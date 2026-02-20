import 'package:flutter/services.dart';

class FullWidthSpaceFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final composing = newValue.composing;
    final isComposing = composing.isValid && !composing.isCollapsed;
    if (isComposing) return newValue;

    final converted = newValue.text.replaceAll('\u3000', ' ');
    if (converted == newValue.text) return newValue;
    return TextEditingValue(
      text: converted,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
