# Flatch ESP32 Firmware Update — Bluetooth idle timeout (battery saving)

**For:** whoever flashes the Flatch (ESP32) device
**Source file:** `esp32/src/main.cpp` (⚠️ **renamed** from `main.cp` — see below)
**Supersedes:** the 22 kHz / download-reliability build shipped with app build 24

---

## Why this update

The radio is only useful while the user is pairing with the app, but the old
firmware advertised **forever** — and re-started advertising every 3 seconds for
the entire time the device was powered on. That is a constant drain for a
feature the user needs for maybe thirty seconds.

This build powers the Bluetooth controller **completely down** if no app
connects within **2 minutes** of power-on.

Playback is untouched: the main button and the (separate RF) remote keep working
exactly as before, because neither goes through Bluetooth.

## Behaviour

| Event | Result |
|---|---|
| Power on | Advertises, 2-minute window starts |
| App connects within 2 min | Timer stops; normal session |
| App disconnects | **Window restarts** — another 2 minutes to reconnect |
| 2 min elapse with no connection | BLE controller shut down for this power cycle |
| After shutdown | Device invisible to the app. Buttons still play sounds. |
| To pair again | **Turn the Flatch off and on again** |

This matches the copy already live in the app ("The Flatch bluetooth signal
turns off after two minutes of searching for the app to preserve battery power.
Simply turn the device off and on again to connect to Bluetooth.").

## What changed in the firmware

All changes are in `esp32/src/main.cpp`:

1. **`BLE_IDLE_TIMEOUT_MS` (120000)** — the advertising window.
2. **`g_bleWindowStartMs`** — set at boot and again on every disconnect.
   Compared with unsigned arithmetic so the ~49-day `millis()` rollover is safe.
3. **`shutdownBle()`** — stops advertising, then `BLEDevice::deinit(true)`,
   which disables and deinitialises bluedroid *and* the controller and releases
   the BT memory pool. That release is irreversible until reboot, which is the
   intended design (power-cycle to pair). All BLE pointers are nulled afterwards
   so nothing can dereference freed objects, and any in-flight upload/download
   state is cleared.
4. **`loop()`** — the old unconditional "re-advertise every 3 s" block is now
   inside a `!g_bleShutdown && !g_connected` guard, and only runs while the
   window is open; once it expires, `shutdownBle()` is called instead.
5. **`restartAdvertisingSafe()`** — early-returns after shutdown.

No change to: I2S/audio, sample rate, LittleFS, auth/HMAC, the button handler,
or the LIST / PLAY / UPLOAD / DOWNLOAD / DELETE / REORDER / CANCEL protocol.

## ⚠️ Build note — file was renamed

The source was named **`main.cp`**, which PlatformIO does **not** compile
(it looks for `.c/.cpp/.cc/.cxx/.ino`). It has been **renamed to `main.cpp`**.

Please confirm what your last flash was actually built from. If the device was
flashed from `main.cp` under a build that included it, fine — but if it was
built from a copy kept elsewhere, that copy is now the odd one out and this
change needs applying there too.

## Build & flash

```bash
cd esp32
pio run --target upload      # build + flash over USB
pio device monitor           # optional: serial logs at 115200
```

If flashing fails to connect, hold **BOOT** while it prints "Connecting…".

## Post-flash test checklist

Timing matters here — use a stopwatch.

- [ ] Power on, open the app, scan **within 2 min** → device found, pairs.
- [ ] Pair, then disconnect in-app, wait ~30 s, scan again → **found**
      (window restarted).
- [ ] Power on and **wait > 2 min**, then scan → **not found**.
- [ ] Immediately after that: press the main button → **still plays**.
- [ ] Same state: press the **remote** → **still plays** (confirms the RF path
      is unaffected by the BLE shutdown).
- [ ] Power cycle → scan within 2 min → found again.
- [ ] Regression: upload, download, cancel mid-download, delete, reorder, LIST.
- [ ] Battery: compare idle drain over a few hours vs the old build.

## Rollback

Keep the current production image. If anything regresses, reflash it — the app
tolerates the older firmware completely (it simply advertises forever, as now).

## Not verified on hardware

This firmware has **not been compiled or run on a device** — there is no
PlatformIO toolchain in the environment it was written in. Treat the checklist
above as required, not optional. The highest-risk line is
`BLEDevice::deinit(true)`: if the Arduino ESP32 core version on your toolchain
behaves differently (some versions have been reported to crash if deinit is
called while a client is mid-handshake), fall back to advertising-stop only —
replace the `BLEDevice::deinit(true)` call with `g_adv->stop();` and drop the
pointer-nulling block. That keeps most of the benefit with none of the risk.
