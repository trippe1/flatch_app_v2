"use strict";

// Flatch content moderation.
//
// Trigger: a new document in `user_farts` (i.e. a freshly uploaded clip).
// Action: send the audio to a multimodal model (Gemini via Vertex AI) and ask
// whether it contains sexually explicit / adult content. High-confidence hits
// are auto-hidden (isPublic=false) and queued for admin review; medium hits
// stay visible but are queued; clean clips are marked approved.
//
// This runs with the Admin SDK, so Firestore/Storage security rules do NOT
// apply to it — it can update any fart doc and write the moderation queue.

const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");
const { VertexAI } = require("@google-cloud/vertexai");

admin.initializeApp();

// ---- Tunables -------------------------------------------------------------
const PROJECT = process.env.GCLOUD_PROJECT || "flatch-e772e";
const LOCATION = "us-central1";
// Vertex publisher models get retired over time (the old "gemini-2.0-flash-001"
// started returning 404 NOT_FOUND). Try current models in order and fall back
// to the next when one is unavailable in the region, so moderation self-heals.
const MODEL_CANDIDATES = [
  "gemini-2.5-flash",
  "gemini-2.0-flash",
  "gemini-1.5-flash-002",
];

// Cost lever:
//   "all"    -> moderate every public upload (proactive; ~$0.001/clip)
//   "signal" -> skip proactive scanning; rely on user reports only (near-zero)
const SCAN_MODE = "all";

const BLOCK_THRESHOLD = 0.7; // >= confidence & adult -> auto-hide
const REVIEW_THRESHOLD = 0.4; // >= confidence & adult -> queue, stay visible
const MAX_BYTES = 10 * 1024 * 1024; // safety cap on clip size we will analyze

const MIME_BY_EXT = {
  wav: "audio/wav",
  mp3: "audio/mpeg",
  mpeg: "audio/mpeg",
  m4a: "audio/mp4",
  mp4: "audio/mp4",
  aac: "audio/aac",
  ogg: "audio/ogg",
};

const RESPONSE_SCHEMA = {
  type: "object",
  properties: {
    adult: { type: "boolean" },
    confidence: { type: "number" },
    category: { type: "string" },
    reason: { type: "string" },
  },
  required: ["adult", "confidence", "category", "reason"],
};

const vertex = new VertexAI({ project: PROJECT, location: LOCATION });

function isModelUnavailable(err) {
  const msg = String(err && err.message ? err.message : err);
  return (
    msg.includes("NOT_FOUND") ||
    msg.includes("was not found") ||
    msg.includes("404") ||
    msg.includes("does not have access")
  );
}

// Try each candidate model until one is available in the region.
async function classifyAudio(base64, mime, title) {
  let lastErr;
  for (const modelName of MODEL_CANDIDATES) {
    try {
      return await classifyWithModel(modelName, base64, mime, title);
    } catch (e) {
      lastErr = e;
      if (isModelUnavailable(e)) {
        logger.warn(`model ${modelName} unavailable, trying next: ${e}`);
        continue;
      }
      throw e; // a real error (quota, malformed response, etc.) — surface it
    }
  }
  throw lastErr;
}

async function classifyWithModel(modelName, base64, mime, title) {
  const model = vertex.getGenerativeModel({
    model: modelName,
    generationConfig: {
      temperature: 0,
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
    },
  });

  const prompt =
    "You are a content-safety classifier for a short-audio social app whose " +
    "normal, allowed content is comedic fart / flatulence sounds. Analyze the " +
    "attached audio clip together with its title and decide whether it " +
    "contains sexually explicit or adult content — e.g. moaning, audible " +
    "sexual acts, explicit sexual speech, or pornographic audio. Comedic fart " +
    "or bathroom-humor sounds are NOT adult content. Be conservative: only set " +
    "adult=true when the audio is genuinely sexual. " +
    `Title: "${title || ""}". ` +
    "Respond with JSON: adult (boolean), confidence (0-1), category (short " +
    "label), reason (one short sentence).";

  const result = await model.generateContent({
    contents: [
      {
        role: "user",
        parts: [
          { text: prompt },
          { inlineData: { data: base64, mimeType: mime } },
        ],
      },
    ],
  });

  const text =
    result?.response?.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
  return JSON.parse(text);
}

