import '../../src/finance.dart';

/// One reconstructed line of a bill (label + price text on the same row),
/// with the average OCR confidence of the boxes that formed it.
class OcrTextLine {
  const OcrTextLine(this.text, this.confidence);

  final String text;
  final double confidence;
}

/// A single detected bill line item, amounts in minor units (paisa).
class ReceiptScanItem {
  const ReceiptScanItem({
    required this.label,
    required this.quantity,
    required this.unitAmountMinor,
    required this.amountMinor,
    required this.confidence,
  });

  final String label;
  final int quantity;
  final int unitAmountMinor;
  final int amountMinor;
  final double confidence;
}

/// Structured result of scanning a printed bill.
class ReceiptScanResult {
  const ReceiptScanResult({
    required this.items,
    required this.serviceChargeMinor,
    required this.taxMinor,
    required this.discountMinor,
    required this.totalMinor,
    required this.confidence,
    this.merchant,
    this.date,
  });

  final String? merchant;
  final String? date;
  final List<ReceiptScanItem> items;
  final int serviceChargeMinor;
  final int taxMinor;
  final int discountMinor; // negative
  final int totalMinor;
  final double confidence;

  bool get hasItems => items.isNotEmpty;
}

// A money token: optional sign, digits with optional thousands separators and
// up to two decimals. The comma-grouped form requires a separator so a plain
// "1200" is matched whole by the second alternative instead of clipped to 120.
final _amountToken = RegExp(
  r'-?\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|-?\d+(?:\.\d{1,2})?',
);
final _qtyPrefix = RegExp(r'^\s*(\d{1,3})\s*[x×*]\s*(.+)$', caseSensitive: false);
final _qtySuffix = RegExp(r'^(.*?)\s*[x×*]\s*(\d{1,3})\s*$', caseSensitive: false);
final _dateRe = RegExp(
  r'(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
);

const _serviceWords = ['service charge', 'service chrg', 's.charge', 'svc', 'service'];
const _taxWords = ['vat', 'g.s.t', 'gst', 'tax'];
const _discountWords = ['discount', 'disc.', 'less', 'promo', 'coupon', 'off'];
const _totalWords = [
  'grand total',
  'net amount',
  'net payable',
  'amount payable',
  'total payable',
  'total amount',
  'total',
];
const _subtotalWords = ['subtotal', 'sub total', 'sub-total', 'taxable'];
const _noiseWords = [
  'cash',
  'change',
  'tender',
  'card',
  'balance',
  'round',
  'date',
  'time',
  'bill no',
  'invoice',
  'receipt',
  'pan no',
  'pan:',
  'vat no',
  'table',
  'waiter',
  'cashier',
  'phone',
  'tel',
  'thank',
  'welcome',
  'qty',
  'rate',
  'particular',
  'description',
  's.n',
  's.no',
  'ref',
];

