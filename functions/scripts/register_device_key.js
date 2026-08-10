#!/usr/bin/env node
"use strict";

/*
 * Register (or update) a Flatch device's auth key in Firestore.
 *
 * The per-device key lives in exactly two places: the device's own flash, and
 * the `device_keys` collection this writes to. The app never sees a key except
 * via the App Check-gated getDeviceKey function, which reads this collection.
 *
 * This is the manual/bench version of what a factory flashing station would do
 * automatically: after burning a random key into a unit's NVS, record the same
 * (MAC -> key) here.
 *
 * Usage (from the functions/ dir, with Admin credentials — see below):
 *
 *   # generate a fresh random key AND register it (prints the key to flash):
 *   node scripts/register_device_key.js --mac 20:6e:f1:2e:81:a8 --generate
 *
 *   # register a key you already flashed:
 *   node scripts/register_device_key.js --mac 20:6e:f1:2e:81:a8 --key a8063b...2380
 *
 *   # disable a device without deleting it (revoke):
 *   node scripts/register_device_key.js --mac 20:6e:f1:2e:81:a8 --disable
 *
 * Credentials: set GOOGLE_APPLICATION_CREDENTIALS to a service-account JSON for
 * flatch-e772e, OR run `gcloud auth application-default login` first.
 */

const crypto = require("crypto");
const admin = require("firebase-admin");

function arg(name) {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 ? process.argv[i + 1] : undefined;
}
const has = (name) => process.argv.includes(`--${name}`);

const macRaw = arg("mac");
if (!macRaw) {
  console.error("ERROR: --mac is required (e.g. --mac 20:6e:f1:2e:81:a8)");
  process.exit(1);
}
const mac = macRaw.trim().toLowerCase();
if (!/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/.test(mac)) {
  console.error(`ERROR: "${macRaw}" is not a valid MAC (aa:bb:cc:dd:ee:ff).`);
  process.exit(1);
}

admin.initializeApp({ projectId: "flatch-e772e" });
const db = admin.firestore();

(async () => {
  const ref = db.collection("device_keys").doc(mac);

  if (has("disable")) {
    await ref.set({ active: false }, { merge: true });
    console.log(`Disabled device ${mac}.`);
    return;
  }

  let key = arg("key");
  if (has("generate")) {
    key = crypto.randomBytes(32).toString("hex"); // 256-bit
    console.log("Generated key (flash THIS into the device's NVS):");
    console.log(`  ${key}`);
  }
  if (!key) {
    console.error("ERROR: provide --key <hex> or --generate.");
    process.exit(1);
  }
  if (!/^[0-9a-f]{64}$/i.test(key)) {
    console.error("ERROR: key must be 64 hex chars (32 bytes).");
    process.exit(1);
  }

  await ref.set(
    {
      key: key.toLowerCase(),
      active: true,
      registeredAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
  console.log(`Registered device ${mac}.`);
})()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
