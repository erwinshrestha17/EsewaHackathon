import '../../src/finance.dart';

/// One reconstructed line of a bill (label + price text on the same row),
/// with the average OCR confidence of the boxes that formed it.
class OcrTextLine {
  const OcrTextLine(this.text, this.confidence);

  final String text;
  final double confidence;
}

/// A single OCR text box with its bounding geometry (in source-image pixels).
/// Plain doubles (no `dart:ui`) so the parser stays pure-Dart and testable.
class OcrWord {
  const OcrWord({
    required this.text,
    required this.confidence,
    required this.left,
    required this.right,
    required this.centerY,
    required this.height,
  });

  final String text;
  final double confidence;
  final double left;
  final double right;
  final double centerY;
  final double height;

  double get centerX => (left + right) / 2;
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
final _qtyPrefix = RegExp(
  r'^\s*(\d{1,3})\s*[x×*]\s*(.+)$',
  caseSensitive: false,
);
final _qtySuffix = RegExp(
  r'^(.*?)\s*[x×*]\s*(\d{1,3})\s*$',
  caseSensitive: false,
);
final _dateRe = RegExp(
  r'(\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{2,4})',
);

const _serviceWords = [
  'service charge',
  'service chrg',
  's.charge',
  'svc',
  'service',
];
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
const _baseAmountWords = [
  'base amount',
  'basic amount',
  'basio amount',
  'basiq amount',
  'basis amount',
  'gross amount',
];

// Lines that open the totals/footer block. The first such line after the item
// table ends the item region in the columnar parser.
const _totalsRegionWords = [
  'gross amount',
  'base amount',
  'basic amount',
  'basio amount',
  'basiq amount',
  'basis amount',
  'grand total',
  'sub total',
  'subtotal',
  'net amount',
  'net payable',
  'total amount',
  'amount payable',
  'total payable',
  'tender',
  'change',
  'total qty',
  'discount',
  'vat',
  'service charge',
  'tax',
];

const _noiseWords = [
  'cash',
  'change',
  'tender',
  'card',
  'balance',
  'round',
  'date',
  'time',
  'miti',
  'bill no',
  'invoice',
  'receipt',
  'pan no',
  'pan:',
  'vat no',
  'payment mode',
  'remarks',
  'address',
  'gross amount',
  'base amount',
  'basic amount',
  'basio amount',
  'basiq amount',
  'basis amount',
  'net amount',
  'total qty',
  'opening hours',
  'counter',
  'cashier',
  'table',
  'waiter',
  'phone',
  'tel',
  'www',
  'goods will',
  'thank',
  'welcome',
  'hsc',
  'qty',
  'rate',
  'particular',
  'description',
  's.n',
  's.no',
  'ref',
];

/// Parses OCR boxes into a structured bill using their geometry.
///
/// Columnar receipts (e.g. supermarket bills with a
/// `Sn | Particulars | Qty | Rate | Amount` header) are parsed column-aware:
/// the item region is gated between the table header and the totals block, the
/// price is taken from the Amount column only, and wrapped/continuation lines
/// (which have no Amount-column number) are dropped. Bills without such a header
/// (e.g. restaurant slips) fall back to the line-based [parseReceiptLines].
ReceiptScanResult parseReceipt(List<OcrWord> words) {
  final clean = [
    for (final word in words)
      if (word.text.trim().isNotEmpty) word,
  ];
  if (clean.isEmpty) {
    return const ReceiptScanResult(
      items: [],
      serviceChargeMinor: 0,
      taxMinor: 0,
      discountMinor: 0,
      totalMinor: 0,
      confidence: 0,
    );
  }

  final rows = _clusterRows(clean);
  final header = _detectHeader(rows);
  if (header == null) {
    return parseReceiptLines([for (final row in rows) _rowToLine(row)]);
  }
  return _parseColumnar(rows, header);
}

/// Column anchors read from a detected table header row.
class _Header {
  const _Header({required this.rowIndex, required this.numbersLeft});