/// Classifies OCR lines into a structured bill (items, service charge, VAT,
/// discount, merchant, total). A faithful port of the server-side parser the
/// Python prototype used, validated against the same restaurant-bill cases.
ReceiptScanResult parseReceiptLines(List<OcrTextLine> lines) {
  final rows = [
    for (final line in lines)
      if (line.text.trim().isNotEmpty) (line.text.trim(), line.confidence),
  ];

  String? merchant;
  String? date;
  final items = <ReceiptScanItem>[];
  var serviceMinor = 0;
  var taxMinor = 0;
  var discountMinor = 0;
  int? declaredTotalMinor;
  final confidences = <double>[];
  var sawAmountLine = false;

  for (var index = 0; index < rows.length; index++) {
    final (text, conf) = rows[index];
    final lowered = text.toLowerCase();

    date ??= _dateRe.firstMatch(text)?.group(1);

    final (amount, label) = _trailingAmount(text);
    final labelLower = label.toLowerCase();

    if (amount == null) {
      if (merchant == null &&
          index <= 4 &&
          !_hasWord(lowered, _noiseWords) &&
          _looksLikeMerchant(text)) {
        merchant = text;
      }
      continue;
    }

    sawAmountLine = true;
    final amountMinor = npr(amount);

    if (_hasWord(labelLower, _totalWords) &&
        !_hasWord(labelLower, _subtotalWords)) {
      declaredTotalMinor = amountMinor;
      continue;
    }
    if (_hasWord(labelLower, _subtotalWords)) {
      continue;
    }
    if (_hasWord(labelLower, _discountWords)) {
      discountMinor += -amountMinor.abs();
      confidences.add(conf);
      continue;
    }
    if (_hasWord(labelLower, _serviceWords)) {
      serviceMinor += amountMinor;
      confidences.add(conf);
      continue;
    }
    if (_hasWord(labelLower, _taxWords)) {
      taxMinor += amountMinor;
      confidences.add(conf);
      continue;
    }
    if (_hasWord(labelLower, _noiseWords)) {
      continue;
    }

    // A real line item. Drop empty / number-only labels (stray total columns).
    if (label.isEmpty || !label.contains(RegExp(r'[A-Za-z]'))) {
      continue;
    }

    final (quantity, cleanLabel) = _extractQuantity(label);
    final qty = quantity < 1 ? 1 : quantity;
    final unitMinor = qty > 0 ? (amountMinor / qty).round() : amountMinor;
    items.add(
      ReceiptScanItem(
        label: cleanLabel.isEmpty ? label : cleanLabel,
        quantity: qty,
        unitAmountMinor: unitMinor,
        amountMinor: amountMinor,
        confidence: conf,
      ),
    );
    confidences.add(conf);
  }

  final itemsTotal = items.fold<int>(0, (sum, item) => sum + item.amountMinor);
  final computedTotal = itemsTotal + serviceMinor + taxMinor + discountMinor;
  final totalMinor = declaredTotalMinor ?? computedTotal;

  final confidence = confidences.isNotEmpty
      ? confidences.reduce((a, b) => a + b) / confidences.length
      : (sawAmountLine ? 0.5 : 0.0);

  return ReceiptScanResult(
    merchant: merchant,
    date: date,
    items: items,
    serviceChargeMinor: serviceMinor,
    taxMinor: taxMinor,
    discountMinor: discountMinor,
    totalMinor: totalMinor,
    confidence: confidence,
  );
}

/// Returns (amount, label) by peeling the last money token off [text].
(num?, String) _trailingAmount(String text) {
  final matches = _amountToken.allMatches(text).toList();
  if (matches.isEmpty) {
    return (null, text.trim());
  }
  final last = matches.last;
  final value = _toNum(last.group(0)!);
  if (value == null) {
    return (null, text.trim());
  }
  final label = (text.substring(0, last.start) + text.substring(last.end))
      .trim()
      .replaceAll(RegExp(r'^[\s.:\-|]+|[\s.:\-|]+$'), '');
  return (value, label);
}

(int, String) _extractQuantity(String label) {
  final prefix = _qtyPrefix.firstMatch(label);
  if (prefix != null) {
    return (int.parse(prefix.group(1)!), _trimEdges(prefix.group(2)!));
  }
  final suffix = _qtySuffix.firstMatch(label);
  if (suffix != null && suffix.group(1)!.trim().isNotEmpty) {
    return (int.parse(suffix.group(2)!), _trimEdges(suffix.group(1)!));
  }
  return (1, label);
}

num? _toNum(String token) {
  final cleaned = token.replaceAll(',', '').trim();
  if (cleaned.isEmpty || cleaned == '-' || cleaned == '.') {
    return null;
  }
  return num.tryParse(cleaned);
}

bool _hasWord(String haystack, List<String> words) {
  for (final word in words) {
    if (haystack.contains(word)) {
      return true;
    }
  }
  return false;
}

bool _looksLikeMerchant(String label) {
  if (label.length < 3 || label.length > 48) {
    return false;
  }
  final letters = RegExp(r'[A-Za-z]').allMatches(label).length;
  return letters >= (label.length ~/ 2).clamp(3, label.length);
}

String _trimEdges(String value) =>
    value.replaceAll(RegExp(r'^[\s.:\-|]+|[\s.:\-|]+$'), '');
