import 'package:flutter_test/flutter_test.dart';
import 'package:sajha_kharcha/shared/ocr/receipt_parser.dart';

ReceiptScanResult parse(List<(String, double)> lines) {
  return parseReceiptLines(
    [for (final (text, conf) in lines) OcrTextLine(text, conf)],
  );
}

void main() {
  test('parses a full restaurant bill into items and adjustments', () {
    final result = parse([
      ('Himalayan Spice Kitchen', 0.99),
      ('Date: 2026-05-30', 0.98),
      ('Chicken Momo x2 300', 0.96),
      ('Pork Belly BBQ 1200', 0.95),
      ('Coke x3 270', 0.92),
      ('Subtotal 1770', 0.97),
      ('Service Charge 177', 0.95),
      ('VAT 13% 253', 0.93),
      ('Discount 100', 0.9),
      ('Grand Total 2100', 0.98),
    ]);

    expect(result.merchant, 'Himalayan Spice Kitchen');
    expect(result.date, '2026-05-30');
    expect(result.items.map((i) => i.label).toList(), [
      'Chicken Momo',
      'Pork Belly BBQ',
      'Coke',
    ]);

    final momo = result.items[0];
    expect(momo.quantity, 2);
    expect(momo.unitAmountMinor, 15000);
    expect(momo.amountMinor, 30000);

    final coke = result.items[2];
    expect(coke.quantity, 3);
    expect(coke.amountMinor, 27000);

    expect(result.serviceChargeMinor, 17700);
    expect(result.taxMinor, 25300);
    expect(result.discountMinor, -10000); // always negative
    expect(result.totalMinor, 210000); // declared total wins
  });

  test('does not clip thousands separators', () {
    final result = parse([('Khasi Meat 6,000', 0.9)]);
    expect(result.items.single.amountMinor, 600000);
  });

  test('computes total when not printed', () {
    final result = parse([
      ('Tea 50', 0.9),
      ('Samosa 80', 0.9),
      ('Service Charge 13', 0.9),
    ]);
    expect(result.totalMinor, 14300);
  });

  test('subtotal and total lines are not items', () {
    final result = parse([('Subtotal 500', 0.9), ('Total 500', 0.9)]);
    expect(result.items, isEmpty);
    expect(result.totalMinor, 50000);
  });

  test('drops noise lines like cash and change', () {
    final result = parse([
      ('Cash 1000', 0.9),
      ('Change 200', 0.9),
      ('Tea 50', 0.9),
    ]);
    expect(result.items.map((i) => i.label).toList(), ['Tea']);
  });
}
