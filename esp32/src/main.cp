#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include "driver/i2s.h"
#include <LittleFS.h>
#include <vector>
#include "mbedtls/md.h"

#define I2S_SAMPLE_RATE 44100
#define I2S_DOUT 22
#define I2S_BCLK 26
#define I2S_LRC 25

#define BUTTON_PIN 27

#define SERVICE_UUID "0000abcd-0000-1000-8000-00805f9b34fb"
#define CMD_UUID "0000abce-0000-1000-8000-00805f9b34fb"
#define DATA_UUID "0000abcf-0000-1000-8000-00805f9b34fb"
#define STATUS_UUID "0000abd0-0000-1000-8000-00805f9b34fb"

static const char* AUTH_SECRET = "CHANGE_ME_TO_STRONG_SECRET_123";

BLECharacteristic *cmdChar = nullptr;
BLECharacteristic *dataChar = nullptr;
BLECharacteristic *statusChar = nullptr;

BLEServer* g_server = nullptr;
BLEAdvertising* g_adv = nullptr;

volatile bool g_connected = false;

static bool g_authed = false;
static uint8_t g_challenge[16];
static bool g_hasChallenge = false;

File uploadFile;
bool uploading = false;
uint32_t uploadTotal = 0, uploadWritten = 0;
int uploadSlot = 0;

volatile bool g_playRequested = false;
volatile int g_playRequestedSlot = -1;

// Download is driven from loop() (not the BLE CMD callback) so the callback
// returns immediately and the BLE stack stays free to receive a CANCEL command
// mid-transfer. See doDownload().
volatile bool g_dlRequested = false;
volatile int g_dlRequestedSlot = -1;
volatile bool g_cancelRequested = false;

static uint32_t g_lastBtnMs = 0;
static bool g_lastBtnState = true;
static int g_playSlotCursor = 1;

static void i2s_init() {
  i2s_config_t cfg = {};
  cfg.mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX);
  cfg.sample_rate = I2S_SAMPLE_RATE;
  cfg.bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT;
  cfg.channel_format = I2S_CHANNEL_FMT_ONLY_LEFT;
  cfg.communication_format = I2S_COMM_FORMAT_I2S;
  cfg.intr_alloc_flags = 0;
  cfg.dma_buf_count = 8;
  cfg.dma_buf_len = 64;
  cfg.use_apll = false;
  cfg.tx_desc_auto_clear = true;
  cfg.fixed_mclk = 0;

  i2s_pin_config_t pins = {};
  pins.bck_io_num = I2S_BCLK;
  pins.ws_io_num = I2S_LRC;
  pins.data_out_num = I2S_DOUT;
  pins.data_in_num = I2S_PIN_NO_CHANGE;

  i2s_driver_install(I2S_NUM_0, &cfg, 0, NULL);
  i2s_set_pin(I2S_NUM_0, &pins);
  i2s_zero_dma_buffer(I2S_NUM_0);
}

static String slotPath(int s) { return "/sound" + String(s) + ".wav"; }
static String tmpPath(int s) { return "/tmp" + String(s) + ".wav"; }

static bool isValidSlot(int s) { return s >= 1 && s <= 9; }

static void playWav(const char* path) {
  File f = LittleFS.open(path, "r");
  if (!f) return;
  uint8_t hdr[44];
  if (f.read(hdr, 44) != 44) { f.close(); return; }
  uint8_t buf[1024];
  while (f.available()) {
    size_t n = f.read(buf, sizeof(buf));
    if (n == 0) break;
    size_t w = 0;
    i2s_write(I2S_NUM_0, buf, n, &w, portMAX_DELAY);
  }
  f.close();
}

static int findNextExistingSlot(int start) {
  for (int i = 0; i < 9; i++) {
    int s = ((start - 1 + i) % 9) + 1;
    if (LittleFS.exists(slotPath(s))) return s;
  }
  return -1;
}

