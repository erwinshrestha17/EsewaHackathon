import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_paddle_ocr/flutter_paddle_ocr.dart';
import 'package:image/image.dart' as image;

import 'ocr_exception.dart';
import 'receipt_parser.dart';
import 'receipt_scan_quality.dart';
// dart:io-backed model download on mobile; a throwing stub on web (where the
// bundled paddleocr-js models are used instead).
import 'model_bootstrap_stub.dart'
    if (dart.library.io) 'model_bootstrap_io.dart'
    as bootstrap;
import 'web_ocr_runtime_stub.dart'
    if (dart.library.html) 'web_ocr_runtime_web.dart'
    as web_runtime;

export 'ocr_exception.dart';
export 'receipt_parser.dart' show ReceiptScanItem, ReceiptScanResult;

enum ReceiptOcrMode { fast, accurate }

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
  static const MethodChannel _macosVisionOcrChannel = MethodChannel(
    'sajha_kharcha/macos_vision_ocr',
  );

  // Serializes recognition: the live-scan loop and a gallery scan must never
  // call the shared native/JS engine concurrently.
  static Future<void> _recognizeLock = Future<void>.value();

  /// Scans [bytes] (a JPEG/PNG bill photo) and returns the parsed bill.
  ///
  /// [onStatus] reports human-readable progress (model download, recognition)
  /// so the UI can keep the user informed. Throws [ReceiptOcrException] on any
  /// model-load or recognition failure. Calls are serialized, so overlapping
  /// requests run one after another.
  Future<ReceiptScanResult> scanReceipt(
    Uint8List bytes, {
    void Function(String message)? onStatus,
    ReceiptOcrMode mode = ReceiptOcrMode.accurate,
  }) {
    return _synchronized(() async {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
        return _scanReceiptWithMacosVision(bytes, onStatus: onStatus);
      }
      final engine = await _ensureEngine(onStatus);
      final variants = _receiptImageVariants(bytes, mode: mode);
      final attempts = <_ReceiptScanAttempt>[];
      Object? firstError;

      for (var index = 0; index < variants.length; index++) {
        final variant = variants[index];
        onStatus?.call(
          index == 0
              ? 'Reading the bill…'
              : 'Trying the ${variant.label} OCR pass…',
        );
        try {
          final regions = await engine.recognize(
            variant.bytes,
            runClassification: !kIsWeb,
          );
          final result = parseReceipt([
            for (final region in regions)
              if (region.text.trim().isNotEmpty) _wordFromRegion(region),
          ]);
          attempts.add(_ReceiptScanAttempt(variant.label, result));
          if (mode == ReceiptOcrMode.accurate &&
              index == 0 &&
              _isStrongScan(result)) {
            return result;
          }
        } catch (error) {
          firstError ??= error;
        }
      }

      if (attempts.isEmpty) {
        throw ReceiptOcrException('Could not read the bill: $firstError');
      }
      attempts.sort((a, b) {
        final score = b.score.compareTo(a.score);
        if (score != 0) {
          return score;
        }
        return b.result.confidence.compareTo(a.result.confidence);
      });
      return attempts.first.result;
    });
  }

  /// Runs [action] after any in-flight scan completes, chaining the next one.
  Future<T> _synchronized<T>(Future<T> Function() action) async {
    final previous = _recognizeLock;
    final completer = Completer<void>();
    _recognizeLock = completer.future;
    try {
      await previous;
    } catch (_) {
      // A prior scan's failure must not block the queue.
    }
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  Future<ReceiptScanResult> _scanReceiptWithMacosVision(
    Uint8List bytes, {
    void Function(String message)? onStatus,
  }) async {
    onStatus?.call('Reading the bill…');
    final List<dynamic>? regions;
    try {
      regions = await _macosVisionOcrChannel.invokeListMethod<dynamic>(
        'recognizeReceipt',
        bytes,
      );
    } on MissingPluginException {
      throw const ReceiptOcrException(
        'Bill OCR is not available in this macOS build. Rebuild the macOS app '
        'so the Vision OCR bridge is registered.',
      );
    } on PlatformException catch (error) {
      throw ReceiptOcrException(
        error.message ?? 'Could not read the bill with macOS Vision OCR.',
      );
    } catch (error) {
      throw ReceiptOcrException('Could not read the bill: $error');
    }

    return parseReceiptLines([
      for (final region in regions ?? const <dynamic>[])
        if (region is Map)
          OcrTextLine(
            region['text']?.toString() ?? '',
            (region['confidence'] as num?)?.toDouble() ?? 0,
          ),
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
          : ReceiptOcrException(web_runtime.friendlyOcrStartupMessage(error));
    });
  }

  Future<PaddleOcr> _createEngine(void Function(String)? onStatus) async {
    final ModelSource source;
    if (kIsWeb) {
      await web_runtime.ensureWebOcrRuntimeReady();
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

class _ReceiptImageVariant {
  const _ReceiptImageVariant(this.label, this.bytes);

  final String label;
  final Uint8List bytes;
}

class _ReceiptScanAttempt {
  _ReceiptScanAttempt(this.variantLabel, this.result)
    : score = receiptScanQualityScore(result);

  final String variantLabel;
  final ReceiptScanResult result;
  final double score;
}

List<_ReceiptImageVariant> _receiptImageVariants(
  Uint8List bytes, {
  required ReceiptOcrMode mode,
}) {
  if (mode == ReceiptOcrMode.fast) {
    return [_ReceiptImageVariant('original', bytes)];
  }

  final variants = <_ReceiptImageVariant>[
    _ReceiptImageVariant('original', bytes),
  ];
  final decoded = image.decodeImage(bytes);
  if (decoded == null) {
    return variants;
  }

  final resized = _resizeForOcr(decoded);
  final highContrast = image.Image.from(resized);
  image.grayscale(highContrast);
  image.normalize(highContrast, min: 0, max: 255);
  image.adjustColor(highContrast, contrast: 1.35, brightness: 1.04);
  variants.add(
    _ReceiptImageVariant(
      'high-contrast',
      image.encodeJpg(highContrast, quality: 96),
    ),
  );

  final thresholded = image.Image.from(resized);
  image.grayscale(thresholded);
  image.normalize(thresholded, min: 0, max: 255);
  image.luminanceThreshold(thresholded, threshold: 0.58);
  variants.add(
    _ReceiptImageVariant(
      'threshold',
      image.encodeJpg(thresholded, quality: 96),
    ),
  );

  return variants;
}

image.Image _resizeForOcr(image.Image source) {
  const maxLongSide = 2200;
  final longSide = source.width > source.height ? source.width : source.height;
  if (longSide <= maxLongSide) {
    return source;
  }
  final scale = maxLongSide / longSide;
  return image.copyResize(
    source,
    width: (source.width * scale).round(),
    height: (source.height * scale).round(),
    interpolation: image.Interpolation.average,
  );
}

bool _isStrongScan(ReceiptScanResult result) {
  return result.confidence >= 0.88 &&
      result.items.length >= 2 &&
      receiptScanHasUsefulItems(result) &&
      receiptScanTotalsAreConsistent(result);
}
