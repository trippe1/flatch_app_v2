import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EmojiInputFormatter extends TextInputFormatter {
  static final RegExp _emojiRegex = RegExp(
    r'^[\u{1F600}-\u{1F64F}'
    r'\u{1F300}-\u{1F5FF}'
    r'\u{1F680}-\u{1F6FF}'
    r'\u{1F1E6}-\u{1F1FF}'
    r'\u{2600}-\u{26FF}'
    r'\u{2700}-\u{27BF}'
    r'\u{1F900}-\u{1F9FF}'
    r'\u{1FA70}-\u{1FAFF}'
    r'\u{1F018}-\u{1F270}]$',
    unicode: true,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final char = newValue.text.characters.last;
    return _emojiRegex.hasMatch(char)
        ? TextEditingValue(
          text: char,
          selection: TextSelection.collapsed(offset: char.length),
        )
        : oldValue;
  }
}
