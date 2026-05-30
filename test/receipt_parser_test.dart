import 'package:flutter_test/flutter_test.dart';
import 'package:sajha_kharcha/shared/ocr/receipt_parser.dart';

ReceiptScanResult parse(List<(String, double)> lines) {
  return parseReceiptLines([
    for (final (text, conf) in lines) OcrTextLine(text, conf),
  ]);
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

  test('parses Paradise restaurant table without summary rows as items', () {
    final result = parse([
      ('Paradise Bake & Brew Pvt. Ltd', 0.96),
      ('KOT/BOT/COT ORDER LIST', 0.8),
      ('Customer Name: CashParty', 0.88),
      ('SN.Particulars Qty Rate Amount', 0.95),
      ('1. CREAM DOUGHNUT 3 50.00 150.00', 0.93),
      ('2. CHICKEN PATTY 2 120.00 240.00', 0.93),
      ('3. SAUSAGE ROLL 1 120.00 120.00', 0.92),
      ('4. LEMON TEA 3 75.00 225.00', 0.92),
      ('5. CHOCOLATE ROLL 1 65.00 65.00', 0.92),
      ('Basio Amount : 800.00', 0.86),
      ('Total : 800.00', 0.91),
      ('In word : Rs. Eight Hundred only', 0.9),
      ('Cashier : Paradise Time : 09:22AM', 0.9),
      ('Please Collect Tax Invoice From Counter', 0.9),
    ]);

    expect(result.merchant, 'Paradise Bake & Brew Pvt. Ltd');
    expect(result.totalMinor, 80000);
    expect(result.items.map((i) => i.label).toList(), [
      'CREAM DOUGHNUT',
      'CHICKEN PATTY',
      'SAUSAGE ROLL',
      'LEMON TEA',
      'CHOCOLATE ROLL',
    ]);
    expect(result.items.map((i) => i.quantity).toList(), [3, 2, 1, 3, 1]);
    expect(result.items.map((i) => i.amountMinor).toList(), [
      15000,
      24000,
      12000,
      22500,
      6500,
    ]);
  });

  test('uses Paradise total and ignores footer numbers after totals', () {
    final result = parse([
      ('Paradise Bake & Brew Pvt. Ltd', 0.96),
      ('SN.Particulars Qty Rate Amount', 0.95),
      ('1. CHICKEN PATTY 2 165.00 330.00', 0.93),
      ('2. VEG PATTY 1 115.00 115.00', 0.93),
      ('3. SAUSAGE ROLL 2 125.00 250.00', 0.92),
      ('4. OLD BILL TEA 3 75.00 225.00', 0.55),
      ('Basic Amount : 695.00', 0.86),
      ('Discount : 0.00', 0.9),
      ('Total : 695.00', 0.91),
      ('In word : Rs. Six Hundred and Ninety Five only', 0.88),
      ('Time : 09:56AM', 0.86),
    ]);

    expect(result.totalMinor, 69500);
    expect(result.discountMinor, 0);
    expect(result.items.map((i) => i.label).toList(), [
      'CHICKEN PATTY',
      'VEG PATTY',
      'SAUSAGE ROLL',
    ]);
    expect(
      result.items.fold<int>(0, (sum, item) => sum + item.amountMinor),
      69500,
    );
  });

  group('columnar supermarket bill (geometry)', () {
    // Mirrors the Save Super Market layout: Sn | Particulars | Qty | Rate |
    // Amount, with item names wrapping across 2-3 lines, header noise above and
    // a totals/footer block below.
    OcrWord b(String text, double left, double right, double y) => OcrWord(
      text: text,
      confidence: 0.95,
      left: left,
      right: right,
      centerY: y,
      height: 12,
    );

    // Column x-bands: Sn ~30, Particulars 60-250, Qty ~300, Rate ~365, Amount ~440.
    List<OcrWord> superMarketWords() => [
      // Header noise (above the table) — must be excluded from items.
      b('SAURAHA VENTURES PVT.LTD.', 60, 320, 10),
      b('RATNANAGAR-06,SAURAHA', 60, 300, 30),
      b('Bill NO: SI39745-SVS-82/83', 40, 320, 50),
      b('Date : 05/28/2026', 40, 260, 70),
      b('Miti :14/02/2083', 40, 250, 90),
      b('Payment Mode : FonePay', 40, 300, 110),
      // Table header.
      b('Sn', 20, 40, 130),
      b('Particulars', 60, 180, 130),
      b('Qty', 280, 320, 130),
      b('Rate', 350, 390, 130),
      b('Amount', 410, 470, 130),
      // 1: FUNZ POTATO CHIPS (qty 1) + 2 wrapped lines.
      b('FUNZ POTATO CHIPS', 60, 250, 150),
      b('1', 290, 310, 150),
      b('50', 350, 380, 150),
      b('50', 420, 460, 150),
      b('BBQ FLAVOUR 41GM', 60, 250, 170),
      b('HSC:', 60, 110, 190),
      // 2: MISMAS THREE (qty 1) + 3 wrapped lines.
      b('MISMAS THREE', 60, 230, 210),
      b('1', 290, 310, 210),
      b('60', 350, 380, 210),
      b('60', 420, 460, 210),
      b('ANGLE ACHARI', 60, 220, 230),
      b('MASTI 77GM', 60, 200, 250),
      b('HSC:', 60, 110, 270),
      // 3: 2PM CHEESE BALLS (qty 1) — name starts with a digit.
      b('2PM CHEESE BALLS', 60, 250, 290),
      b('1', 290, 310, 290),
      b('355', 350, 390, 290),
      b('355', 415, 460, 290),
      b('60GM', 60, 120, 310),
      b('HSC:', 60, 110, 330),
      // 4: WAI WAI CHICKEN (qty 2, rate 20, amount 40).
      b('WAI WAI CHICKEN', 60, 240, 350),
      b('2', 290, 310, 350),
      b('20', 350, 380, 350),
      b('40', 420, 460, 350),
      b('NOODLES 60GM', 60, 220, 370),
      b('HSC:', 60, 110, 390),
      // 5: 1L (name is "1L"), COCA/FANTA/SPRITE wrapped.
      b('1L', 60, 90, 410),
      b('1', 290, 310, 410),
      b('140', 350, 390, 410),
      b('140', 415, 460, 410),
      b('COCA/FANTA/SPRITE', 60, 250, 430),
      b('HSC:', 60, 110, 450),
      // Totals + footer.
      b('Gross Amount : 645.00', 150, 460, 470),
      b('Discount : 0.00', 150, 460, 490),
      b('Net Amount : 645.00', 150, 460, 510),
      b('Tender : 645.00', 150, 460, 530),
      b('Total Qty : 6.00', 150, 460, 550),
      b('Opening hours:08 AM TO 09 PM', 40, 400, 570),
      b('Counter: TERMINAL-1 ( 7:44PM )', 40, 400, 590),
    ];

    test('extracts exactly the five items with first-line names + price', () {
      final result = parseReceipt(superMarketWords());

      expect(result.items.map((i) => i.label).toList(), [
        'FUNZ POTATO CHIPS',
        'MISMAS THREE',
        '2PM CHEESE BALLS',
        'WAI WAI CHICKEN',
        '1L',
      ]);
      expect(result.items.map((i) => i.amountMinor).toList(), [
        5000,
        6000,
        35500,
        4000,
        14000,
      ]);
    });

    test('reads quantity from the Qty column', () {
      final result = parseReceipt(superMarketWords());
      final waiwai = result.items.firstWhere(
        (i) => i.label == 'WAI WAI CHICKEN',
      );
      expect(waiwai.quantity, 2);
      expect(waiwai.unitAmountMinor, 2000);
      // qty 1 items keep quantity 1.
      expect(result.items.first.quantity, 1);
    });

    test('drops header, footer, totals, and wrapped weight lines', () {
      final result = parseReceipt(superMarketWords());
      final labels = result.items.map((i) => i.label).join(' | ');
      for (final noise in [
        'GM',
        'HSC',
        'Gross',
        'Net',
        'Opening',
        'Counter',
        'Bill',
        'Miti',
        'RATNANAGAR',
        'SAURAHA',
      ]) {
        expect(labels.contains(noise), isFalse, reason: 'leaked "$noise"');
      }
    });

    test('captures totals and zero discount/no VAT', () {
      final result = parseReceipt(superMarketWords());
      expect(result.discountMinor, 0); // Discount 0.00 -> omitted downstream
      expect(result.taxMinor, 0); // no VAT line on this bill
      expect(result.serviceChargeMinor, 0);
      expect(result.totalMinor, 64500); // Net Amount
      expect(result.merchant, 'SAURAHA VENTURES PVT.LTD.');
    });

    test('keeps a short, left-aligned item name (regression for 1L)', () {
      // "1L" box center (66) sits LEFT of the Sn/Particulars midpoint, which the
      // earlier center-band logic would have excluded -> dropped the item.
      final result = parseReceipt([
        b('Sn', 20, 60, 0),
        b('Particulars', 80, 200, 0),
        b('Qty', 280, 320, 0),
        b('Rate', 350, 390, 0),
        b('Amount', 410, 470, 0),
        b('5', 25, 45, 25), // Sn cell (pure number -> excluded from name)
        b('1L', 58, 74, 25), // short name, center 66
        b('1', 290, 310, 25),
        b('140', 350, 388, 25),
        b('140', 415, 458, 25),
        b('Net Amount : 140.00', 150, 460, 50),
      ]);

      expect(result.items.length, 1);
      expect(result.items.single.label, '1L');
      expect(result.items.single.amountMinor, 14000);
    });
  });
}