async function queueForReview(fartId, fart, verdict, status) {
  await admin
    .firestore()
    .collection("moderation_queue")
    .doc(fartId)
    .set(
      {
        fartId,
        uid: fart.uid || null,
        title: fart.title || "",
        fileUrl: fart.fileUrl || "",
        fileType: fart.fileType || "",
        verdict: {
          adult: !!verdict.adult,
          confidence: Number(verdict.confidence) || 0,
          category: verdict.category || "",
          reason: verdict.reason || "",
        },
        status, // auto_blocked | pending_review | error
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

// ---- Offensive-language control (community titles) ------------------------
// Policy: titles uploaded to the COMMUNITY (public) must be clean. Private /
// device recordings are unaffected (they never reach the public feed). This is
// a deterministic word-list match with light obfuscation handling; blocked
// items are hidden from the feed and land in the admin review queue.
const PROFANITY = [
  "fuck", "fuckn", "fuckin", "fucking", "fucked", "fucks", "fucker", "fuckers",
  "fuckwad", "fuckface", "motherfucker", "motherfuckers", "stfu", "wtf",
  "shit", "shite", "shitty", "shithead", "shithole", "bullshit", "dipshit",
  "bitch", "bitches", "bitchy", "cunt", "cunts", "asshole", "assholes",
  "dumbass", "jackass", "bastard", "bastards", "dick", "dicks", "dickhead",
  "pussy", "pussies", "cock", "cocks", "slut", "sluts", "whore", "whores",
  "douche", "douchebag", "wank", "wanker", "bollocks", "prick", "pricks",
  "twat", "jerkoff", "cum", "cumshot", "boner",
  // slurs / hate
  "fag", "fags", "faggot", "faggots", "nigger", "niggers", "nigga", "niggas",
  "retard", "retarded", "spic", "chink", "kike", "coon", "dyke", "tranny",
  "gook", "wetback", "beaner",
];
// Also matched after stripping ALL separators (catches "f u c k", "f.u.c.k").
// Only words that never appear inside innocent words go here — avoids the
// "Scunthorpe problem" (e.g. class/assess/cockpit must not trip).
const COLLAPSE_SET = new Set([
  "fuck", "fucking", "fucked", "motherfucker", "bitch", "asshole",
  "faggot", "nigger", "nigga", "bastard", "dickhead", "bullshit", "dumbass",
]);

function deLeet(s) {
  return String(s)
    .toLowerCase()
    .replace(/[@4]/g, "a")
    .replace(/[!1|]/g, "i")
    .replace(/3/g, "e")
    .replace(/0/g, "o")
    .replace(/[$5]/g, "s")
    .replace(/7/g, "t");
}

// Returns the offending word, or null if the text is clean.
function findProfanity(text) {
  if (!text) return null;
  const deleet = deLeet(text);
  for (const w of PROFANITY) {
    if (new RegExp(`\\b${w}\\b`).test(deleet)) return w;
  }
  const collapsed = deleet.replace(/[^a-z]/g, "");
  for (const w of COLLAPSE_SET) {
    if (collapsed.includes(w)) return w;
  }
  return null;
}

exports.moderateNewFart = onDocumentCreated(
  {
    document: "user_farts/{fartId}",
    region: LOCATION,
    memory: "512MiB",
    timeoutSeconds: 120,
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const fart = snap.data();
    const fartId = event.params.fartId;

    // Private clips never hit the public feed, so skip them.
    if (fart.isPublic === false) return;

    // Offensive-language control: a profane title is never allowed into the
    // community. Block it from the public feed and queue it for review. (The
    // user keeps the clip in their own library; it just can't be shared.)
    const badWord = findProfanity(fart.title);
    if (badWord) {
      await admin
        .firestore()
        .collection("user_farts")
        .doc(fartId)
        .update({ isPublic: false, moderationStatus: "blocked_language" });
      await queueForReview(
        fartId,
        fart,
        {
          adult: false,
          confidence: 1,
          category: "offensive_language",
          reason: `Profane title ("${badWord}")`,
        },
        "auto_blocked"
      );
      logger.info(`fart ${fartId}: auto-blocked for language ("${badWord}")`);
      return;
    }

    // Cost lever: reactive-only mode does no proactive scanning.
    if (SCAN_MODE === "signal") return;

    const url = fart.fileUrl;
    if (!url) {
      logger.warn(`fart ${fartId}: no fileUrl, skipping moderation`);
      return;
    }
    const ext = String(fart.fileType || "").toLowerCase();
    const mime = MIME_BY_EXT[ext] || "audio/mpeg";

    let verdict;
    try {
      const resp = await fetch(url);
      if (!resp.ok) throw new Error(`download failed: ${resp.status}`);
      const buf = Buffer.from(await resp.arrayBuffer());
      if (buf.length > MAX_BYTES) {
        logger.warn(`fart ${fartId}: ${buf.length} bytes exceeds cap, queuing`);
        await queueForReview(
          fartId,
          fart,
          { adult: false, confidence: 0, category: "oversized", reason: "too large to auto-scan" },
          "error"
        );
        return;
      }
      verdict = await classifyAudio(buf.toString("base64"), mime, fart.title);
    } catch (e) {
      // Fail OPEN (leave the clip visible) but queue it so nothing slips by
      // silently on an API/network error.
      logger.error(`fart ${fartId}: moderation error: ${e}`);
      await queueForReview(
        fartId,
        fart,
        { adult: false, confidence: 0, category: "error", reason: String(e) },
        "error"
      );
      return;
    }

    const conf = Number(verdict.confidence) || 0;
    const isAdult = verdict.adult === true;
    const fartRef = admin.firestore().collection("user_farts").doc(fartId);

    if (isAdult && conf >= BLOCK_THRESHOLD) {
      await fartRef.update({ isPublic: false, moderationStatus: "auto_blocked" });
      await queueForReview(fartId, fart, verdict, "auto_blocked");
      logger.info(`fart ${fartId}: auto-blocked (conf=${conf})`);
    } else if (isAdult && conf >= REVIEW_THRESHOLD) {
      await fartRef.update({ moderationStatus: "pending_review" });
      await queueForReview(fartId, fart, verdict, "pending_review");
      logger.info(`fart ${fartId}: queued for review (conf=${conf})`);
    } else {
      await fartRef.update({ moderationStatus: "approved" });
    }
  }
);

// ---------------------------------------------------------------------------
// Push notification: tell a fart's owner when someone comments on it.
// ---------------------------------------------------------------------------
exports.notifyOnComment = onDocumentCreated(
  {
    document: "user_farts/{fartId}/comments/{commentId}",
    region: LOCATION,
  },
  async (event) => {
    const comment = event.data?.data();
    if (!comment) return;
    const fartId = event.params.fartId;
    const commenterUid = comment.uid;

    const db = admin.firestore();

    const fartSnap = await db.collection("user_farts").doc(fartId).get();
    if (!fartSnap.exists) return;
    const ownerUid = fartSnap.data().uid;
    // Don't notify people about their own comments.
    if (!ownerUid || ownerUid === commenterUid) return;

    const tokenSnap = await db.collection("user_push_tokens").doc(ownerUid).get();
    const tokens = (tokenSnap.exists && tokenSnap.data().tokens) || [];
    if (!tokens.length) return;

    let commenterName = "Someone";
    try {
      const cSnap = await db.collection("app_users").doc(commenterUid).get();
      if (cSnap.exists && cSnap.data().name) commenterName = cSnap.data().name;
    } catch (_) {}

    const body = String(comment.text || "").slice(0, 120);
    const resp = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: `${commenterName} commented on your fart`,
        body,
      },
      data: { fartId, type: "comment" },
      android: {
        priority: "high",
        notification: { channelId: "high_importance_channel" },
      },
      apns: { payload: { aps: { sound: "default" } } },
    });

    // Prune tokens FCM reports as dead so the list doesn't grow stale.
    const invalid = [];
    resp.responses.forEach((r, i) => {
      const code = r.error && r.error.code;
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-argument"
      ) {
        invalid.push(tokens[i]);
      }
    });
    if (invalid.length) {
      await db
        .collection("user_push_tokens")
        .doc(ownerUid)
        .update({
          tokens: admin.firestore.FieldValue.arrayRemove(...invalid),
        });
    }
  }
);

