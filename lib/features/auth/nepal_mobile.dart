import 'package:flutter/services.dart';

String? normalizeNepalMobile(String value) {
  var digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('977') && digits.length > 10) {
    digits = digits.substring(3);
  }
  return RegExp(r'^9[678]\d{8}$').hasMatch(digits) ? digits : null;
}

class NepalMobileInputFormatter extends TextInputFormatter {
  const NepalMobileInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('977') && digits.length > 10) {
      digits = digits.substring(3);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