  final int rowIndex;
  final double numbersLeft; // left edge of the Qty/Rate/Amount number zone
}

/// Groups boxes into reading-order rows by vertical position.
List<List<OcrWord>> _clusterRows(List<OcrWord> words) {
  final sorted = [...words]..sort((a, b) => a.centerY.compareTo(b.centerY));
  final heights = [
    for (final w in sorted)
      if (w.height > 0) w.height,
  ]..sort();
  final medianHeight = heights.isEmpty ? 12.0 : heights[heights.length ~/ 2];
  final gap = (medianHeight <= 0 ? 12.0 : medianHeight) * 0.6;

  final rows = <List<OcrWord>>[];
  var row = <OcrWord>[sorted.first];
  var anchorY = sorted.first.centerY;
  for (final word in sorted.skip(1)) {
    if ((word.centerY - anchorY).abs() <= gap) {
      row.add(word);
    } else {
      rows.add(_sortByLeft(row));
      row = <OcrWord>[word];
      anchorY = word.centerY;
    }
  }
  rows.add(_sortByLeft(row));
  return rows;
}

List<OcrWord> _sortByLeft(List<OcrWord> row) =>
    [...row]..sort((a, b) => a.left.compareTo(b.left));

OcrTextLine _rowToLine(List<OcrWord> row) {
  final text = row.map((w) => w.text).join(' ');
  final confidence =
      row.map((w) => w.confidence).fold<double>(0, (a, b) => a + b) /
      row.length;
  return OcrTextLine(text, confidence);
}

/// Finds the `Particulars … Amount` table header and reads its column anchors.
_Header? _detectHeader(List<List<OcrWord>> rows) {
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final joined = row.map((w) => w.text.toLowerCase()).join(' ');
    if (!joined.contains('particular')) {
      continue;
    }
    if (!joined.contains('amount') &&
        !joined.contains('rate') &&
        !joined.contains('qty')) {
      continue;
    }

    OcrWord? find(String keyword) {
      OcrWord? hit;
      for (final w in row) {
        if (w.text.toLowerCase().contains(keyword)) {
          hit = w;
        }
      }
      return hit;
    }

    final part = find('particular');
    final amount = find('amount');
    if (part == null || amount == null) {
      continue;
    }
    // Left edge of the number columns: the left-most of Qty/Rate/Amount. Used
    // only to keep the Sn column out of the Qty/amount calculation.
    final numberHeaders = [
      find('qty'),
      find('rate'),
      amount,
    ].whereType<OcrWord>().toList();
    final numbersLeft = numberHeaders
        .map((w) => w.left)
        .reduce((a, b) => a < b ? a : b);
    return _Header(rowIndex: i, numbersLeft: numbersLeft);
  }
  return null;
}

ReceiptScanResult _parseColumnar(List<List<OcrWord>> rows, _Header header) {
  // The item region runs from just after the header to the first totals line.
  var totalsStart = rows.length;
  for (var i = header.rowIndex + 1; i < rows.length; i++) {
    final joined = rows[i].map((w) => w.text.toLowerCase()).join(' ');
    if (_hasWord(joined, _totalsRegionWords)) {
      totalsStart = i;
      break;
    }
  }

  final items = <ReceiptScanItem>[];
  final confidences = <double>[];
  for (var i = header.rowIndex + 1; i < totalsStart; i++) {
    final item = _itemFromRow(rows[i], header);
    if (item != null) {
      items.add(item);
      confidences.add(item.confidence);
    }
  }

  var serviceMinor = 0;
  var taxMinor = 0;
  var discountMinor = 0;
  int? declaredTotalMinor;
  for (var i = totalsStart; i < rows.length; i++) {
    final joined = rows[i].map((w) => w.text).join(' ');
    final lower = joined.toLowerCase();
    final (amount, _) = _trailingAmount(joined);
    if (amount == null) {
      continue;
    }
    final minor = npr(amount);
    if (lower.contains('discount')) {
      discountMinor += -minor.abs();
    } else if (lower.contains('vat') ||
        (lower.contains('tax') && !lower.contains('invoice'))) {
      taxMinor += minor;
    } else if (lower.contains('service')) {
      serviceMinor += minor;
    } else if (lower.contains('net amount') ||
        lower.contains('grand total') ||
        lower.contains('total amount') ||
        lower.contains('amount payable')) {
      declaredTotalMinor = minor;
    }
  }

  String? merchant;
  String? date;
  for (var i = 0; i < header.rowIndex; i++) {
    final text = rows[i].map((w) => w.text).join(' ').trim();
    date ??= _dateRe.firstMatch(text)?.group(1);
    if (merchant == null &&
        _looksLikeMerchant(text) &&
        !_hasWord(text.toLowerCase(), _noiseWords)) {
      merchant = text;
    }
  }

  final reconciledItems = declaredTotalMinor == null
      ? items
      : _itemsReconciledToPrintedTotal(
          items,
          declaredTotalMinor - serviceMinor - taxMinor - discountMinor,
        );
  final itemsTotal = reconciledItems.fold<int>(
    0,
    (sum, item) => sum + item.amountMinor,
  );
  final totalMinor =
      declaredTotalMinor ??
      (itemsTotal + serviceMinor + taxMinor + discountMinor);
  final resultConfidences = [
    for (final item in reconciledItems) item.confidence,
  ];
  final confidence = resultConfidences.isNotEmpty
      ? resultConfidences.reduce((a, b) => a + b) / resultConfidences.length
      : 0.0;

  return ReceiptScanResult(
    merchant: merchant,
    date: date,
    items: reconciledItems,
    serviceChargeMinor: serviceMinor,
    taxMinor: taxMinor,
    discountMinor: discountMinor,
    totalMinor: totalMinor,
    confidence: confidence,
  );
}

