/// The BLE OTA (over-the-air firmware update) protocol — the single source of
/// truth for what the app sends the device and what it expects back.
///
/// ⚠️ PROVISIONAL. The device firmware (PS075-007, ESP-IDF) does not implement
/// these yet. This is the app's proposed contract; the firmware team must
/// implement the matching side (or send changes and we adjust here — this file
/// is the only place to change). See docs/OTA_PROTOCOL.md.
///
/// All commands go on the existing CMD characteristic AFTER auth; all status
/// lines arrive on the existing STATUS characteristic (notify), exactly like
/// the current LIST/PLAY/UPLOAD protocol.
class OtaProtocol {
  OtaProtocol._();

  /// Field separator inside a command whose fields may themselves contain
  /// commas/colons (WiFi ssid/password). ASCII Unit Separator (0x1F) never
  /// appears in a URL, SSID, password, or semver, so it can't collide.
  static const String sep = '\u{001F}';

  // ---- App → device (commands) ----

  /// Ask the device for its current firmware version → replies [sVersion].
  static const String cmdGetVersion = 'GET_VERSION';

  /// Provide WiFi so the device can reach the download URL:
  /// `OTA_WIFI:<ssid>` + sep(0x1F) + `<password>`.
  /// OPEN QUESTION for firmware: how the device gets WiFi is unspecified in the
  /// change spec. If the device is provisioned another way, drop this.
  static const String cmdWifiPrefix = 'OTA_WIFI:';

  /// Reset the device's URL buffer before sending a new one.
  static const String cmdUrlClear = 'OTA_URL_CLEAR';

  /// Append a URL fragment: `OTA_URL_APPEND:<chunk>`. The URL is sent in
  /// [urlChunkSize]-byte pieces because a signed download URL can exceed the
  /// BLE MTU.
  static const String cmdUrlAppendPrefix = 'OTA_URL_APPEND:';

  /// Begin download + verify + install of the buffered URL:
  /// `OTA_START:<sizeBytes>,<sha256hex>,<version>`.
  static const String cmdStartPrefix = 'OTA_START:';

  /// Abort an in-progress OTA (device stays on current firmware).
  static const String cmdAbort = 'OTA_ABORT';

  /// Max bytes of URL per OTA_URL_APPEND (MTU 185 minus prefix + overhead).
  static const int urlChunkSize = 120;

  // ---- Device → app (status lines) ----

  static const String sVersion = 'VERSION:'; // VERSION:<semver>
  static const String sOtaState = 'OTA_STATE:'; // see [OtaDeviceState]
  static const String sOtaProgress = 'OTA_PROGRESS:'; // done/total
  static const String sOtaError = 'OTA_ERROR:'; // see [OtaError]
  static const String sOtaDone = 'OTA_DONE'; // installed, about to reboot
}

/// Device-reported OTA phases (payload of `OTA_STATE:`).
enum OtaDeviceState {
  connectingWifi,
  downloading,
  verifying,
  installing,
  rebooting;

  static OtaDeviceState? parse(String s) {
    switch (s.trim().toUpperCase()) {
      case 'CONNECTING_WIFI':
        return OtaDeviceState.connectingWifi;
      case 'DOWNLOADING':
        return OtaDeviceState.downloading;
      case 'VERIFYING':
        return OtaDeviceState.verifying;
      case 'INSTALLING':
        return OtaDeviceState.installing;
      case 'REBOOTING':
        return OtaDeviceState.rebooting;
    }
    return null;
  }

  /// User-facing label.
  String get label {
    switch (this) {
      case OtaDeviceState.connectingWifi:
        return 'Connecting to Wi-Fi…';
      case OtaDeviceState.downloading:
        return 'Downloading update…';
      case OtaDeviceState.verifying:
        return 'Verifying…';
      case OtaDeviceState.installing:
        return 'Installing…';
      case OtaDeviceState.rebooting:
        return 'Restarting device…';
    }
  }
}

/// Device-reported OTA failures (payload of `OTA_ERROR:`).
enum OtaError {
  lowBattery,
  wifiFail,
  httpFail,
  verifyFail,
  sameVersion,
  olderVersion,
  noSpace,
  aborted,
  unknown;

  static OtaError parse(String s) {
    switch (s.trim().toUpperCase()) {
      case 'LOW_BATTERY':
        return OtaError.lowBattery;
      case 'WIFI_FAIL':
        return OtaError.wifiFail;
      case 'HTTP_FAIL':
        return OtaError.httpFail;
      case 'VERIFY_FAIL':
        return OtaError.verifyFail;
      case 'SAME_VERSION':
        return OtaError.sameVersion;
      case 'OLDER_VERSION':
        return OtaError.olderVersion;
      case 'NO_SPACE':
        return OtaError.noSpace;
      case 'ABORTED':
        return OtaError.aborted;
    }
    return OtaError.unknown;
  }

  /// User-facing message.
  String get message {
    switch (this) {
      case OtaError.lowBattery:
        return 'Your Flatch needs at least 30% battery to update. Charge it '
            'and try again.';
      case OtaError.wifiFail:
        return "Your Flatch couldn't reach Wi-Fi. Check the network and "
            'password, then retry.';
      case OtaError.httpFail:
        return 'The update download failed. Check your connection and retry.';
      case OtaError.verifyFail:
        return 'The update failed its safety check and was not installed. '
            'Your Flatch is unchanged.';
      case OtaError.sameVersion:
        return 'Your Flatch is already on this version.';
      case OtaError.olderVersion:
        return 'That version is older than what your Flatch is running.';
      case OtaError.noSpace:
        return 'Not enough space on the device to install the update.';
      case OtaError.aborted:
        return 'Update cancelled. Your Flatch is unchanged.';
      case OtaError.unknown:
        return 'The update could not be completed. Your Flatch is unchanged.';
    }
  }
}
