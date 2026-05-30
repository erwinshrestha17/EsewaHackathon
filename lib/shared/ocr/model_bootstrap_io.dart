import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_paddle_ocr/flutter_paddle_ocr.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'ocr_exception.dart';

// PP-OCRv2 slim models + Chinese dictionary. The Chinese recognizer also covers
// Latin letters and digits, which is what receipt amounts/labels use.
const _modelsUrl =
    'https://paddleocr.bj.bcebos.com/PP-OCRv2/lite/ch_PP-OCRv2.tar.gz';
const _dictUrl =
    'https://paddleocr.bj.bcebos.com/dygraph_v2.0/lite/ch_dict.tar.gz';
const _detName = 'det_db.nb';
const _recName = 'rec_crnn.nb';
const _clsName = 'cls.nb';
const _dictName = 'ppocr_keys_v1.txt';

/// Downloads (once) and caches the Paddle Lite model files for Android/iOS and
/// returns a [ModelSource.filePaths] pointing at them.
Future<ModelSource> prepareMobileModelSource(
  void Function(String message)? onStatus,
) async {
  final root = await getApplicationSupportDirectory();
  final dir = Directory('${root.path}/paddle_ocr');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  File file(String name) => File('${dir.path}/$name');
  final det = file(_detName);
  final rec = file(_recName);
  final cls = file(_clsName);
  final dict = file(_dictName);

  if (!det.existsSync() || !rec.existsSync() || !cls.existsSync()) {
    onStatus?.call('Downloading OCR models…');
    await _downloadAndExtract(_modelsUrl, dir, {_detName, _recName, _clsName});
  }
  if (!dict.existsSync()) {
    onStatus?.call('Downloading OCR dictionary…');
    await _downloadAndExtract(_dictUrl, dir, {_dictName});
  }

  return ModelSource.filePaths(
    det: det.path,
    rec: rec.path,
    dict: dict.path,
    cls: cls.existsSync() ? cls.path : null,
  );
}

/// Fetches a `.tar.gz` and writes any entry whose basename is in [wanted] into
/// [dir], flattening the archive's directory structure.
Future<void> _downloadAndExtract(
  String url,
  Directory dir,
  Set<String> wanted,
) async {
  final Uint8List gz;
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw ReceiptOcrException(
        'Model download failed (HTTP ${response.statusCode}).',
      );
    }
    gz = response.bodyBytes;
  } catch (error) {
    if (error is ReceiptOcrException) {
      rethrow;
    }
    throw ReceiptOcrException('Could not download OCR models: $error');
  }

  final tar = GZipDecoder().decodeBytes(gz);
  final archive = TarDecoder().decodeBytes(tar);
  var found = 0;
  for (final entry in archive) {
    if (!entry.isFile) {
      continue;
    }
    final base = entry.name.split('/').last;
    if (!wanted.contains(base)) {
      continue;
    }
    File('${dir.path}/$base').writeAsBytesSync(entry.content as List<int>);
    found += 1;
  }
  if (found < wanted.length) {
    throw const ReceiptOcrException(
      'OCR model archive was missing expected files.',
    );
  }
}
