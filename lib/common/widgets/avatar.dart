import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'dart:typed_data';

Widget buildUserAvatar(String? imageUrl, String userName, double height) {
  if (imageUrl != null && imageUrl.startsWith('data:image')) {
    try {
      final base64Str = imageUrl.split(',').last;
      final Uint8List bytes = base64Decode(base64Str);

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          width: height * 0.18,
          height: height * 0.14,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {
      return _initialLetterAvatar(userName);
    }
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: CachedNetworkImage(
      imageUrl: imageUrl ?? '',
      width: height * 0.18,
      height: height * 0.14,
      fit: BoxFit.cover,
      placeholder:
          (context, url) => _shimmerAvatar(height * 0.18, height * 0.14),
      errorWidget: (context, url, error) => _initialLetterAvatar(userName),
    ),
  );
}

Widget buildUserAvatarDetails(
  String? imageUrl,
  String userName,
  double height,
  double width, {
  BoxFit fit = BoxFit.cover,
}) {
  if (imageUrl != null && imageUrl.startsWith('data:image')) {
    try {
      final base64Str = imageUrl.split(',').last;
      final Uint8List bytes = base64Decode(base64Str);

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(bytes, width: width, height: height, fit: fit),
      );
    } catch (_) {
      return _initialLetterAvatar(userName);
    }
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: CachedNetworkImage(
      imageUrl: imageUrl ?? '',
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _shimmerAvatar(width, height),
      errorWidget: (context, url, error) => _initialLetterAvatar(userName),
    ),
  );
}

Widget buildCircularUserAvatar(
  BuildContext context, 
  String? imageUrl,
  String userName,
  double size, {
  BoxFit fit = BoxFit.cover,
}) {
  return GestureDetector(
    onTap: () {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        showDialog(
          context: context,
          builder:
              (_) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Hero(
                    tag: imageUrl,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
        );
      }
    },
    child: Hero(
      tag: imageUrl ?? userName,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl ?? '',
          width: size,
          height: size,
          fit: fit,
          placeholder: (context, url) => _shimmerAvatar(size * 0.6, size * 0.6),
          errorWidget: (context, url, error) => _initialLetterAvatar(userName),
        ),
      ),
    ),
  );
}

Widget buildCircularUserAvatarAdmin(
  BuildContext context,
  String? imageUrl,
  String userName,
  double size, {
  BoxFit fit = BoxFit.cover,
  required String heroTag, 
}) {
  return GestureDetector(
    onTap: () {
      if (imageUrl != null && imageUrl.isNotEmpty) {
        showDialog(
          context: context,
          builder:
              (_) => Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Hero(
                    tag: heroTag, // same unique tag here
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
        );
      }
    },
    child: Hero(
      tag: heroTag, // unique for each user
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: imageUrl ?? '',
          width: size,
          height: size,
          fit: fit,
          placeholder: (context, url) => _shimmerAvatar(size * 0.6, size * 0.6),
          errorWidget: (context, url, error) => _initialLetterAvatar(userName),
        ),
      ),
    ),
  );
}


Widget _initialLetterAvatar(String name) {
  final initial = (name.isNotEmpty ? name[0].toUpperCase() : '?');
  final bgColor = getColorForLetter(initial);
  return Container(
    width: 50,
    height: 50,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      initial,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Color getColorForLetter(String letter) {
  final colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.indigo,
    Colors.teal,
    Colors.deepOrange,
    Colors.cyan,
    Colors.pink,
    Colors.brown,
    Colors.amber,
  ];
  int index = letter.codeUnitAt(0) % colors.length;
  return colors[index].shade400;
}

Widget buildInitialAvatar(String name) {
  final initial = (name.isNotEmpty ? name[0].toUpperCase() : '?');
  final bgColor = getColorForLetter(initial);

  return ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      color: bgColor,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

Widget _shimmerAvatar(double width, double height) {
  return Shimmer.fromColors(
    baseColor: Colors.grey[500]!,
    highlightColor: Colors.grey[100]!,
    direction: ShimmerDirection.ltr,
    child: Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
