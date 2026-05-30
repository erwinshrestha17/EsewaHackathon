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
    return parseReceipt([
      for (final region in regions)
        if (region.text.trim().isNotEmpty) _wordFromRegion(region),
    ]);
  }

  /// Converts an OCR region into a geometry-bearing [OcrWord] for the parser.
  OcrWord _wordFromRegion(OcrResult region) {
    final points = region.points;
    if (points.isEmpty) {
      return OcrWord(
        text: region.text.trim(),
        confidence: region.confidence,
        left: 0,
        right: 0,
        centerY: 0,
        height: 0,
      );
    }
    var minX = points.first.dx;
    var maxX = points.first.dx;
    var minY = points.first.dy;
    var maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }
    return OcrWord(
      text: region.text.trim(),
      confidence: region.confidence,
      left: minX,
      right: maxX,
      centerY: (minY + maxY) / 2,
      height: maxY - minY,
    );
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
}
