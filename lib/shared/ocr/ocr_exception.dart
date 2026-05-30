/// Thrown when on-device OCR cannot be prepared or run.
class ReceiptOcrException implements Exception {
  const ReceiptOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}
