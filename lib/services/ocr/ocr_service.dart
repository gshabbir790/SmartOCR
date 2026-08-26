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
  Future<OcrResult> recognize(String path, {String language = 'eng'}) async {
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
      blocks: cleaned.isEmpty ? [] : [OcrBlock(text: cleaned, confidence: confidence)],
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

/// Called with a short, user-facing label whenever OCR moves to a new stage,
/// so the UI can show real progress instead of a generic spinner.
typedef OcrProgressCallback = void Function(String stage);

/// Auto-detect works by running Tesseract once per language, completely
/// separately, and scoring each attempt's output afterwards. An earlier
/// version combined Urdu and Arabic into one "urd+ara" pass on the
/// (reasonable-sounding) theory that same-script languages are safe to
/// merge — but Urdu's Nastaliq shaping is different enough from Arabic's
/// Naskh-style shaping that mixing their dictionaries made Urdu *worse*,
/// not better. Every language now gets its own fully isolated pass.
const _kAutoDetectLanguages = <String, String>{
  'eng': 'Reading English text…',
  'urd': 'Reading Urdu text…',
  'ara': 'Reading Arabic text…',
  'hin': 'Reading Hindi text…',
};

class OcrService {
  final OcrProvider local = LocalTesseractProvider();
  final ImagePreprocessor _preprocessor = ImagePreprocessor();
  Future<void> init() async {}

  /// Preprocesses [path] (deskew/resize/contrast), then runs Tesseract once
  /// per script group and keeps whichever result actually looks like real
  /// text — this is what gives users "auto-detect" without a language
  /// picker, and without eng+urd+ara+hin scrambling each other.
  Future<OcrResult> recognize(String path, {OcrProgressCallback? onProgress}) async {
    onProgress?.call('Preparing image…');
    String preparedPath = path;
    try {
      preparedPath = await _preprocessor.prepare(path);
    } catch (_) {
      // Fall back to the original image if preprocessing fails for any reason.
      preparedPath = path;
    }

    OcrResult? best;
    int bestScore = -1;
    for (final entry in _kAutoDetectLanguages.entries) {
      onProgress?.call(entry.value);
      final result = await local.recognize(preparedPath, language: entry.key);
      final score = _score(result.text);
      if (score > bestScore) {
        bestScore = score;
        best = result;
      }
    }

    onProgress?.call('Finalizing…');
    if (best == null || best.text.isEmpty) {
      throw const FormatException('No readable text found.');
    }
    return best;
  }

  /// Rewards text that is mostly real letters (Latin, Arabic/Urdu, or
  /// Devanagari) over noise/garbage, so the best-scoring script group wins.
  int _score(String text) {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return -1;
    final letters = RegExp(r'[A-Za-z\u0600-\u06FF\u0750-\u077F\u0900-\u097F]');
    final letterCount = letters.allMatches(cleaned).length;
    final totalNonSpace = cleaned.replaceAll(RegExp(r'\s'), '').length;
    if (totalNonSpace == 0) return -1;
    final ratio = letterCount / totalNonSpace;
    return (ratio * 1000).round() + letterCount;
  }
}
