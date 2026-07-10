# Flatch — 22 kHz Audio Optimization Rollout

**Branch:** `audio/22khz`  •  **Version:** 1.0.12+17
**What it does:** switches the device + app audio pipeline from 44.1 kHz to **22.05 kHz mono**, halving on-device storage and Bluetooth transfer time with no audible difference on the device speaker.

---

## ⚠️ READ FIRST — this is a *coordinated* release

The firmware plays raw PCM at whatever rate is compiled in, and the app produces
files at whatever rate its converter is set to. **They must match**, or playback
speed is wrong:

- Device 22 kHz + app still 44 kHz files → plays **half speed** (slow/deep)
- Device still 44 kHz + app 22 kHz files → plays **double speed** (chipmunk)

And **sounds already stored on a device are 44.1 kHz** — after the firmware is
flashed they'll play at half speed until re-uploaded.

**Therefore: flash firmware AND ship the app together, then have users re-sync.**

---

## What's in this package

```
firmware/
  main.cpp              ← updated firmware (drop-in for esp32/src/main.cp)
  FIRMWARE_UPDATE.md    ← build/flash steps + test checklist
  22khz_change.patch    ← the diff, if applying to your own tree
app/
  flatch-iOS-22khz-v1.0.12-17.ipa       ← iOS build for TestFlight
  flatch-Android-22khz-v1.0.12-17.apk   ← Android build (direct install / testers)
ROLLOUT.md             ← this file
```

## Deployment order

### 1. Firmware (manufacturer) — do this FIRST
- Send `firmware/` to whoever flashes your ESP32 hardware.
- They flash `main.cpp` (see `FIRMWARE_UPDATE.md`) onto the test devices.
- **Verify on hardware:** upload a sound from the app build below and confirm it
  plays at **normal speed and pitch** (this is the key check that both sides match).

### 2. App — ship once firmware is confirmed on test devices
- **iOS:** upload the IPA to TestFlight:
  ```
  xcrun altool --upload-app --type ios \
    --file app/flatch-iOS-22khz-v1.0.12-17.ipa \
    --apiKey AAYJQ36654 --apiIssuer 6ee6a7e4-b5d6-4f57-ae5d-63c043c02f24
  ```
  Then (App Store Connect) assign build 17 to your test group + submit Beta App Review.
- **Android:** send `app/flatch-Android-22khz-...apk` to testers (WeChat/QQ for
  China testers), or upload to Google Play internal testing.

### 3. Users — re-sync their sounds
- Anything already on a device is old-format and will sound wrong until replaced.
- Have testers **delete + re-add / re-sync** their sounds after updating.
- Consider a one-time in-app "please re-sync your sounds" prompt for the real release.

## Rollback
- Keep the current 44.1 kHz firmware image and the build-16 app.
- If anything sounds wrong, reflash the old firmware AND revert to the build-16 app
  **together** — never one without the other.

## Note
Not hardware-tested from here (no device/toolchain available). The firmware +
app changes are a straightforward `44100 → 22050` swap, but **verify playback
speed on a real ESP32 before a wide rollout.**
