import 'dart:math';

import 'models.dart';

int npr(num amount) => (amount * 100).round();

String money(int minor) {
  final sign = minor < 0 ? '-' : '';
  final absolute = minor.abs();
  final rupees = absolute ~/ 100;
  final paisa = absolute % 100;
  if (paisa == 0) {
    return '${sign}NPR $rupees';
  }
  return '${sign}NPR $rupees.${paisa.toString().padLeft(2, '0')}';
}

String shortMoney(int minor) {
  final sign = minor < 0 ? '-' : '';
  final absolute = minor.abs();
  final rupees = absolute / 100;
  if (rupees >= 100000) {
    return '${sign}NPR ${(rupees / 100000).toStringAsFixed(1)}L';
  }
  if (rupees >= 1000) {
    return '${sign}NPR ${(rupees / 1000).toStringAsFixed(1)}k';
  }
  return money(minor);
}

int parseMoneyToMinor(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) {
    return 0;
  }
  return npr(num.tryParse(cleaned) ?? 0);
}

String enumLabel(Object value) {
  final label = value.toString().split('.').last;
  final buffer = StringBuffer();
  for (var i = 0; i < label.length; i++) {
    final char = label[i];
    if (i > 0 && char.toUpperCase() == char && char.toLowerCase() != char) {
      buffer.write(' ');
    }
    buffer.write(i == 0 ? char.toUpperCase() : char);
  }
  return buffer.toString();
}

List<int> distributeByWeights(int totalMinor, List<int> weights) {
  if (weights.isEmpty) {
    return <int>[];
  }
  final totalWeight = weights.fold<int>(0, (sum, item) => sum + item);
  if (totalWeight <= 0) {
    return List<int>.filled(weights.length, 0);
  }

  final raw = <_RemainderShare>[];
  var assigned = 0;
  for (var i = 0; i < weights.length; i++) {
    final exact = totalMinor * weights[i] / totalWeight;
    final floorValue = exact.floor();
    assigned += floorValue;
    raw.add(_RemainderShare(i, floorValue, exact - floorValue));
  }

  var remainder = totalMinor - assigned;
  raw.sort((a, b) {
    final byRemainder = b.remainder.compareTo(a.remainder);
    if (byRemainder != 0) {
      return byRemainder;
    }
    return a.index.compareTo(b.index);
  });
  var cursor = 0;
  while (remainder > 0 && raw.isNotEmpty) {
    raw[cursor % raw.length].value += 1;
    remainder -= 1;
    cursor += 1;
  }
  raw.sort((a, b) => a.index.compareTo(b.index));
  return raw.map((share) => share.value).toList(growable: false);
}

String? roundingRecipientFor({
  required List<String> userIds,
  String? payerId,
  Map<String, int>? payerAmounts,
}) {
  if (userIds.isEmpty) {
    return null;
  }
  if (payerAmounts != null && payerAmounts.isNotEmpty) {
    final eligible =
        payerAmounts.entries
            .where((entry) => userIds.contains(entry.key) && entry.value > 0)
            .toList()
          ..sort((a, b) {
            final byAmount = b.value.compareTo(a.value);
            if (byAmount != 0) {
              return byAmount;
            }
            return userIds.indexOf(a.key).compareTo(userIds.indexOf(b.key));
          });
    if (eligible.isNotEmpty) {
      return eligible.first.key;
    }
  }
  if (payerId != null && userIds.contains(payerId)) {
    return payerId;
  }
  return userIds.first;
}

List<int> equalShares(
  int totalMinor,
  List<String> userIds, {
  String? payerId,
  Map<String, int>? payerAmounts,
  String? remainderUserId,
}) {
  if (userIds.isEmpty) {
    return <int>[];
  }
  final base = totalMinor ~/ userIds.length;
  var remainder = totalMinor - (base * userIds.length);
  final shares = List<int>.filled(userIds.length, base);
  final preferredUserId =
      remainderUserId ??
      roundingRecipientFor(
        userIds: userIds,
        payerId: payerId,
        payerAmounts: payerAmounts,
      );
  final preferredIndex = preferredUserId == null
      ? 0
      : userIds.indexOf(preferredUserId);
  final indices = <int>[
    if (preferredIndex >= 0) preferredIndex,
    for (var index = 0; index < userIds.length; index++)
      if (index != preferredIndex) index,
  ];
  var cursor = 0;
  while (remainder > 0) {
    shares[indices[cursor % indices.length]] += 1;
    remainder -= 1;
    cursor += 1;
  }
  while (remainder < 0) {
    shares[indices[cursor % indices.length]] -= 1;
    remainder += 1;
    cursor += 1;
  }
  return shares;
}

List<int> percentageShares(int totalMinor, List<double> percentages) {
  final sum = percentages.fold<double>(0, (total, item) => total + item);
  if ((sum - 100).abs() > 0.0001) {
    throw ArgumentError('Percentages must total 100%.');
  }
  final scaled = percentages.map((percentage) => (percentage * 10000).round());
  return distributeByWeights(totalMinor, scaled.toList(growable: false));
}

List<int> unitShares(int totalMinor, List<int> units) {
  if (units.any((unit) => unit <= 0)) {
    throw ArgumentError('Shares must be positive.');
  }
  return distributeByWeights(totalMinor, units);
}