static String bytesToHex(const uint8_t* in, size_t len) {
  static const char* hex = "0123456789abcdef";
  String out;
  out.reserve(len * 2);
  for (size_t i = 0; i < len; i++) {
    out += hex[(in[i] >> 4) & 0xF];
    out += hex[in[i] & 0xF];
  }
  return out;
}

static String hmacSha256Hex(const uint8_t* key, size_t keyLen, const uint8_t* data, size_t dataLen) {
  uint8_t out[32];
  mbedtls_md_context_t ctx;
  mbedtls_md_init(&ctx);
  const mbedtls_md_info_t* info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
  mbedtls_md_setup(&ctx, info, 1);
  mbedtls_md_hmac_starts(&ctx, key, keyLen);
  mbedtls_md_hmac_update(&ctx, data, dataLen);
  mbedtls_md_hmac_finish(&ctx, out);
  mbedtls_md_free(&ctx);
  return bytesToHex(out, sizeof(out));
}

static void setStatus(const String &msg) {
  if (!statusChar) return;
  statusChar->setValue(msg.c_str());
  statusChar->notify();
}

static void sendList() {
  String l = "";
  for (int i = 1; i <= 9; i++) {
    if (LittleFS.exists(slotPath(i))) {
      if (l.length()) l += ",";
      l += String(i);
    }
  }
  setStatus("LIST:" + l);
}

static void reorderSlots(const std::vector<int>& order) {
  for (int i = 1; i <= 9; i++) {
    String t = tmpPath(i);
    if (LittleFS.exists(t)) LittleFS.remove(t);
  }

  for (int i = 0; i < (int)order.size() && i < 9; i++) {
    int oldSlot = order[i];
    if (!isValidSlot(oldSlot)) continue;
    String oldP = slotPath(oldSlot);
    String tmpP = tmpPath(i + 1);
    if (LittleFS.exists(oldP)) LittleFS.rename(oldP, tmpP);
  }

  for (int i = 1; i <= 9; i++) {
    String p = slotPath(i);
    if (LittleFS.exists(p)) LittleFS.remove(p);
  }

  for (int i = 1; i <= 9; i++) {
    String t = tmpPath(i);
    String p = slotPath(i);
    if (LittleFS.exists(t)) LittleFS.rename(t, p);
  }

  sendList();
  setStatus("OK");
}

static void restartAdvertisingSafe() {
  if (!g_adv) g_adv = BLEDevice::getAdvertising();
  g_adv->stop();
  delay(120);
  BLEDevice::startAdvertising();
}

// Streams a slot to the client. Runs from loop() (Arduino task), NOT the BLE
// callback, so a CANCEL command can arrive and be honored mid-transfer.
static void doDownload(int s) {
  File f = LittleFS.open(slotPath(s), "r");
  if (!f) { setStatus("ERR:NOT_FOUND"); return; }

  uint32_t size = (uint32_t)f.size();
  setStatus("DL_BEGIN:" + String(s) + "," + String(size));

  // Give the client time to receive DL_BEGIN and enable data notifications
  // before the first chunk. Without this the opening chunks (including the WAV
  // header) arrive before the app is listening and are dropped -- which is why
  // downloaded files showed up empty / 0-length.
  delay(150);

  const size_t CHUNK = 180;  // matches the upload chunk size (negotiated MTU 185)
  uint8_t buf[CHUNK];
  uint32_t sent = 0;

  while (f.available() && g_connected) {
    if (g_cancelRequested) break;
    size_t n = f.read(buf, CHUNK);
    if (n == 0) break;
    dataChar->setValue(buf, n);
    dataChar->notify();
    sent += (uint32_t)n;
    delay(8);  // pace notifications so the client's BLE stack doesn't drop them
  }

  f.close();

  if (g_cancelRequested) {
    g_cancelRequested = false;
    setStatus("DL_CANCELLED:" + String(s));
    return;
  }

  setStatus("DL_END:" + String(s) + "," + String(sent));
}

