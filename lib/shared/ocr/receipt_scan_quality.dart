import 'dart:math' as math;

import 'receipt_parser.dart';

/// Scores a parsed receipt so OCR retries can choose the most trustworthy pass.
double receiptScanQualityScore(ReceiptScanResult result) {
  if (result.items.isEmpty) {
    return result.confidence * 8 - 40;
  }

  final usefulItems = result.items.where(_hasUsefulLabel).length;
  final usefulRatio = usefulItems / result.items.length;
  final itemCountScore = math.min(result.items.length, 10) * 6;
  final confidenceScore = result.confidence.clamp(0, 1) * 38;
  final labelScore = usefulRatio * 24;
  final totalScore = receiptScanTotalsAreConsistent(result) ? 32 : -24;
  final merchantScore = result.merchant?.trim().isNotEmpty == true ? 4 : 0;
  final dateScore = result.date?.trim().isNotEmpty == true ? 2 : 0;

  return confidenceScore +
      itemCountScore +
      labelScore +
      totalScore +
      merchantScore +
      dateScore;
}

bool receiptScanTotalsAreConsistent(ReceiptScanResult result) {
  if (result.items.isEmpty || result.totalMinor <= 0) {
    return false;
  }
  final itemTotal = result.items.fold<int>(
    0,
    (sum, item) => sum + item.amountMinor,
  );
  final computedTotal =
      itemTotal +
      result.serviceChargeMinor +
      result.taxMinor +
      result.discountMinor;
  final tolerance = math.max(100, (result.totalMinor * 0.015).round());
  return (computedTotal - result.totalMinor).abs() <= tolerance;
}

bool receiptScanHasUsefulItems(ReceiptScanResult result) {
  if (result.items.isEmpty) {
    return false;
  }
  final usefulItems = result.items.where(_hasUsefulLabel).length;
  return usefulItems >= math.min(2, result.items.length);
}

bool _hasUsefulLabel(ReceiptScanItem item) {
  if (item.amountMinor <= 0) {
    return false;
  }
  final compact = item.label.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '',
  );
  final letters = RegExp(r'[a-z]').allMatches(compact).length;
  final digits = RegExp(r'\d').allMatches(compact).length;
  return compact.length >= 3 && letters >= digits;
}