// ---- Farts with Buddies: notify group members of new posts ----------------
// Trigger: a new message in a group's chat. Notify every OTHER member who has
// FWB notifications on (default: on). In anonymous groups the poster's name is
// withheld from the notification. System messages (e.g. "left the group") are
// not pushed.
exports.notifyFwbMessage = onDocumentCreated(
  {
    document: "fwb_groups/{groupId}/messages/{messageId}",
    region: LOCATION,
  },
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;
    if (msg.type === "system") return;

    const groupId = event.params.groupId;
    const senderUid = msg.senderUid;
    const db = admin.firestore();

    const groupSnap = await db.collection("fwb_groups").doc(groupId).get();
    if (!groupSnap.exists) return;
    const group = groupSnap.data();
    const members = Array.isArray(group.members) ? group.members : [];
    const anonymous = group.anonymous === true;
    const groupName = group.name || "your group";

    // Everyone except the sender.
    const recipients = members.filter((u) => u && u !== senderUid);
    if (!recipients.length) return;

    // Sender's display name (only used when the group isn't anonymous).
    let senderName = "Someone";
    if (!anonymous) {
      try {
        const s = await db.collection("app_users").doc(senderUid).get();
        if (s.exists && s.data().name) senderName = s.data().name;
      } catch (_) {}
    }

    const title = anonymous
      ? `New post in ${groupName}`
      : `${senderName} posted in ${groupName}`;
    let body;
    if (msg.type === "fart") {
      const t = String(msg.title || "").slice(0, 80);
      body = t ? `Shared a fart: ${t}` : "Shared a fart";
    } else {
      body = String(msg.text || "").slice(0, 120);
    }

    // Resolve each recipient's notification preference + tokens in parallel.
    await Promise.all(
      recipients.map(async (uid) => {
        try {
          const [settingSnap, tokenSnap] = await Promise.all([
            db.collection("user_settings").doc(uid).get(),
            db.collection("user_push_tokens").doc(uid).get(),
          ]);
          // Default ON when unset. Respect both the global toggle and this
          // user's per-chat mute list.
          const settings = settingSnap.exists ? settingSnap.data() : {};
          const globallyOn = settings.fwbNotifications !== false;
          const muted =
            Array.isArray(settings.mutedFwbGroups) &&
            settings.mutedFwbGroups.includes(groupId);
          if (!globallyOn || muted) return;

          const tokens =
            (tokenSnap.exists && tokenSnap.data().tokens) || [];
          if (!tokens.length) return;

          const resp = await admin.messaging().sendEachForMulticast({
            tokens,
            notification: { title, body },
            data: { groupId, type: "fwb" },
            android: {
              priority: "high",
              notification: { channelId: "high_importance_channel" },
            },
            apns: { payload: { aps: { sound: "default" } } },
          });

          const invalid = [];
          resp.responses.forEach((r, i) => {
            const code = r.error && r.error.code;
            if (
              code === "messaging/registration-token-not-registered" ||
              code === "messaging/invalid-argument"
            ) {
              invalid.push(tokens[i]);
            }
          });
          if (invalid.length) {
            await db
              .collection("user_push_tokens")
              .doc(uid)
              .update({
                tokens: admin.firestore.FieldValue.arrayRemove(...invalid),
              });
          }
        } catch (e) {
          logger.warn(`FWB notify failed for ${uid}: ${e}`);
        }
      })
    );
  }
);