class ServerCB : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) override {
    g_connected = true;
    g_authed = false;
    g_hasChallenge = false;
  }

  void onDisconnect(BLEServer* pServer) override {
    g_connected = false;
    g_authed = false;
    g_hasChallenge = false;
    uploading = false;
    if (uploadFile) uploadFile.close();
    delay(300);
    restartAdvertisingSafe();
  }
};

class CmdCB : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) override {
    String cmd = c->getValue().c_str();
    cmd.trim();
    if (cmd.length() == 0) return;

    if (cmd == "AUTH_HELLO") {
      for (int i = 0; i < 16; i++) g_challenge[i] = (uint8_t)esp_random();
      g_hasChallenge = true;
      g_authed = false;
      setStatus("AUTH_CHAL:" + bytesToHex(g_challenge, 16));
      return;
    }

    if (cmd.startsWith("AUTH_RESP:")) {
      if (!g_hasChallenge) {
        setStatus("AUTH_FAIL:NO_CHAL");
        return;
      }
      String respHex = cmd.substring(String("AUTH_RESP:").length());
      respHex.trim();
      String expected = hmacSha256Hex(
        (const uint8_t*)AUTH_SECRET, strlen(AUTH_SECRET),
        g_challenge, 16
      );

      if (respHex.equalsIgnoreCase(expected)) {
        g_authed = true;
        setStatus("AUTH_OK");
      } else {
        g_authed = false;
        setStatus("AUTH_FAIL");
      }
      return;
    }

    if (!g_authed) {
      setStatus("ERR:NOT_AUTH");
      return;
    }

    if (cmd == "LIST") { sendList(); return; }

    if (cmd.startsWith("REORDER:")) {
      String body = cmd.substring(8);
      std::vector<int> order;
      while (body.length()) {
        int comma = body.indexOf(',');
        if (comma == -1) { order.push_back(body.toInt()); break; }
        order.push_back(body.substring(0, comma).toInt());
        body = body.substring(comma + 1);
      }
      reorderSlots(order);
      return;
    }

    if (cmd.startsWith("PLAY:")) {
      int s = cmd.substring(5).toInt();
      if (!isValidSlot(s)) { setStatus("ERR:BAD_SLOT"); return; }
      if (!LittleFS.exists(slotPath(s))) { setStatus("ERR:NOT_FOUND"); return; }
      g_playRequestedSlot = s;
      g_playRequested = true;
      setStatus("OK");
      return;
    }

    if (cmd.startsWith("DELETE:")) {
      int s = cmd.substring(7).toInt();
      if (!isValidSlot(s)) { setStatus("ERR:BAD_SLOT"); return; }
      if (LittleFS.exists(slotPath(s))) LittleFS.remove(slotPath(s));
      sendList();
      setStatus("OK");
      return;
    }

    if (cmd.startsWith("UPLOAD_BEGIN:")) {
      int p = cmd.indexOf(',');
      if (p < 0) { setStatus("ERR:BAD_FMT"); return; }

      uploadSlot = cmd.substring(13, p).toInt();
      uploadTotal = cmd.substring(p + 1).toInt();
      uploadWritten = 0;

      if (!isValidSlot(uploadSlot) || uploadTotal == 0) { setStatus("ERR:BAD_SLOT_OR_SIZE"); return; }

      uploading = false;
      if (uploadFile) uploadFile.close();

      String tp = tmpPath(uploadSlot);
      if (LittleFS.exists(tp)) LittleFS.remove(tp);

      uploadFile = LittleFS.open(tp, "w");
      if (!uploadFile) { setStatus("ERR:OPEN_FAIL"); return; }

      uploading = true;
      setStatus("OK");
      return;
    }

    if (cmd == "UPLOAD_END") {
      uploading = false;
      if (uploadFile) uploadFile.close();

      if (uploadWritten != uploadTotal) {
        String tp = tmpPath(uploadSlot);
        if (LittleFS.exists(tp)) LittleFS.remove(tp);
        setStatus("ERR:SIZE_MISMATCH");
        return;
      }

      String tp = tmpPath(uploadSlot);
      String fp = slotPath(uploadSlot);
      if (LittleFS.exists(fp)) LittleFS.remove(fp);
      if (!LittleFS.rename(tp, fp)) { setStatus("ERR:RENAME_FAIL"); return; }

      sendList();
      setStatus("OK");
      return;
    }

