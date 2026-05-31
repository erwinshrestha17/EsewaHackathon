import 'dart:math' as math;

import 'receipt_parser.dart';
import 'receipt_scan_quality.dart';

/// Keeps live camera OCR from accepting a single noisy frame.
class LiveReceiptScanStabilizer {
  LiveReceiptScanStabilizer({this.window = const Duration(seconds: 14)});

  final Duration window;
  final List<_LiveScanCandidate> _candidates = <_LiveScanCandidate>[];

  void reset() {
    _candidates.clear();
  }

  ReceiptScanResult? add(
    ReceiptScanResult result, {
    required bool manual,
    DateTime? now,
  }) {
    final capturedAt = now ?? DateTime.now();
    _candidates.removeWhere(
      (candidate) => capturedAt.difference(candidate.capturedAt) > window,
    );
    final candidate = _LiveScanCandidate(result, capturedAt);
    _candidates.add(candidate);

    final consistentTotal = receiptScanTotalsAreConsistent(result);
    if (manual && consistentTotal && receiptScanHasUsefulItems(result)) {
      return result;
    }

    final amountMatches = _candidates
        .where((item) => item.amountSignature == candidate.amountSignature)
        .toList();
    final textMatches = _candidates
        .where((item) => item.fullSignature == candidate.fullSignature)
        .toList();
    final matchingCandidates = textMatches.length >= 2
        ? textMatches
        : amountMatches;

    if (matchingCandidates.length < 2 ||
        !consistentTotal ||
        !receiptScanHasUsefulItems(result)) {
      return null;
    }

    matchingCandidates.sort((a, b) {
      final quality = b.qualityScore.compareTo(a.qualityScore);
      if (quality != 0) {
        return quality;
      }
      return b.capturedAt.compareTo(a.capturedAt);
    });
    return matchingCandidates.first.result;
  }
}

class _LiveScanCandidate {
  _LiveScanCandidate(this.result, this.capturedAt)
    : amountSignature = _liveScanAmountSignature(result),
      fullSignature = _liveScanFullSignature(result),
      qualityScore = _liveScanQualityScore(result);

  final ReceiptScanResult result;
  final DateTime capturedAt;
  final String amountSignature;
  final String fullSignature;
  final double qualityScore;
}

String _liveScanAmountSignature(ReceiptScanResult result) {
  final amounts = result.items.map((item) => item.amountMinor).join(',');
  return [
    result.items.length,
    amounts,
    result.serviceChargeMinor,
    result.taxMinor,
    result.discountMinor,
    result.totalMinor,
  ].join('|');
}

String _liveScanFullSignature(ReceiptScanResult result) {
  final merchant = _compactLiveScanToken(result.merchant ?? '');
  final labels = result.items
      .map((item) => _compactLiveScanToken(item.label))
      .join(',');
  return '${_liveScanAmountSignature(result)}|$merchant|$labels';
}

String _compactLiveScanToken(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

double _liveScanQualityScore(ReceiptScanResult result) {
  final confidence = result.confidence.clamp(0, 1).toDouble();
  final itemCountScore = math.min(result.items.length, 8) * 0.08;
  final labelQuality = result.items.isEmpty
      ? 0.0
      : result.items.map(_liveScanItemLabelQuality).reduce((a, b) => a + b) /
            result.items.length;
  final totalScore = receiptScanTotalsAreConsistent(result) ? 0.24 : -0.35;
  return confidence + itemCountScore + (labelQuality * 0.22) + totalScore;
}

double _liveScanItemLabelQuality(ReceiptScanItem item) {
  final compact = _compactLiveScanToken(item.label);
  if (compact.length < 3 || item.amountMinor <= 0) {
    return 0;
  }
  final letters = RegExp(r'[a-z]').allMatches(compact).length;
  final digits = RegExp(r'\d').allMatches(compact).length;
  return letters >= digits ? 1 : 0.45;
}
