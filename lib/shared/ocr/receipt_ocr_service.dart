import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:flutter_paddle_ocr/flutter_paddle_ocr.dart';

import 'ocr_exception.dart';
import 'receipt_parser.dart';
// dart:io-backed model download on mobile; a throwing stub on web (where the
// bundled paddleocr-js models are used instead).
import 'model_bootstrap_stub.dart'
    if (dart.library.io) 'model_bootstrap_io.dart'
    as bootstrap;

export 'ocr_exception.dart';
export 'receipt_parser.dart' show ReceiptScanItem, ReceiptScanResult;

/// Runs PaddleOCR fully on-device (no backend) and turns the recognized text
/// into a structured bill the expense flow can pre-fill.
///
/// Models are loaded once per app run:
///  * mobile (Android/iOS) — the PP-OCRv2 Paddle Lite `.nb` files + dictionary
///    are downloaded and cached on first use, then passed via
///    [ModelSource.filePaths];
///  * web — [ModelSource.bundled] lets paddleocr-js fetch the models itself.
class ReceiptOcrService {
  /// Shared across screens so the model is only loaded once per process.
  static Future<PaddleOcr>? _engineFuture;

  /// Scans [bytes] (a JPEG/PNG bill photo) and returns the parsed bill.
  ///
  /// [onStatus] reports human-readable progress (model download, recognition)
  /// so the UI can keep the user informed. Throws [ReceiptOcrException] on any
  /// model-load or recognition failure.
  Future<ReceiptScanResult> scanReceipt(
    Uint8List bytes, {
    void Function(String message)? onStatus,
  }) async {
    final engine = await _ensureEngine(onStatus);
    onStatus?.call('Reading the bill…');
    final List<OcrResult> regions;
    try {
      regions = await engine.recognize(bytes, runClassification: !kIsWeb);
    } catch (error) {
      throw ReceiptOcrException('Could not read the bill: $error');
    }
    final lines = _groupIntoLines(regions);
    return parseReceiptLines(lines);
  }

  Future<PaddleOcr> _ensureEngine(void Function(String)? onStatus) {
    return _engineFuture ??= _createEngine(onStatus).catchError((Object error) {
      // Let a failed attempt be retried on the next scan.
      _engineFuture = null;
      throw error is ReceiptOcrException
          ? error
          : ReceiptOcrException('Could not start the bill scanner: $error');
    });
  }

  Future<PaddleOcr> _createEngine(void Function(String)? onStatus) async {
    final ModelSource source;
    if (kIsWeb) {
      // paddleocr-js fetches the bundled PP-OCRv5 models on the web backend.
      source = const ModelSource.bundled(lang: 'ch', version: 'PP-OCRv5');
    } else {
      // Downloads + caches the Paddle Lite .nb files on first use (mobile only).
      source = await bootstrap.prepareMobileModelSource(onStatus);
    }
    onStatus?.call('Loading the OCR engine…');
    return PaddleOcr.create(source: source);
  }

  /// Groups detected text regions into reading-order lines.
  ///
  /// PaddleOCR detects each text region separately, so an item label and its
  /// price often arrive as two boxes on the same row. We cluster boxes by
  /// vertical position and join each row left-to-right, which reconstructs
  /// lines like "Chicken Momo 300" that the parser can read.
  List<OcrTextLine> _groupIntoLines(List<OcrResult> regions) {
    final boxes = <_Box>[];
    for (final region in regions) {
      final text = region.text.trim();
      if (text.isEmpty) {
        continue;
      }
      boxes.add(_Box(text, region.confidence, region.points));
    }
    if (boxes.isEmpty) {
      return const <OcrTextLine>[];
    }

    final avgHeight =
        boxes.map((b) => b.height).fold<double>(0, (a, b) => a + b) /
        boxes.length;
    final rowGap = (avgHeight <= 0 ? 12.0 : avgHeight) * 0.6;

    boxes.sort((a, b) => a.centerY.compareTo(b.centerY));

    final lines = <OcrTextLine>[];
    var row = <_Box>[boxes.first];
    var rowY = boxes.first.centerY;
    for (final box in boxes.skip(1)) {
      if ((box.centerY - rowY).abs() <= rowGap) {
        row.add(box);
      } else {
        lines.add(_composeLine(row));
        row = <_Box>[box];
      }
      rowY = box.centerY;
    }
    lines.add(_composeLine(row));
    return lines;
  }

  OcrTextLine _composeLine(List<_Box> row) {
    row.sort((a, b) => a.left.compareTo(b.left));
    final text = row.map((b) => b.text).join(' ');
    final confidence =
        row.map((b) => b.confidence).fold<double>(0, (a, b) => a + b) /
        row.length;
    return OcrTextLine(text, confidence);
  }
}

class _Box {
  _Box(this.text, this.confidence, List<Offset> points)
    : left = points.isEmpty
          ? 0
          : points.map((p) => p.dx).reduce((a, b) => a < b ? a : b),
      centerY = points.isEmpty
          ? 0
          : points.map((p) => p.dy).reduce((a, b) => a + b) / points.length,
      height = points.isEmpty
          ? 0
          : points.map((p) => p.dy).reduce((a, b) => a > b ? a : b) -
                points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);

  final String text;
  final double confidence;
  final double left;
  final double centerY;
  final double height;
}
