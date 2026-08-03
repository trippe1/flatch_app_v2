/// Built-in ("stock") sounds available to everyone, including guests with no
/// account. These ship as bundled assets so they need no auth / no Firestore.
///
/// NOTE: the current WAV files under assets/sounds/ are PLACEHOLDER tones
/// (22.05kHz / 16-bit / mono — matching the device's fixed I2S rate; the WAV
/// byte-rate field reads 44100 = 22050 x 2, which is easy to misread as the
/// sample rate). Swap them for real fart clips by replacing the files at the
/// same paths — keep the format 22050 Hz / 16-bit / mono so they play at the
/// correct speed on the device. No code change needed.
class StockSound {
  final String id;
  final String name;
  final String category;
  final String assetPath;

  const StockSound({
    required this.id,
    required this.name,
    required this.category,
    required this.assetPath,
  });
}

const List<StockSound> kStockSounds = [
  StockSound(
    id: 'stock_01',
    name: 'Report',
    category: 'Standard Issue',
    assetPath: 'assets/sounds/stock_01_toot.wav',
  ),
  StockSound(
    id: 'stock_02',
    name: 'Beep',
    category: 'Classic',
    assetPath: 'assets/sounds/stock_02_beep.wav',
  ),
  StockSound(
    id: 'stock_03',
    name: 'Honk',
    category: 'Classic',
    assetPath: 'assets/sounds/stock_03_honk.wav',
  ),
  StockSound(
    id: 'stock_04',
    name: 'Buzz',
    category: 'Rude',
    assetPath: 'assets/sounds/stock_04_buzz.wav',
  ),
  StockSound(
    id: 'stock_05',
    name: 'Squeak',
    category: 'Rude',
    assetPath: 'assets/sounds/stock_05_squeak.wav',
  ),
  StockSound(
    id: 'stock_06',
    name: 'Pop',
    category: 'Rude',
    assetPath: 'assets/sounds/stock_06_pop.wav',
  ),
  StockSound(
    id: 'stock_07',
    name: 'Blip',
    category: 'Silly',
    assetPath: 'assets/sounds/stock_07_blip.wav',
  ),
  StockSound(
    id: 'stock_08',
    name: 'Rumble',
    category: 'Silly',
    assetPath: 'assets/sounds/stock_08_rumble.wav',
  ),
];
