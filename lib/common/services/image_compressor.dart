import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressor {
  ImageCompressor._();
  static final instance = ImageCompressor._();
  Future<String> compressImage(XFile imageFile) async {
    final directory = await getTemporaryDirectory();
    final targetPath = '${directory.path}/compressed_image.jpg';
    final result = await FlutterImageCompress.compressAndGetFile(
      imageFile.path,
      targetPath,
      quality: 25,
    );
    if (result == null) {
      throw Exception('Failed to compress image');
    }
    return result.path;
  }
}
