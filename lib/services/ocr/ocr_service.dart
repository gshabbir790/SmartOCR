import 'dart:io';

import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

import '../../data/models/ocr_models.dart';
import '../image/image_preprocessor.dart';

/// Common OCR provider interface.
abstract interface class OcrProvider {
  Future<OcrResult> recognize(
    String path, {
    String language = 'eng',
  });
}

/// Local Tesseract OCR implementation.
///
/// Important:
/// - "urd" is mapped to "urd_naw" for better Urdu Nastaliq recognition.
/// - "urd_naw" is the primary Urdu model.
/// - "urd" remains available as a high-accuracy fallback model.
///
/// Required traineddata files:
///   assets/tessdata/eng.traineddata
///   assets/tessdata/urd_naw.traineddata
///   assets/tessdata/urd.traineddata
///   assets/tessdata/ara.traineddata
///   assets/tessdata/hin.traineddata
class LocalTesseractProvider implements OcrProvider {
  /// Maps the app's user-facing language code to the actual
  /// Tesseract traineddata model.
  String _resolveLanguage(String language) {
    switch (language.toLowerCase().trim()) {
      case 'urdu':
      case 'ur':
      case 'urd':
        // Primary Urdu Nastaliq model.
        return 'urd_naw';

      case 'english':
      case 'en':
      case 'eng':
        return 'eng';

      case 'arabic':
      case 'ar':
      case 'ara':
        return 'ara';

      case 'hindi':
      case 'hi':
      case 'hin':
        return 'hin';

      case 'urd_naw':
        return 'urd_naw';

      default:
        return language;
    }
  }

  @override
  Future<OcrResult> recognize(
    String path, {
    String language = 'eng',
  }) async {
    final file = File(path);

    if (!await file.exists()) {
      throw const FileSystemException('Image not found');
    }

    final resolvedLanguage = _resolveLanguage(language);

    final config = OCRConfig(
      language: resolvedLanguage,
      engine: OCREngine.tesseract,
      options: {
        TesseractConfig.preserveInterwordSpaces: '1',

        // auto is more predictable for normal document/poster OCR.
        // autoOsd can incorrectly detect Urdu/Nastaliq orientation/script.
        TesseractConfig.pageSegMode: PageSegmentationMode.auto,
      },
    );

    final text = await TesseractOcr.extractText(
      path,
      config: config,
    );

    final cleaned = _cleanOcrText(
      text,
      language: resolvedLanguage,
    );

    final confidence = _estimateConfidence(
      cleaned,
      language: resolvedLanguage,
    );

    return OcrResult(
      text: cleaned,
      language: resolvedLanguage,
      confidence: confidence,
      blocks: cleaned.isEmpty
          ? []
          : [
              OcrBlock(
                text: cleaned,
                confidence: confidence,
              ),
            ],
    );
  }

  /// Removes OCR artefacts without reversing Urdu/Arabic text.
  ///
  /// IMPORTANT:
  /// We deliberately do NOT reverse RTL text here.
  /// Urdu/Arabic are Unicode bidirectional scripts and reversing the
  /// characters manually can corrupt their natural character order.
  String _cleanOcrText(
    String text, {
    required String language,
  }) {
    var value = text;

    // Remove common invisible bidi control characters that can be
    // accidentally returned by OCR or introduced during processing.
    value = value.replaceAll(
      RegExp(r'[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]'),
      '',
    );

    // Normalize non-breaking spaces.
    value = value.replaceAll('\u00A0', ' ');

    // Remove excessive spaces around line breaks.
    value = value.replaceAll(
      RegExp(r'[ \t]+\n'),
      '\n',
    );

    value = value.replaceAll(
      RegExp(r'\n[ \t]+'),
      '\n',
    );

    // Collapse excessive blank lines while preserving paragraph structure.
    value = value.replaceAll(
      RegExp(r'\n{3,}'),
      '\n\n',
    );

    // Collapse repeated horizontal spaces.
    value = value.replaceAll(
      RegExp(r'[ \t]{2,}'),
      ' ',
    );

    return value.trim();
  }

  /// Tesseract's Dart plugin does not always expose a reliable confidence
  /// value through the simple extractText API, therefore this provides a
  /// conservative text-quality estimate for the existing OcrResult model.
  double _estimateConfidence(
    String text, {
    required String language,
  }) {
    if (text.trim().isEmpty) {
      return 0.0;
    }

    final score = _score(text);

    // Convert our quality score to a stable 0..1 range.
    final normalized = (score / 1000.0).clamp(0.0, 1.0);

    // Keep a sensible floor for readable OCR rather than claiming
    // artificially high confidence.
    return normalized.clamp(0.35, 0.95);
  }
}

/// Supported Tesseract language/model identifiers.
///
/// "urd" remains the public application language code.
///
/// Internally:
///   urd -> urd_naw
///
/// This allows the rest of the application to continue using "urd"
/// without needing to know about the specialized model filename.
const kSupportedOcrLanguages = <String, String>{
  'eng': 'English',

  // Urdu uses urd_naw internally.
  'urd': 'اردو (Urdu)',

  'ara': 'العربية (Arabic)',
  'hin': 'हिन्दी (Hindi)',
};

