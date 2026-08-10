# Flatch device authentication — key storage & provisioning

How the app proves it's allowed to control a Flatch, and where the per-device
keys live.

## The handshake

1. On connect, the device sends `AUTH_CHAL:<challengeHex>,<MAC>` — a random
   16-byte challenge plus its own MAC.
2. The app looks up that device's key, computes
   `HMAC-SHA256(key, challenge)` over the **raw bytes** of each, and replies
   `AUTH_RESP:<hmacHex>`.
3. The device computes the same HMAC with its own key and compares. Match → the
   session is authenticated.

The MAC is sent **in the message** (not read from BLE) because iOS hides the
hardware MAC behind a random peripheral UUID — the app can't learn it otherwise.

## Where keys live (cache-on-phone model)

A per-device key exists in exactly two places:

- the **device's flash (NVS)**, written at manufacturing;
- the **`device_keys/{mac}` Firestore doc** — server-only, never client-readable.

The app obtains its key like this:

1. Check the phone's **secure storage** (Keychain / Keystore).
2. On a miss, call the **`getDeviceKey`** Cloud Function (App Check + auth
   enforced), which reads `device_keys` with the Admin SDK and returns the key.
3. Cache it and compute the HMAC locally.

So a key crosses the network **once per device**; every reconnect afterward
works offline — important because the firmware powers Bluetooth down after 2
minutes, so users reconnect often.

Why a function and not a direct Firestore read: MACs are broadcast over BLE and
therefore public. A client-readable key collection could be enumerated to
harvest every key. `device_keys` is locked to `allow read, write: if false;`
(see `firestore.rules`); the function is the only door, and it's gated.

Residual exposure: a rooted/jailbroken phone can extract keys for devices **it
has paired** from secure storage. That's a small, local exposure — not "all
keys everywhere" — and acceptable for this product.

## Provisioning a device (manufacturing / bench)

`functions/scripts/register_device_key.js` is the manual version of what a
flashing station should automate. It writes `device_keys/{mac}`.

Set Admin credentials first (service-account JSON via
`GOOGLE_APPLICATION_CREDENTIALS`, or `gcloud auth application-default login`),
then from `functions/`:

```bash
# Generate a random 256-bit key AND register it. It prints the key —
# flash THAT into the device's NVS.
node scripts/register_device_key.js --mac 20:6e:f1:2e:81:a8 --generate

# Or register a key you already flashed:
node scripts/register_device_key.js --mac 20:6e:f1:2e:81:a8 --key <64-hex>

# Revoke a device (keeps the record, blocks auth):
node scripts/register_device_key.js --mac 20:6e:f1:2e:81:a8 --disable
```

At scale, the flashing station does the same three things per unit:
1. generate a random 32-byte key,
2. burn it into that unit's NVS,
3. write `(MAC -> key)` to `device_keys`.

The key must be **unique per device** and **never shared in source**. (The old
firmware's single hardcoded `AUTH_SECRET` is exactly what this replaces.)

## For the firmware team

- Each unit must read **its own** key from NVS, not a shared constant.
- Keep sending the MAC in `AUTH_CHAL` (the app depends on it for iOS).
- Consider a monotonic counter alongside the random challenge so a captured
  `(challenge, response)` pair can't be replayed.
- On `AUTH_FAIL`, issue a **fresh** challenge rather than reusing the stale one.

## Rollout checklist

- [ ] Deploy `firestore.rules` (locks `device_keys`).
- [ ] Deploy `getDeviceKey` (App Check enforced).
- [ ] Register at least one device (`--generate` or `--key`).
- [ ] App build with `FirestoreCachedKeyProvider` (wired in `main.dart`).
- [ ] Pair end-to-end; confirm offline reconnect works after the first pair.
- [ ] Remove the bundled test key from `device_key_service.dart` before GA and
      re-key device_001.