// ===========================================================================
//  Community feed index: Reddit-style ranking + searchable tokens
// ===========================================================================
// The app's "Community Farts" tab orders by `hotScore` and searches by
// `searchTokens`, both maintained here so ranking and search are correct
// GLOBALLY (not just over whatever page the client happened to load).

/** Reddit's "hot" ranking. Age is baked in at write time, so the score only
 *  needs recomputing when votes change — it does not decay on a timer. */
function hotScore(ups, downs, createdAtMs) {
  const score = (ups || 0) - (downs || 0);
  const order = Math.log10(Math.max(Math.abs(score), 1));
  const sign = score > 0 ? 1 : score < 0 ? -1 : 0;
  // Reddit epoch (2005-12-08); createdAt is stored as epoch millis.
  const seconds = (createdAtMs || 0) / 1000 - 1134028003;
  return Number((sign * order + seconds / 45000).toFixed(7));
}

/** Must mirror `tokenizeSearch` in lib/common/logics/search_tokens.dart. */
function tokenize(input) {
  if (!input) return [];
  return String(input)
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((t) => t.length >= 2);
}

// Bound the array so a fart with thousands of comments can't blow up the doc.
const MAX_TOKENS = 300;

/** Recompute hotScore + searchTokens whenever a fart changes.
 *  searchTokens = title + author name + `commentTokens` (kept separately by
 *  syncCommentTokens), so a re-title never wipes comment-derived tokens. */
exports.syncFartIndex = onDocumentWritten(
  { document: "user_farts/{fartId}", region: LOCATION },
  async (event) => {
    const after = event.data?.after;
    if (!after || !after.exists) return; // deleted
    const fart = after.data();
    const db = admin.firestore();

    let authorName = "";
    if (fart.uid) {
      try {
        const u = await db.collection("app_users").doc(fart.uid).get();
        authorName = (u.exists && u.data().name) || "";
      } catch (_) {}
    }

    const commentTokens = Array.isArray(fart.commentTokens)
      ? fart.commentTokens
      : [];
    const tokens = Array.from(
      new Set([
        ...tokenize(fart.title),
        ...tokenize(authorName),
        ...commentTokens,
      ])
    ).slice(0, MAX_TOKENS);

    const score = hotScore(fart.upvotes, fart.downvotes, fart.createdAt);

    // Loop guard: this function writes to the doc it watches, so bail out once
    // the stored values already match what we just computed.
    const prevTokens = Array.isArray(fart.searchTokens) ? fart.searchTokens : [];
    const sameTokens =
      prevTokens.length === tokens.length &&
      prevTokens.every((t, i) => t === tokens[i]);
    if (sameTokens && fart.hotScore === score) return;

    await after.ref.update({ hotScore: score, searchTokens: tokens });
  }
);