/// Called with a short, user-facing label whenever OCR moves to a new stage.
typedef OcrProgressCallback = void Function(String stage);

/// Auto-detection language passes.
///
/// IMPORTANT:
/// Urdu Nastaliq is tested separately from Arabic.
///
/// We intentionally DO NOT use:
///   urd+ara
///
/// because combining Urdu and Arabic dictionaries/models in one pass can
/// make Urdu Nastaliq recognition worse.
const _kAutoDetectLanguages = <String, String>{
  'eng': 'Reading English text…',

  // Primary Urdu Nastaliq model.
  'urd_naw': 'Reading Urdu Nastaliq text…',

  // Official high-accuracy Urdu fallback.
  'urd': 'Checking Urdu text…',

  'ara': 'Reading Arabic text…',
  'hin': 'Reading Hindi text…',
};

class OcrService {
  final OcrProvider local = LocalTesseractProvider();

  final ImagePreprocessor _preprocessor = ImagePreprocessor();

  Future<void> init() async {}

  /// Performs local OCR.
  ///
  /// Pipeline:
  ///
  /// 1. Prepare / preprocess image.
  /// 2. Run each supported language independently.
  /// 3. Give Urdu Nastaliq its own dedicated pass.
  /// 4. Compare OCR quality.
  /// 5. Return the strongest result.
  ///
  /// Urdu strategy:
  ///
  ///     urd_naw  -> primary
  ///     urd      -> fallback
  ///
  /// This prevents Arabic OCR from stealing Urdu results.
  Future<OcrResult> recognize(
    String path, {
    OcrProgressCallback? onProgress,
  }) async {
    onProgress?.call('Preparing image…');

    String preparedPath = path;

    try {
      preparedPath = await _preprocessor.prepare(path);
    } catch (_) {
      // If preprocessing fails, OCR the original image.
      preparedPath = path;
    }

    OcrResult? best;
    int bestScore = -1;

    for (final entry in _kAutoDetectLanguages.entries) {
      onProgress?.call(entry.value);

      try {
        final result = await local.recognize(
          preparedPath,
          language: entry.key,
        );

        final score = _score(
          result.text,
          language: entry.key,
        );

        if (score > bestScore) {
          bestScore = score;
          best = result;
        }
      } catch (_) {
        // One failed language should not stop the complete OCR process.
        continue;
      }
    }

    onProgress?.call('Finalizing…');

    if (best == null || best.text.trim().isEmpty) {
      throw const FormatException(
        'No readable text found.',
      );
    }

    return best;
  }

  /// Scores OCR output based on script-aware text quality.
  ///
  /// This is intentionally different from simply counting all Unicode
  /// letters. Urdu and Arabic share the Arabic Unicode block, so we add
  /// Urdu-specific characters and common Nastaliq/Urdu letters where
  /// possible.
  int _score(
    String text, {
    String? language,
  }) {
    final cleaned = text.trim();

    if (cleaned.isEmpty) {
      return -1;
    }

    final totalNonSpace = cleaned
        .replaceAll(RegExp(r'\s'), '')
        .length;

    if (totalNonSpace == 0) {
      return -1;
    }

    final latinLetters = RegExp(
      r'[A-Za-z]',
    ).allMatches(cleaned).length;

    final arabicScriptLetters = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]',
    ).allMatches(cleaned).length;

    final devanagariLetters = RegExp(
      r'[\u0900-\u097F]',
    ).allMatches(cleaned).length;

    // Common Urdu-specific letters.
    final urduSpecificLetters = RegExp(
      r'[ٹڈڑںھہءےؤئۃ]',
    ).allMatches(cleaned).length;

    final digits = RegExp(
      r'[0-9\u0660-\u0669\u06F0-\u06F9]',
    ).allMatches(cleaned).length;

    final punctuation = RegExp(
      r'''[.,!?;:'"(){}\[\]،۔؟؛٪%\-–—]''',
    ).allMatches(cleaned).length;

    int scriptLetters;

    switch (language) {
      case 'eng':
        scriptLetters = latinLetters;
        break;

      case 'hin':
        scriptLetters = devanagariLetters;
        break;

      case 'urd':
      case 'urd_naw':
        scriptLetters = arabicScriptLetters + urduSpecificLetters;
        break;

      case 'ara':
        scriptLetters = arabicScriptLetters;
        break;

      default:
        scriptLetters =
            latinLetters +
            arabicScriptLetters +
            devanagariLetters;
    }

    final meaningfulCharacters =
        scriptLetters + digits + punctuation;

    final ratio = meaningfulCharacters / totalNonSpace;

    int score = (ratio * 1000).round();

    // Reward longer readable text.
    score += scriptLetters * 3;

    // Strong bonus for Urdu-specific characters.
    if (language == 'urd' || language == 'urd_naw') {
      score += urduSpecificLetters * 12;
    }

    // Slight preference for the specialized Urdu model when both
    // Urdu models produce similarly good text.
    if (language == 'urd_naw' && urduSpecificLetters > 0) {
      score += 80;
    }

    return score;
  }
}
