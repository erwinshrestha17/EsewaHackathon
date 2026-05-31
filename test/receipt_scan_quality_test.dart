import 'package:flutter_test/flutter_test.dart';
import 'package:sajha_kharcha/shared/ocr/receipt_parser.dart';
import 'package:sajha_kharcha/shared/ocr/receipt_scan_quality.dart';

void main() {
  test('scores consistent itemized scans above weak or mismatched scans', () {
    final trusted = _scanResult(
      confidence: 0.9,
      totalMinor: 39000,
      items: [_item('Cream Doughnut', 15000), _item('Chicken Patty', 24000)],
    );
    final mismatched = _scanResult(
      confidence: 0.9,
      totalMinor: 50000,
      items: [_item('Cream Doughnut', 15000), _item('Chicken Patty', 24000)],
    );
    final empty = _scanResult(confidence: 0.95, totalMinor: 0, items: []);

    expect(receiptScanTotalsAreConsistent(trusted), isTrue);
    expect(receiptScanTotalsAreConsistent(mismatched), isFalse);
    expect(
      receiptScanQualityScore(trusted),
      greaterThan(receiptScanQualityScore(mismatched)),
    );
    expect(
      receiptScanQualityScore(mismatched),
      greaterThan(receiptScanQualityScore(empty)),
    );
  });
}

ReceiptScanResult _scanResult({
  required double confidence,
  required int totalMinor,
  required List<ReceiptScanItem> items,
}) {
  return ReceiptScanResult(
    merchant: 'Paradise Bake & Brew Pvt. Ltd',
    date: '2026-05-30',
    items: items,
    serviceChargeMinor: 0,
    taxMinor: 0,
    discountMinor: 0,
    totalMinor: totalMinor,
    confidence: confidence,
  );
}

ReceiptScanItem _item(String label, int amountMinor) {
  return ReceiptScanItem(
    label: label,
    quantity: 1,
    unitAmountMinor: amountMinor,
    amountMinor: amountMinor,
    confidence: 0.9,
  );
}