    if (cmd == "CANCEL") {
      // Aborts an in-progress download; honored inside doDownload()'s loop.
      g_cancelRequested = true;
      return;
    }

    if (cmd.startsWith("DOWNLOAD:")) {
      int s = cmd.substring(9).toInt();
      if (!isValidSlot(s)) { setStatus("ERR:BAD_SLOT"); return; }
      if (!LittleFS.exists(slotPath(s))) { setStatus("ERR:NOT_FOUND"); return; }

      // Defer streaming to loop() so this callback returns and the BLE stack
      // stays free to receive a CANCEL while the transfer is running.
      g_cancelRequested = false;
      g_dlRequestedSlot = s;
      g_dlRequested = true;
      return;
    }

    setStatus("ERR:UNKNOWN_CMD");
  }
};

class DataCB : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *c) override {
    if (!g_authed) return;
    if (!uploading) return;
    if (!uploadFile) return;
    std::string v = c->getValue();
    if (v.empty()) return;
    size_t w = uploadFile.write((uint8_t*)v.data(), v.size());
    uploadWritten += (uint32_t)w;
    if (uploadWritten % 4096 == 0 || uploadWritten == uploadTotal) {
      setStatus("PROG:" + String(uploadWritten) + "/" + String(uploadTotal));
    }
  }
};

void setup() {
  i2s_init();
  LittleFS.begin(true);

  pinMode(BUTTON_PIN, INPUT_PULLUP);

  BLEDevice::init("Latch V8");
  g_server = BLEDevice::createServer();
  g_server->setCallbacks(new ServerCB());

  BLEService *svc = g_server->createService(SERVICE_UUID);
  cmdChar = svc->createCharacteristic(CMD_UUID, BLECharacteristic::PROPERTY_WRITE);

  dataChar = svc->createCharacteristic(
    DATA_UUID,
    BLECharacteristic::PROPERTY_WRITE_NR | BLECharacteristic::PROPERTY_NOTIFY
  );

  statusChar = svc->createCharacteristic(
    STATUS_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
  );

  dataChar->addDescriptor(new BLE2902());
  statusChar->addDescriptor(new BLE2902());

  cmdChar->setCallbacks(new CmdCB());
  dataChar->setCallbacks(new DataCB());

  svc->start();

  g_adv = BLEDevice::getAdvertising();
  g_adv->addServiceUUID(SERVICE_UUID);
  g_adv->setScanResponse(true);
  g_adv->setMinPreferred(0x06);
  g_adv->setMinPreferred(0x12);

  BLEDevice::startAdvertising();
  sendList();
}

void loop() {
  if (g_dlRequested) {
    g_dlRequested = false;
    int s = g_dlRequestedSlot;
    g_dlRequestedSlot = -1;
    doDownload(s);
  }

  if (g_playRequested) {
    int s = g_playRequestedSlot;
    g_playRequested = false;
    g_playRequestedSlot = -1;
    if (isValidSlot(s) && LittleFS.exists(slotPath(s))) {
      playWav(slotPath(s).c_str());
    }
  }

  bool nowState = digitalRead(BUTTON_PIN);
  uint32_t nowMs = millis();
  if (nowMs - g_lastBtnMs > 60) {
    if (g_lastBtnState == HIGH && nowState == LOW) {
      int s = findNextExistingSlot(g_playSlotCursor);
      if (s != -1) {
        g_playSlotCursor = s + 1;
        playWav(slotPath(s).c_str());
      }
    }
    g_lastBtnState = nowState;
    g_lastBtnMs = nowMs;
  }

  static uint32_t last = 0;
  if (!g_connected && (millis() - last > 3000)) {
    last = millis();
    restartAdvertisingSafe();
  }

  delay(10);
}