/// Extracts one item from a table row, or null if the row is a continuation
/// line (no number in the Amount column) or otherwise not an item.
ReceiptScanItem? _itemFromRow(List<OcrWord> row, _Header header) {
  final numbers = <(OcrWord, num)>[];
  for (final word in row) {
    if (word.centerX < header.numbersLeft) {
      continue;
    }
    final value = _pureNumber(word.text);
    if (value != null) {
      numbers.add((word, value));
    }
  }
  numbers.sort((a, b) => a.$1.left.compareTo(b.$1.left));
  if (numbers.isEmpty) {
    return null; // wrapped name / HSC continuation — drop it
  }

  // Amount is the right-most number; Qty (when a full Qty/Rate/Amount triple is
  // present) is the left-most small integer.
  final amountBox = numbers.last.$1;
  final amount = numbers.last.$2;
  var quantity = 1;
  if (numbers.length >= 3) {
    final first = numbers.first.$2;
    if (first == first.roundToDouble() && first >= 1 && first <= 99) {
      quantity = first.toInt();
    }
  }

  // The name is every non-numeric box left of the amount. Pure-number boxes
  // (the Sn, Qty and Rate columns) are excluded by value, so a short name like
  // "1L" is kept regardless of where its center lands between the columns.
  final nameBoxes = [
    for (final word in row)
      if (word.left < amountBox.left && _pureNumber(word.text) == null) word,
  ]..sort((a, b) => a.left.compareTo(b.left));
  final name = _cleanItemName(nameBoxes.map((w) => w.text).join(' '));
  if (name.isEmpty || !name.contains(RegExp(r'[A-Za-z]'))) {
    return null;
  }

  final amountMinor = npr(amount);
  final unitMinor = quantity > 0
      ? (amountMinor / quantity).round()
      : amountMinor;
  final confidence =
      row.map((w) => w.confidence).fold<double>(0, (a, b) => a + b) /
      row.length;
  return ReceiptScanItem(
    label: name,
    quantity: quantity,
    unitAmountMinor: unitMinor,
    amountMinor: amountMinor,
    confidence: confidence,
  );
}

/// A box whose text is purely a number (commas/decimals allowed). Rejects
/// tokens with letters like "1L", "41GM", "2PM".
num? _pureNumber(String text) {
  final token = text.trim();
  if (!RegExp(r'^-?[\d,]+(?:\.\d{1,2})?$').hasMatch(token)) {
    return null;
  }
  return _toNum(token);
}

/// Strips a leading serial number and any trailing stray numbers (Qty/Rate that
/// OCR merged into the name box), leaving the first-line product name.
String _cleanItemName(String name) {
  var value = name.trim();
  value = value.replaceFirst(RegExp(r'^\d{1,3}\s*[.):-]?\s+'), '');
  value = value.replaceAll(RegExp(r'(?:\s+-?\d+(?:[.,]\d+)?)+$'), '');
  return _trimEdges(value).trim();
}

