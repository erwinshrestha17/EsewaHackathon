import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:esewa_flutter/esewa_flutter.dart';
import 'package:flutter/material.dart';

import '../transactions/transaction_confirmation_data.dart';
import '../transactions/transaction_status.dart';

class EsewaPaymentException implements Exception {
  const EsewaPaymentException(this.message, {this.reference});

  final String message;
  final String? reference;

  @override
  String toString() => message;
}

class EsewaPaymentReceipt {
  const EsewaPaymentReceipt({
    required this.reference,
    required this.transactionUuid,
    required this.encodedData,
    required this.decodedPayload,
  });

  final String reference;
  final String transactionUuid;
  final String encodedData;
  final Map<String, dynamic> decodedPayload;

  String get rawPayload => jsonEncode({
    'provider': 'esewa',
    'transaction_uuid': transactionUuid,
    'data': encodedData,
    'decoded': decodedPayload,
  });
}

class EsewaPaymentService {
  const EsewaPaymentService();

  static const EsewaPaymentService instance = EsewaPaymentService();

  static const _env = String.fromEnvironment('ESEWA_ENV', defaultValue: 'dev');
  static const _productCode = String.fromEnvironment(
    'ESEWA_PRODUCT_CODE',
    defaultValue: 'EPAYTEST',
  );
  static const _uatSecretKey = '8gBm/:&EnhH.1/q';
  static const _secretKey = String.fromEnvironment(
    'ESEWA_SECRET_KEY',
    defaultValue: _uatSecretKey,
  );
  static const _successUrl = String.fromEnvironment(
    'ESEWA_SUCCESS_URL',
    defaultValue: 'https://developer.esewa.com.np/success',
  );
  static const _failureUrl = String.fromEnvironment(
    'ESEWA_FAILURE_URL',
    defaultValue: 'https://developer.esewa.com.np/failure',
  );

  Future<EsewaPaymentReceipt> pay({
    required BuildContext context,
    required TransactionConfirmationData data,
  }) async {
    if (data.amount <= 0) {
      throw const EsewaPaymentException('Amount must be greater than zero.');
    }
    final transactionUuid = _transactionUuidFor(data);
    final config = _configFor(data, transactionUuid);
    final result = await Esewa.i.init(
      context: context,
      eSewaConfig: config,
      walletPageContent: EsewaPageContent(
        appBar: AppBar(title: const Text('Pay with eSewa')),
        progressLoader: const _EsewaCheckoutLoader(),
      ),
    );
    if (result.hasError) {
      throw EsewaPaymentException(
        _friendlyGatewayError(result.error),
        reference: transactionUuid,
      );
    }
    final response = result.data;
    final encodedData = response?.data?.trim();
    if (encodedData == null || encodedData.isEmpty) {
      throw EsewaPaymentException(
        'eSewa did not return a payment confirmation payload.',
        reference: transactionUuid,
      );
    }
    return _verifiedReceipt(
      encodedData: encodedData,
      transactionUuid: transactionUuid,
      expectedAmountMinor: data.amount,
    );
  }

  ESewaConfig _configFor(
    TransactionConfirmationData data,
    String transactionUuid,
  ) {
    final live = _env.toLowerCase() == 'live' || _env.toLowerCase() == 'prod';
    if (live && (_productCode == 'EPAYTEST' || _secretKey == _uatSecretKey)) {
      throw const EsewaPaymentException(
        'Live eSewa credentials are not configured.',
      );
    }
    final amount = data.amount / 100;
    if (live) {
      return ESewaConfig.live(
        amount: amount,
        productCode: _productCode,
        transactionUuid: transactionUuid,
        successUrl: _successUrl,
        failureUrl: _failureUrl,
        secretKey: _secretKey,
      );
    }
    return ESewaConfig.dev(
      amount: amount,
      productCode: _productCode,
      transactionUuid: transactionUuid,
      successUrl: _successUrl,
      failureUrl: _failureUrl,
      secretKey: _secretKey,
    );
  }

  EsewaPaymentReceipt _verifiedReceipt({
    required String encodedData,
    required String transactionUuid,
    required int expectedAmountMinor,
  }) {
    final payload = _decodePayload(encodedData);
    final status = payload['status']?.toString().toUpperCase();
    if (status != 'COMPLETE') {
      throw EsewaPaymentException(
        'eSewa payment status is ${status ?? 'unknown'}.',
        reference: transactionUuid,
      );
    }
    final responseUuid = payload['transaction_uuid']?.toString();
    if (responseUuid != transactionUuid) {
      throw EsewaPaymentException(
        'eSewa returned a different transaction reference.',
        reference: transactionUuid,
      );
    }
    final responseProductCode = payload['product_code']?.toString();
    if (responseProductCode != _productCode) {
      throw EsewaPaymentException(
        'eSewa returned a different merchant product code.',
        reference: transactionUuid,
      );
    }
    final responseAmountMinor = _minorAmount(payload['total_amount']);
    if (responseAmountMinor != expectedAmountMinor) {
      throw EsewaPaymentException(
        'eSewa returned a different payment amount.',
        reference: transactionUuid,
      );
    }
    _verifySignature(payload, transactionUuid);
    return EsewaPaymentReceipt(
      reference:
          payload['transaction_code']?.toString().trim().isNotEmpty == true
          ? payload['transaction_code'].toString()
          : transactionUuid,
      transactionUuid: transactionUuid,
      encodedData: encodedData,
      decodedPayload: payload,
    );
  }

