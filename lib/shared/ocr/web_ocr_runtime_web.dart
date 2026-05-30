import 'dart:js_interop';

import 'ocr_exception.dart';

@JS('PaddleOCR')
external JSAny? get _paddleOcrRuntime;

Future<void> ensureWebOcrRuntimeReady() async {
  if (!_paddleOcrRuntime.isUndefinedOrNull) {
    return;
  }
  throw const ReceiptOcrException(
    'Could not start the bill scanner: PaddleOCR web assets are not loaded. '
    'Generate web/paddleocr_bundle.js from the Bill Scanning setup, then '
    'restart the Flutter web server.',
  );
}

String friendlyOcrStartupMessage(Object error) {
  final message = error.toString();
  if (error is ReceiptOcrException) {
    return error.message;
  }
  if (message.contains('JObject') || message.contains('PaddleOCR')) {
    return 'Could not start the bill scanner: PaddleOCR web assets are not '
        'loaded. Generate web/paddleocr_bundle.js from the Bill Scanning '
        'setup, then restart the Flutter web server.';
  }
  return 'Could not start the bill scanner: $error';
}