/// Classifies OCR lines into a structured bill (items, service charge, VAT,
/// discount, merchant, total). A faithful port of the server-side parser the
/// Python prototype used, validated against the same restaurant-bill cases.
ReceiptScanResult parseReceiptLines(List<OcrTextLine> lines) {
  final rows = [
    for (final line in lines)
      if (line.text.trim().isNotEmpty) (line.text.trim(), line.confidence),
  ];

  final tableResult = _parseRestaurantTableLines(rows);
  if (tableResult != null) {
    return tableResult;
  }

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
    if (_hasWord(labelLower, _subtotalWords) ||
        _hasWord(labelLower, _baseAmountWords)) {
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

ReceiptScanResult? _parseRestaurantTableLines(List<(String, double)> rows) {
  var headerIndex = -1;
  for (var index = 0; index < rows.length; index++) {
    if (_looksLikeRestaurantTableHeader(rows[index].$1)) {
      headerIndex = index;
      break;
    }
  }
  if (headerIndex == -1) {
    return null;
  }

  String? merchant;
  String? date;
  for (var index = 0; index < headerIndex; index++) {
    final text = rows[index].$1;
    final lowered = text.toLowerCase();
    date ??= _dateRe.firstMatch(text)?.group(1);
    if (merchant == null &&
        _looksLikeMerchant(text) &&
        !_hasWord(lowered, _noiseWords)) {
      merchant = text;
    }
  }

  final items = <ReceiptScanItem>[];
  final confidences = <double>[];
  var serviceMinor = 0;
  var taxMinor = 0;
  var discountMinor = 0;
  int? declaredTotalMinor;
  var sawSummary = false;

  for (var index = headerIndex + 1; index < rows.length; index++) {
    final (text, conf) = rows[index];
    final lowered = text.toLowerCase();
    date ??= _dateRe.firstMatch(text)?.group(1);

    if (_isReceiptFooterLine(lowered)) {
      break;
    }

    final (summaryAmount, summaryLabel) = _trailingAmount(text);
    final summaryLower = summaryLabel.toLowerCase();
    if (summaryAmount != null &&
        (_hasWord(summaryLower, _baseAmountWords) ||
            _hasWord(summaryLower, _subtotalWords))) {
      sawSummary = true;
      continue;
    }
    if (summaryAmount != null && _hasWord(summaryLower, _discountWords)) {
      sawSummary = true;
      discountMinor += -npr(summaryAmount).abs();
      confidences.add(conf);
      continue;
    }
    if (summaryAmount != null && _hasWord(summaryLower, _serviceWords)) {
      sawSummary = true;
      serviceMinor += npr(summaryAmount);
      confidences.add(conf);
      continue;
    }
    if (summaryAmount != null && _hasWord(summaryLower, _taxWords)) {
      sawSummary = true;
      taxMinor += npr(summaryAmount);
      confidences.add(conf);
      continue;
    }
    if (summaryAmount != null &&
        _hasWord(summaryLower, _totalWords) &&
        !_hasWord(summaryLower, _subtotalWords)) {
      sawSummary = true;
      declaredTotalMinor = npr(summaryAmount);
      continue;
    }

    if (sawSummary) {
      // Once totals/adjustments have started, random footer numbers are not
      // bill items even if OCR leaves a trailing amount on the line.
      continue;
    }

    final item = _restaurantItemFromLine(text, conf);
    if (item != null) {
      items.add(item);
      confidences.add(item.confidence);
    }
  }

  if (items.isEmpty) {
    return null;
  }

  final reconciledItems = declaredTotalMinor == null
      ? items
      : _itemsReconciledToPrintedTotal(
          items,
          declaredTotalMinor - serviceMinor - taxMinor - discountMinor,
        );
  final itemsTotal = reconciledItems.fold<int>(
    0,
    (sum, item) => sum + item.amountMinor,
  );
  final totalMinor =
      declaredTotalMinor ??
      itemsTotal + serviceMinor + taxMinor + discountMinor;
  final resultConfidences = [
    for (final item in reconciledItems) item.confidence,
  ];
  final confidence = resultConfidences.isNotEmpty
      ? resultConfidences.reduce((a, b) => a + b) / resultConfidences.length
      : 0.0;

  return ReceiptScanResult(
    merchant: merchant,
    date: date,
    items: reconciledItems,
    serviceChargeMinor: serviceMinor,
    taxMinor: taxMinor,
    discountMinor: discountMinor,
    totalMinor: totalMinor,
    confidence: confidence,
  );
}

List<ReceiptScanItem> _itemsReconciledToPrintedTotal(
  List<ReceiptScanItem> items,
  int targetMinor,
) {
  if (items.isEmpty || targetMinor <= 0) {
    return items;
  }
  final currentTotal = items.fold<int>(
    0,
    (sum, item) => sum + item.amountMinor,
  );
  if (currentTotal == targetMinor) {
    return items;
  }

  List<ReceiptScanItem>? best;
  for (var start = 0; start < items.length; start++) {
    var runningTotal = 0;
    for (var end = start; end < items.length; end++) {
      runningTotal += items[end].amountMinor;
      if (runningTotal == targetMinor) {
        final candidate = items.sublist(start, end + 1);
        if (best == null || candidate.length > best.length) {
          best = candidate;
        }
        break;
      }
      if (runningTotal > targetMinor) {
        break;
      }
    }
  }
  return best ?? items;
}

bool _looksLikeRestaurantTableHeader(String text) {
  final lowered = text.toLowerCase();
  return lowered.contains('particular') &&
      lowered.contains('qty') &&
      lowered.contains('rate') &&
      lowered.contains('amount');
}

ReceiptScanItem? _restaurantItemFromLine(String text, double confidence) {
  final matches = _amountToken.allMatches(text).toList();
  if (matches.isEmpty) {
    return null;
  }
  final numbers = <num>[];
  for (final match in matches) {
    if (_unitSuffix.hasMatch(text.substring(match.end))) {
      continue;
    }
    final value = _toNum(match.group(0)!);
    if (value != null) {
      numbers.add(value);
    }
  }
  if (numbers.isEmpty) {
    return null;
  }

  final amount = numbers.last;
  var quantity = 1;
  if (numbers.length >= 3) {
    final qty = numbers[numbers.length - 3];
    if (qty == qty.roundToDouble() && qty >= 1 && qty <= 99) {
      quantity = qty.toInt();
    }
  }

  final amountMatch = matches.last;
  var label = text.substring(0, amountMatch.start).trim();
  if (numbers.length >= 3) {
    final rateMatch = matches[matches.length - 2];
    label = text.substring(0, rateMatch.start).trim();
  }
  label = _cleanItemName(label);
  if (label.isEmpty || !label.contains(RegExp(r'[A-Za-z]'))) {
    return null;
  }
  final lowered = label.toLowerCase();
  if (_hasWord(lowered, _noiseWords) ||
      _hasWord(lowered, _baseAmountWords) ||
      _hasWord(lowered, _totalWords) ||
      _hasWord(lowered, _discountWords) ||
      _hasWord(lowered, _taxWords) ||
      _hasWord(lowered, _serviceWords)) {
    return null;
  }

  final amountMinor = npr(amount);
  final unitMinor = quantity > 0
      ? (amountMinor / quantity).round()
      : amountMinor;
  return ReceiptScanItem(
    label: label,
    quantity: quantity,
    unitAmountMinor: unitMinor,
    amountMinor: amountMinor,
    confidence: confidence,
  );
}

bool _isReceiptFooterLine(String lowered) {
  return lowered.contains('in word') ||
      lowered.contains('in words') ||
      lowered.contains('cashier') ||
      lowered.contains('thank') ||
      lowered.contains('tax invoice') ||
      lowered.contains('collect tax') ||
      lowered.contains('please collect');
}

// A number glued to a unit (50GM, 1L, 250ML) is a weight/volume, not a price.
final _unitSuffix = RegExp(
  r'^\s*(?:gms?|kgs?|mg|ml|ltrs?|ltr|pcs?|pkt|l|g)\b',
  caseSensitive: false,
);

/// Returns (amount, label) by peeling the right-most money token off [text],
/// skipping unit-suffixed numbers like "41GM".
(num?, String) _trailingAmount(String text) {
  final matches = _amountToken.allMatches(text).toList();
  for (var i = matches.length - 1; i >= 0; i--) {
    final match = matches[i];
    if (_unitSuffix.hasMatch(text.substring(match.end))) {
      continue;
    }
    final value = _toNum(match.group(0)!);
    if (value == null) {
      continue;
    }
    final label = (text.substring(0, match.start) + text.substring(match.end))
        .trim()
        .replaceAll(RegExp(r'^[\s.:\-|]+|[\s.:\-|]+$'), '');
    return (value, label);
  }
  return (null, text.trim());
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
