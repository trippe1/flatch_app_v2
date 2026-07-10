# Flatch ESP32 Firmware Update

**For:** the firmware/manufacturing team flashing the Flatch (ESP32) device
**Source file:** `esp32/src/main.cp`  •  **Branch:** `audio/22khz`

This firmware bundles **two** sets of changes — flash it once and you get both.

---

## Change set A — BLE download reliability & cancel (bugs 2 & 4)

**Problems fixed**
1. Files downloaded from the device to the app arrived **empty / 0-length** (WAV and MP3).
2. The app's **Cancel** button couldn't interrupt a transfer.

**Root cause:** the old firmware streamed the whole file **synchronously inside the
BLE `CMD` callback** with 20-byte chunks and no pacing — the opening chunks (incl.
the WAV header) were sent before the phone was listening and got dropped, and no
`CANCEL` could be received mid-transfer.

**What changed**
- The download transfer now runs from `loop()` (a new `doDownload()`), not the BLE
  callback, so the stack stays free to receive commands mid-transfer.
- A **150 ms delay after `DL_BEGIN`** before the first chunk (fixes the empty files).
- Chunk size **20 → 180 bytes** (matches the upload path / negotiated MTU) + **8 ms
  pacing** between chunks.
- A new **`CANCEL`** command (honored inside the streaming loop) + a `DL_CANCELLED:<slot>`
  status.

Protocol `DL_BEGIN` / `DL_END` are unchanged; `DL_CANCELLED:<slot>` is new.

---

## Change set B — 22.05 kHz mono audio

**What changed:** `#define I2S_SAMPLE_RATE 44100` → **`22050`** (line 11).

**Why:** halves on-device storage and Bluetooth transfer time with no audible loss
on the device speaker (fart audio is low-frequency; the small speaker is the quality
bottleneck).

### ⚠️ Change set B is a COORDINATED release — read this
The firmware plays raw PCM at `I2S_SAMPLE_RATE`; the app produces files at whatever
rate its converter is set to. **They must match** or playback speed is wrong:
- device 22 kHz + app still 44 kHz files → **half speed** (slow/deep)
- device still 44 kHz + app 22 kHz files → **double speed** (chipmunk)

So this firmware must ship **together with the matching app build (1.0.12+17 from the
`audio/22khz` branch)**. And **sounds already on a device are 44.1 kHz** — after this
flash they'll play at half speed until the user **re-syncs / re-uploads** them.

*(Change set A has no such dependency — it works with any app version.)*

---

## Build & flash

Per `esp32/platformio.ini`: board **`esp32dev`**, framework **`arduino`**, monitor **115200**.

> **⚠️ Build note:** the source file is named **`main.cp`**. Standard PlatformIO only
> compiles `.cpp`/`.cc`/`.cxx`. **Rename `src/main.cp` → `src/main.cpp`** (the attached
> `main.cpp` already is) or add a matching `build_src_filter`, or the code won't compile in.

```bash
cd esp32
pio run --target upload      # build + flash over USB
pio device monitor           # optional: serial logs at 115200
```
If flashing fails to connect, hold the board's **BOOT** button while it prints
"Connecting…", then release.

---

## Post-flash test checklist

**Change set A (download + cancel):**
- [ ] Download a WAV slot from device → app: file plays fully (not empty / 0-length).
- [ ] Download an MP3-content slot: same.
- [ ] Press **Cancel** mid-download: transfer stops promptly; device sends `DL_CANCELLED`.

**Change set B (22 kHz) — use the matching app build 1.0.12+17:**
- [ ] Upload a sound from the app, then play it on the device: it plays at **normal
      speed and pitch** (this confirms firmware + app sample rates match — the key check).
- [ ] Confirm multi-file **Sync to Flatch** still completes (app-side handshake).

**Regression (both):**
- [ ] LIST, PLAY, UPLOAD, DELETE, REORDER still work; the physical button still plays.

---

## Rollback

Keep the current production firmware image and the build-16 (44.1 kHz) app.
If anything sounds wrong, reflash the previous firmware **and** revert the app to
build 16 **together** — never one without the other (they must match on sample rate).
