import 'dart:io';
import 'package:tesseract_ocr/tesseract_ocr.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import '../../data/models/ocr_models.dart';
import '../image/image_preprocessor.dart';

abstract interface class OcrProvider {
  Future<OcrResult> recognize(String path, {String language = 'eng'});
}

class LocalTesseractProvider implements OcrProvider {
  @override
  Future<OcrResult> recognize(String path, {String language = kAutoDetectLanguage}) async {
    // یہاں بریکٹس { } شامل کیے گئے ہیں
    if (!await File(path).exists()) {
      throw const FileSystemException('Image not found');
    }
    
    final config = OCRConfig(
      language: language,
      engine: OCREngine.tesseract,
      options: const {
        TesseractConfig.preserveInterwordSpaces: '1',
      },
    );
    final text = await TesseractOcr.extractText(path, config: config);
    final cleaned = text.trim();
    final confidence = cleaned.isEmpty ? 0.0 : 0.82;
    return OcrResult(
      text: cleaned, 
      language: language, 
      confidence: confidence, 
      blocks: cleaned.isEmpty ? [] : [OcrBlock(text: cleaned, confidence: confidence)]
    );
  }
}

/// Supported Tesseract language codes, driven by the traineddata files
/// shipped in assets/tessdata/ (see that folder's README).
const kSupportedOcrLanguages = <String, String>{
  'eng': 'English',
  'urd': 'اردو (Urdu)',
  'ara': 'العربية (Arabic)',
  'hin': 'हिन्दी (Hindi)',
};

/// Tesseract has no single "detect the language" call, but it can load
/// several language models for one recognition pass and pick whichever
/// characters score best per line. Combining every bundled language here
/// is what gives users the "auto" behaviour: no manual picker needed.
const kAutoDetectLanguage = 'eng+urd+ara+hin';

class OcrService {
  final OcrProvider local = LocalTesseractProvider();
  final ImagePreprocessor _preprocessor = ImagePreprocessor();
  Future<void> init() async {}

  /// Preprocesses [path] (deskew/resize/contrast) before running Tesseract,
  /// which measurably improves accuracy on phone-camera photos.
  Future<OcrResult> recognize(String path, {String language = kAutoDetectLanguage}) async {
    String preparedPath = path;
    try {
      preparedPath = await _preprocessor.prepare(path);
    } catch (_) {
      // Fall back to the original image if preprocessing fails for any reason.
      preparedPath = path;
    }
    final result = await local.recognize(preparedPath, language: language);
    
    // یہاں بھی بریکٹس { } شامل کیے گئے ہیں
    if (result.text.isEmpty) {
      throw const FormatException('No readable text found.');
    }
    
    return result;
  }
}