void validateCustomShares(int totalMinor, Iterable<int> shares) {
  if (shares.any((amount) => amount < 0)) {
    throw ArgumentError('Custom shares cannot be negative.');
  }
  final sum = shares.fold<int>(0, (total, amount) => total + amount);
  if (sum != totalMinor) {
    throw ArgumentError('Custom shares must add up to ${money(totalMinor)}.');
  }
}

void validatePayerAmounts(int totalMinor, Iterable<int> payerAmounts) {
  if (payerAmounts.any((amount) => amount < 0)) {
    throw ArgumentError('Payer amounts cannot be negative.');
  }
  final sum = payerAmounts.fold<int>(0, (total, amount) => total + amount);
  if (sum != totalMinor) {
    throw ArgumentError('Payer amounts must add up to ${money(totalMinor)}.');
  }
}

Map<String, int> calculateBalances({
  required String groupId,
  required Iterable<GroupMember> members,
  required Iterable<Expense> expenses,
  required Iterable<Settlement> settlements,
  required Iterable<Adjustment> adjustments,
}) {
  final balances = <String, int>{};
  for (final member in members.where((item) => item.groupId == groupId)) {
    balances[member.userId] = 0;
  }
  for (final expense in expenses.where(
    (item) => item.groupId == groupId && item.status == ExpenseStatus.active,
  )) {
    if (expense.payers.isEmpty) {
      balances[expense.payerId] =
          (balances[expense.payerId] ?? 0) + expense.totalMinor;
    } else {
      for (final payer in expense.payers) {
        balances[payer.userId] =
            (balances[payer.userId] ?? 0) + payer.amountMinor;
      }
    }
    for (final share in expense.shares) {
      balances[share.userId] =
          (balances[share.userId] ?? 0) - share.amountMinor;
    }
  }
  for (final settlement in settlements.where(
    (item) => item.groupId == groupId && item.status == PaymentStatus.paid,
  )) {
    balances[settlement.payerId] =
        (balances[settlement.payerId] ?? 0) + settlement.amountMinor;
    balances[settlement.payeeId] =
        (balances[settlement.payeeId] ?? 0) - settlement.amountMinor;
  }
  for (final adjustment in adjustments.where(
    (item) => item.groupId == groupId,
  )) {
    for (final entry in adjustment.entries) {
      final delta = entry.direction == 'credit'
          ? entry.amountMinor
          : -entry.amountMinor;
      balances[entry.userId] = (balances[entry.userId] ?? 0) + delta;
    }
  }
  balances.removeWhere((_, value) => value == 0);
  return balances;
}

List<SettlementSuggestion> simplifySettlements({
  required String groupId,
  required Map<String, int> balances,
  required Iterable<Settlement> settlements,
}) {
  final creditors = balances.entries
      .where((entry) => entry.value > 0)
      .map((entry) => MapEntry(entry.key, entry.value))
      .toList();
  final debtors = balances.entries
      .where((entry) => entry.value < 0)
      .map((entry) => MapEntry(entry.key, entry.value.abs()))
      .toList();

  creditors.sort((a, b) => b.value.compareTo(a.value));
  debtors.sort((a, b) => b.value.compareTo(a.value));

  final suggestions = <SettlementSuggestion>[];
  var debtorIndex = 0;
  var creditorIndex = 0;
  while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
    final debtor = debtors[debtorIndex];
    final creditor = creditors[creditorIndex];
    final amount = min(debtor.value, creditor.value);
    final pending = settlements.where(
      (item) =>
          item.groupId == groupId &&
          item.payerId == debtor.key &&
          item.payeeId == creditor.key &&
          item.amountMinor == amount &&
          item.status == PaymentStatus.pending,
    );
    suggestions.add(
      SettlementSuggestion(
        groupId: groupId,
        payerId: debtor.key,
        payeeId: creditor.key,
        amountMinor: amount,
        pendingSettlementId: pending.isEmpty ? null : pending.first.id,
      ),
    );

    debtors[debtorIndex] = MapEntry(debtor.key, debtor.value - amount);
    creditors[creditorIndex] = MapEntry(creditor.key, creditor.value - amount);
    if (debtors[debtorIndex].value == 0) {
      debtorIndex += 1;
    }
    if (creditors[creditorIndex].value == 0) {
      creditorIndex += 1;
    }
  }
  return suggestions;
}

List<ParsedReceiptItem> parseControlledReceipt(String input) {
  final normalized = input.trim().isEmpty
      ? '''
Khasi meat 6000
Masala packet 650
Cooking gas 900
Transport 1200
Service charge 350
Discount -100
'''
      : input;
  final parser = RegExp(r'^(.+?)\s+(-?\d+(?:\.\d{1,2})?)$', multiLine: true);
  final items = <ParsedReceiptItem>[];
  for (final match in parser.allMatches(normalized)) {
    final label = match.group(1)!.trim();
    final amount = num.tryParse(match.group(2) ?? '');
    if (label.isEmpty || amount == null) {
      continue;
    }
    items.add(
      ParsedReceiptItem(
        label: label,
        amountMinor: npr(amount),
        confidence: label.toLowerCase().contains('cloud') ? 0.78 : 0.94,
      ),
    );
  }
  return items;
}

String dateLabel(DateTime date) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class _RemainderShare {
  _RemainderShare(this.index, this.value, this.remainder);

  final int index;
  int value;
  final double remainder;
}