  Map<String, dynamic> _decodePayload(String encodedData) {
    try {
      final normalized = base64.normalize(encodedData);
      final decoded = utf8.decode(base64.decode(normalized));
      final payload = jsonDecode(decoded);
      if (payload is Map<String, dynamic>) {
        return payload;
      }
      if (payload is Map) {
        return payload.map((key, value) => MapEntry(key.toString(), value));
      }
    } on Object catch (error) {
      throw EsewaPaymentException(
        'Could not read eSewa confirmation payload: $error',
      );
    }
    throw const EsewaPaymentException(
      'eSewa confirmation payload was not a valid object.',
    );
  }

  void _verifySignature(Map<String, dynamic> payload, String reference) {
    final signedFieldNames = payload['signed_field_names']?.toString();
    final receivedSignature = payload['signature']?.toString();
    if (signedFieldNames == null ||
        signedFieldNames.trim().isEmpty ||
        receivedSignature == null ||
        receivedSignature.trim().isEmpty) {
      throw EsewaPaymentException(
        'eSewa confirmation did not include a verifiable signature.',
        reference: reference,
      );
    }
    final signatureInput = signedFieldNames
        .split(',')
        .map((fieldName) {
          final trimmed = fieldName.trim();
          if (!payload.containsKey(trimmed)) {
            throw EsewaPaymentException(
              'eSewa signature field "$trimmed" was missing.',
              reference: reference,
            );
          }
          return '$trimmed=${payload[trimmed]}';
        })
        .join(',');
    final digest = Hmac(
      sha256,
      utf8.encode(_secretKey),
    ).convert(utf8.encode(signatureInput));
    final expectedSignature = base64Encode(digest.bytes);
    if (!_constantTimeEquals(expectedSignature, receivedSignature)) {
      throw EsewaPaymentException(
        'eSewa confirmation signature could not be verified.',
        reference: reference,
      );
    }
  }

  int _minorAmount(Object? raw) {
    final value = num.tryParse(raw.toString().replaceAll(',', ''));
    if (value == null) {
      throw const EsewaPaymentException(
        'eSewa returned an unreadable payment amount.',
      );
    }
    return (value * 100).round();
  }

  String _transactionUuidFor(TransactionConfirmationData data) {
    final sanitized = data.idempotencyKey
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-')
        .replaceAll(RegExp('-+'), '-');
    final base = sanitized.isEmpty ? data.id : sanitized;
    if (base.length <= 64) {
      return base;
    }
    final digest = sha256
        .convert(utf8.encode(base))
        .toString()
        .substring(0, 12);
    return '${base.substring(0, 51)}-$digest';
  }

  String _friendlyGatewayError(String? error) {
    final message = error?.trim();
    if (message == null || message.isEmpty) {
      return 'eSewa payment could not be completed.';
    }
    return message;
  }

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) {
      return false;
    }
    var result = 0;
    for (var i = 0; i < left.length; i++) {
      result |= left.codeUnitAt(i) ^ right.codeUnitAt(i);
    }
    return result == 0;
  }
}

class _EsewaCheckoutLoader extends StatelessWidget {
  const _EsewaCheckoutLoader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'Opening eSewa checkout...',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Keep this screen open while the secure payment page loads.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

typedef EsewaReceiptHandler =
    Future<TransactionResult> Function(EsewaPaymentReceipt receipt);

Future<TransactionResult> confirmWithEsewa({
  required BuildContext context,
  required TransactionConfirmationData data,
  required EsewaReceiptHandler onSuccess,
}) async {
  EsewaPaymentReceipt receipt;
  try {
    receipt = await EsewaPaymentService.instance.pay(
      context: context,
      data: data,
    );
  } on EsewaPaymentException catch (error) {
    return TransactionResult.failure(
      reason: error.message,
      amount: data.amount,
      transactionReference:
          error.reference ?? data.transactionReference ?? data.id,
      createdAt: DateTime.now(),
      status: TransactionStatus.failed,
    );
  } on Object catch (error) {
    return TransactionResult.failure(
      reason: error.toString(),
      amount: data.amount,
      transactionReference: data.transactionReference ?? data.id,
      createdAt: DateTime.now(),
      status: TransactionStatus.failed,
    );
  }

  try {
    return await onSuccess(receipt);
  } on Object catch (error) {
    return TransactionResult.failure(
      reason:
          'eSewa payment succeeded, but Sajha Kharcha could not record it: $error',
      amount: data.amount,
      transactionReference: receipt.reference,
      createdAt: DateTime.now(),
      status: TransactionStatus.failedReview,
    );
  }
}
