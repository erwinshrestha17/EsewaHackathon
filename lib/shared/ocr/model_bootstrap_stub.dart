import 'package:flutter_paddle_ocr/flutter_paddle_ocr.dart';

import 'ocr_exception.dart';

/// Web has no filesystem-backed models — [ReceiptOcrService] uses
/// [ModelSource.bundled] there, so this is never reached. Present only to
/// satisfy the conditional import.
Future<ModelSource> prepareMobileModelSource(
  void Function(String message)? onStatus,
) async {
  throw const ReceiptOcrException(
    'On-device model files are only used on Android and iOS.',
  );
}
