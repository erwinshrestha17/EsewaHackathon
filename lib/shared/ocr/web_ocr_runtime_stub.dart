import 'ocr_exception.dart';

Future<void> ensureWebOcrRuntimeReady() async {}

String friendlyOcrStartupMessage(Object error) {
  if (error is ReceiptOcrException) {
    return error.message;
  }
  return 'Could not start the bill scanner: $error';
}