/** Fold new comment text into the parent fart's `commentTokens` so community
 *  search can find a fart by what people said about it. */
exports.syncCommentTokens = onDocumentCreated(
  { document: "user_farts/{fartId}/comments/{commentId}", region: LOCATION },
  async (event) => {
    const comment = event.data?.data();
    if (!comment) return;
    const tokens = tokenize(comment.text);
    if (!tokens.length) return;

    await admin
      .firestore()
      .collection("user_farts")
      .doc(event.params.fartId)
      .update({
        commentTokens: admin.firestore.FieldValue.arrayUnion(...tokens),
      });
    // The update above re-triggers syncFartIndex, which merges these into
    // searchTokens.
  }
);

/** One-time (idempotent) backfill for farts created before this index existed.
 *  Docs missing `hotScore` are invisible to the ranked query, so this must be
 *  run once after deploy. Admin-only; safe to re-run. */
exports.backfillFartIndex = onCall(
  { region: LOCATION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Sign in required.");

    const db = admin.firestore();
    const me = await db.collection("app_users").doc(uid).get();
    if (!me.exists || me.data().role !== "Admin") {
      throw new HttpsError("permission-denied", "Admins only.");
    }

    const names = new Map();
    let scanned = 0;
    let updated = 0;
    let cursor = null;

    for (;;) {
      let q = db.collection("user_farts").orderBy("__name__").limit(200);
      if (cursor) q = q.startAfter(cursor);
      const snap = await q.get();
      if (snap.empty) break;
      cursor = snap.docs[snap.docs.length - 1];

      const batch = db.batch();
      let writes = 0;

      for (const doc of snap.docs) {
        scanned++;
        const fart = doc.data();

        if (!names.has(fart.uid)) {
          let n = "";
          try {
            const u = await db.collection("app_users").doc(fart.uid).get();
            n = (u.exists && u.data().name) || "";
          } catch (_) {}
          names.set(fart.uid, n);
        }

        // Pull existing comment text for this fart.
        let commentTokens = [];
        try {
          const cs = await doc.ref.collection("comments").limit(200).get();
          cs.forEach((c) => commentTokens.push(...tokenize(c.data().text)));
        } catch (_) {}

        const tokens = Array.from(
          new Set([
            ...tokenize(fart.title),
            ...tokenize(names.get(fart.uid)),
            ...commentTokens,
          ])
        ).slice(0, MAX_TOKENS);

        batch.update(doc.ref, {
          hotScore: hotScore(fart.upvotes, fart.downvotes, fart.createdAt),
          commentTokens: Array.from(new Set(commentTokens)).slice(0, MAX_TOKENS),
          searchTokens: tokens,
        });
        writes++;
        updated++;
      }

      if (writes) await batch.commit();
      if (snap.docs.length < 200) break;
    }

    logger.info(`backfillFartIndex: scanned ${scanned}, updated ${updated}`);
    return { scanned, updated };
  }
);

// ===========================================================================
//  Password reset: does this account exist?
// ===========================================================================
// Firebase's email enumeration protection (on by default for projects created
// after 2023-09-15) makes sendPasswordResetEmail succeed silently for unknown
// addresses — the client can no longer tell "sent" from "no such account".
// This callable answers that question with the Admin SDK so the app can show
// "no account found" instead of a misleading success screen.
//
// NOTE: this intentionally exposes whether an email has an account (that is the
// requested UX), so App Check is ENFORCED here — only attested builds of the
// real app can call it, which stops scripted enumeration of your user list.
// App Check attests the app rather than the user, so this still works on the
// signed-out Forgot Password screen.
exports.checkAccountExists = onCall(
  { region: LOCATION, enforceAppCheck: true },
  async (request) => {
    const email = String(request.data?.email || "").trim().toLowerCase();
    if (!email || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "A valid email is required.");
    }

    try {
      await admin.auth().getUserByEmail(email);
      return { exists: true };
    } catch (e) {
      if (e && e.code === "auth/user-not-found") return { exists: false };
      logger.error(`checkAccountExists failed for ${email}: ${e}`);
      throw new HttpsError("internal", "Could not check that email.");
    }
  }
);
