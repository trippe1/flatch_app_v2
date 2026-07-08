# Flatch ESP32 Firmware Update — BLE Download Reliability & Cancel

**For:** the firmware/manufacturing team flashing the Flatch (ESP32) device
**Source file:** `esp32/src/main.cp`
**Reference commit:** `a7ee741` (repo `trippe1/flatch_app_v2`, branch `test/feed-bloc-tests`)

---

## Why this update

Two field bugs were traced to the ESP32 `DOWNLOAD` handler:

1. **Downloaded files arrive empty / 0-length (0 dB)** for both WAV and MP3.
2. **The app's Cancel button cannot interrupt a transfer.**

Root cause: the old firmware streamed the entire file **synchronously inside the
BLE `CMD` `onWrite` callback**, sending `DL_BEGIN` and then immediately blasting
20-byte notifications with only `delay(10)` between them. Result:
- The opening chunks (including the WAV header) are sent before the phone has
  processed `DL_BEGIN` and enabled notifications, so they are **dropped** → the
  saved file is truncated/empty.
- Because the whole transfer runs inside one BLE callback, the device **cannot
  receive a CANCEL** command while streaming.

## What changed in the firmware

All changes are in `esp32/src/main.cp` (see the attached patch
`flatch_firmware_download_fix.patch`, or diff commit `a7ee741`):

1. **Transfer moved out of the BLE callback into `loop()`** — a new
   `doDownload(int slot)` function, triggered by a `g_dlRequested` flag set in
   the `DOWNLOAD` command handler. This frees the BLE stack to receive commands
   (i.e. CANCEL) mid-transfer.
2. **150 ms delay after `DL_BEGIN`**, before the first data chunk, so the client
   is listening before data starts (fixes the dropped-header/empty-file bug).
3. **Chunk size 20 → 180 bytes**, matching the existing UPLOAD path (which
   already uses 180-byte writes over the negotiated MTU of 185). Far fewer
   notifications → much lower chance of the BLE notify queue overflowing.
4. **8 ms pacing** between chunk notifications.
5. **New `CANCEL` command** — sets `g_cancelRequested`, which `doDownload()`
   checks each iteration; on cancel it stops and emits `DL_CANCELLED:<slot>`.

Protocol messages `DL_BEGIN:<slot>,<size>` and `DL_END:<slot>,<sent>` are
**unchanged**. One new status string is added: `DL_CANCELLED:<slot>`.

## Compatibility notes

- **MTU:** the 180-byte download chunks require an MTU of ~185, which the app
  already negotiates and already uses for uploads — so this is not a new
  requirement. No change needed on the client for downloads to work.
- **CANCEL:** the updated app sends `CANCEL` to abort a download. Older firmware
  simply ignores it (the app still stops on its side), so there is graceful
  degradation, but the full fix requires this firmware.
- No pin, I2S, LittleFS, auth, upload, list, play, delete, or reorder behavior
  was changed.

## Build & flash

Per `esp32/platformio.ini`: **board `esp32dev`, framework `arduino`,
monitor 115200**.

> **⚠️ Build note:** the source file is named **`main.cp`**. Standard PlatformIO
> only compiles `.cpp`/`.cc`/`.cxx`. If your build does not already include
> `.cp`, **rename `src/main.cp` → `src/main.cpp`** (or add a matching
> `build_src_filter`) before building, or the new code won't be compiled in.

```bash
cd esp32
pio run --target upload      # build + flash over USB
pio device monitor           # optional: serial logs at 115200
```

If flashing fails to connect, hold the board's **BOOT** button while it prints
"Connecting…", then release.

## Post-flash test checklist

- [ ] **Download a WAV slot** from device → app: file plays fully (not empty / 0 dB).
- [ ] **Download an MP3-content slot**: same — plays correctly.
- [ ] **Download several slots consecutively**: all succeed.
- [ ] **Press Cancel mid-download**: transfer stops promptly; device sends
      `DL_CANCELLED`; a subsequent download still works.
- [ ] **Regression:** LIST, PLAY, UPLOAD, DELETE, REORDER all still work.
- [ ] **Regression:** the physical button still plays sounds.

## Rollback

Keep the current production firmware image. If any regression appears, reflash
the previous build; the app tolerates the older firmware (cancel becomes
client-side only, and downloads revert to the prior behavior).
