import 'package:flutter_test/flutter_test.dart';
import 'package:sajha_kharcha/shared/ocr/live_receipt_stabilizer.dart';
import 'package:sajha_kharcha/shared/ocr/receipt_parser.dart';

void main() {
  test('automatic live scan waits for a matching consistent frame', () {
    final stabilizer = LiveReceiptScanStabilizer();
    final now = DateTime(2026, 5, 30, 21, 30);
    final first = _scanResult(
      confidence: 0.45,
      items: [
        _item('Chk Pattv', 33000, confidence: 0.35),
        _item('Veg Patly', 11500, confidence: 0.35),
        _item('Sausage Roll', 25000, confidence: 0.6),
      ],
      totalMinor: 69500,
    );
    final second = _scanResult(
      confidence: 0.86,
      items: [
        _item('Chicken Patty', 33000, confidence: 0.9),
        _item('Veg Patty', 11500, confidence: 0.86),
        _item('Sausage Roll', 25000, confidence: 0.82),
      ],
      totalMinor: 69500,
    );

    expect(stabilizer.add(first, manual: false, now: now), isNull);

    final accepted = stabilizer.add(
      second,
      manual: false,
      now: now.add(const Duration(seconds: 3)),
    );

    expect(accepted, same(second));
  });

  test('manual live capture accepts one consistent bill result', () {
    final stabilizer = LiveReceiptScanStabilizer();
    final result = _scanResult(
      items: [_item('Cream Doughnut', 15000), _item('Chicken Patty', 24000)],
      totalMinor: 39000,
    );

    expect(stabilizer.add(result, manual: true), same(result));
  });

  test(
    'repeated live frames are rejected when item sum does not match total',
    () {
      final stabilizer = LiveReceiptScanStabilizer();
      final now = DateTime(2026, 5, 30, 21, 35);
      final result = _scanResult(
        items: [_item('Chicken Patty', 33000), _item('Veg Patty', 11500)],
        totalMinor: 69500,
      );

      expect(stabilizer.add(result, manual: false, now: now), isNull);
      expect(
        stabilizer.add(
          result,
          manual: false,
          now: now.add(const Duration(seconds: 3)),
        ),
        isNull,
      );
    },
  );
}

ReceiptScanResult _scanResult({
  required List<ReceiptScanItem> items,
  required int totalMinor,
  double confidence = 0.9,
}) {
  return ReceiptScanResult(
    merchant: 'Paradise Bake & Brew Pvt. Ltd',
    items: items,
    serviceChargeMinor: 0,
    taxMinor: 0,
    discountMinor: 0,
    totalMinor: totalMinor,
    confidence: confidence,
  );
}

ReceiptScanItem _item(
  String label,
  int amountMinor, {
  double confidence = 0.9,
}) {
  return ReceiptScanItem(
    label: label,
    quantity: 1,
    unitAmountMinor: amountMinor,
    amountMinor: amountMinor,
    confidence: confidence,
  );
}
