import 'dart:io';

import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

import '../../data/models/ocr_models.dart';
import '../image/image_preprocessor.dart';

abstract interface class OcrProvider {
  Future<OcrResult> recognize(String path, {String language = 'eng'});
}

class LocalTesseractProvider implements OcrProvider {
  @override
  Future<OcrResult> recognize(String path, {String language = 'eng'}) async {
    if (!await File(path).exists()) {
      throw const FileSystemException('Image not found');
    }

    final config = OCRConfig(
      language: language,
      engine: OCREngine.tesseract,
      options: <String, dynamic>{
        'preserve_interword_spaces': '1',
        'tessedit_pageseg_mode': '3',
      },
    );

    final text = await TesseractOcr.extractText(path, config: config);
    final cleaned = text.trim();
    final confidence = cleaned.isEmpty ? 0.0 : 0.82;

    return OcrResult(
      text: cleaned,
      language: language,
      confidence: confidence,
      blocks: cleaned.isEmpty
          ? []
          : [OcrBlock(text: cleaned, confidence: confidence)],
    );
  }
}

const kSupportedOcrLanguages = <String, String>{
  'eng': 'English',
  'urd': 'اردو (Urdu)',
  'ara': 'العربية (Arabic)',
  'hin': 'हिन्दी (Hindi)',
};

class OcrService {
  final OcrProvider local = LocalTesseractProvider();
  final ImagePreprocessor _preprocessor = ImagePreprocessor();

  Future<void> init() async {}

  Future<OcrResult> recognize(String path, {String language = 'eng'}) async {
    String preparedPath = path;
    try {
      preparedPath = await _preprocessor.prepare(path);
    } catch (_) {
      preparedPath = path;
    }

    final result = await local.recognize(preparedPath, language: language);
    if (result.text.isEmpty) {
      throw const FormatException('No readable text found.');
    }
    return result;
  }
}
