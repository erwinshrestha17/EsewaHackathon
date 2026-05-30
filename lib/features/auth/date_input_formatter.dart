import 'package:flutter/services.dart';

/// Formats raw digits into a `YYYY-MM-DD` date as the user types.
///
/// The user only enters digits; hyphens are inserted automatically after the
/// year (4 digits) and the month (2 digits) so they never have to type them.
class DateOfBirthInputFormatter extends TextInputFormatter {
  const DateOfBirthInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) {
      digits = digits.substring(0, 8);
    }

    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 4 || i == 6) {
        buffer.write('-');
      }
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
