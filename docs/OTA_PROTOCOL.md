# Flatch OTA — app ↔ device BLE protocol (PROPOSED)

The app-side firmware-update flow is built. This is the contract it speaks; the
device firmware (PS075-007, ESP-IDF) must implement the matching side. **Please
review and confirm or send changes** — the app keeps this in one place
(`lib/common/constants/ota_protocol.dart`), so adjusting is a one-file change.

Everything reuses the existing BLE setup: commands on the **CMD** characteristic
(after auth), status lines on the **STATUS** characteristic (notify) — exactly
like today's LIST / PLAY / UPLOAD protocol.

## Flow

1. On connect + auth, the app sends `GET_VERSION`; the device replies
   `VERSION:<semver>`.
2. The app reads the current release from Firestore (`firmware/current`:
   version, url, sha256, sizeBytes, minBatteryPct, notes). If its version is
   newer than the device's, it shows "Device update available".
3. The user taps Update and (for now) enters Wi-Fi credentials.
4. The app sends, in order:
   - `OTA_WIFI:<ssid><US><password>` (US = 0x1F) — *if provided*
   - `OTA_URL_CLEAR`
   - `OTA_URL_APPEND:<chunk>` × N  (URL split into ≤120-byte pieces)
   - `OTA_START:<sizeBytes>,<sha256hex>,<version>`
5. The device connects Wi-Fi, downloads, verifies (length + SHA-256 + app
   descriptor), installs into the inactive OTA slot, and reboots — emitting
   status as it goes.
6. After reboot the device re-advertises on the new firmware; the app
   reconnects and `GET_VERSION` confirms the new version (acceptance test T1).

## Commands (app → device, CMD char, post-auth)

| Command | Meaning |
|---|---|
| `GET_VERSION` | Reply `VERSION:<semver>` |
| `OTA_WIFI:<ssid><0x1F><password>` | Wi-Fi to use for the download |
| `OTA_URL_CLEAR` | Reset the URL buffer |
| `OTA_URL_APPEND:<chunk>` | Append ≤120 bytes to the URL buffer |
| `OTA_START:<size>,<sha256>,<version>` | Begin download+verify+install of the buffered URL |
| `OTA_ABORT` | Cancel an in-progress OTA (stay on current firmware) |

The URL is chunked because a signed download URL can exceed the BLE MTU (~185).
`size`/`sha256`/`version` contain no commas, so a comma separator is safe there;
SSID/password may, so those use 0x1F.

## Status (device → app, STATUS char notify)

| Line | Meaning |
|---|---|
| `VERSION:<semver>` | Current firmware version |
| `OTA_STATE:<S>` | Phase: `CONNECTING_WIFI` / `DOWNLOADING` / `VERIFYING` / `INSTALLING` / `REBOOTING` |
| `OTA_PROGRESS:<done>/<total>` | Download progress (bytes) |
| `OTA_ERROR:<E>` | Failure — see below. Device stays on current firmware. |
| `OTA_DONE` | Verified + installed; device about to reboot |

Error codes `<E>`: `LOW_BATTERY`, `WIFI_FAIL`, `HTTP_FAIL`, `VERIFY_FAIL`,
`SAME_VERSION`, `OLDER_VERSION`, `NO_SPACE`, `ABORTED`, `UNKNOWN`. The app maps
each to a specific user message (see `OtaError` in `ota_protocol.dart`).

## Open questions for the firmware team

1. **Wi-Fi provisioning.** The change spec says "device joins Wi-Fi" but not
   *how* it gets credentials. The app currently prompts the user and sends
   `OTA_WIFI:`. If the device is provisioned another way, we'll drop that step.
   Note: BLE isn't necessarily encrypted unless bonded — if we send a Wi-Fi
   password over it, confirm the link is encrypted, or we should provision
   differently.
2. **URL length / chunking.** Confirm 120-byte `OTA_URL_APPEND` chunks and a
   server-side URL buffer are acceptable, or propose a cap/short-URL scheme.
3. **Battery gate.** The app shows the `minBatteryPct` from Firestore (default
   30) and relies on the device to enforce it (spec: refuse below 30% via
   `BAT_VDET`) and report `OTA_ERROR:LOW_BATTERY`. Confirm the device enforces,
   not just the app.
4. **Version source.** The app sends `version` in `OTA_START` for gating, but
   the device can also read it from the image's `esp_app_desc_t`. Confirm which
   is authoritative (recommend the descriptor — it can't be spoofed by the app).
5. **Post-reboot handshake.** Confirm the device re-advertises normally after an
   OTA reboot so the app's existing reconnect + `GET_VERSION` closes the loop.

## App side (already built)

- `lib/common/constants/ota_protocol.dart` — commands/status/errors (this doc).
- `lib/common/services/firmware_release_service.dart` — reads `firmware/current`.
- `FlatchBleCubit.startOta / abortOta` + status parsing.
- `lib/views/home/firmware_update_card.dart` — the connected-screen UI.
- `firestore.rules` — `firmware/{doc}` readable by signed-in users, written by
  admins.

## Publishing a release (your side, later)

Host the `.bin` at a public HTTPS URL (Firebase Storage download URL or CDN) and
write `firmware/current`:

```json
{
  "version": "13.1",
  "url": "https://.../PS075-007-v13.1.bin",
  "sha256": "<hex>",
  "sizeBytes": 1900000,
  "minBatteryPct": 30,
  "notes": "OTA + external sound library."
}
```

The app picks it up on the next device connection.
