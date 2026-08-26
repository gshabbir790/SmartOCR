import 'dart:io';

import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

import '../../data/models/ocr_models.dart';
import '../image/image_preprocessor.dart';

abstract interface class OcrProvider {
  Future<OcrResult> recognize(
    String path, {
    String language = 'eng',
  });
}

/// Local Tesseract OCR provider.
///
/// Urdu strategy:
///   urd -> urd_naw
///
/// The specialized Urdu Nastaliq model is used first.
/// The official high-accuracy `urd` model is used as a fallback
/// when explicitly requested by the OCR service.
class LocalTesseractProvider implements OcrProvider {
  String _resolveLanguage(String language) {
    switch (language.toLowerCase().trim()) {
      case 'ur':
      case 'urdu':
      case 'urd':
        return 'urd_naw';

      case 'urd_naw':
        return 'urd_naw';

      case 'en':
      case 'english':
      case 'eng':
        return 'eng';

      case 'ar':
      case 'arabic':
      case 'ara':
        return 'ara';

      case 'hi':
      case 'hindi':
      case 'hin':
        return 'hin';

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
      options: const {
        TesseractConfig.preserveInterwordSpaces: '1',

        // Do not use autoOsd for Urdu/Nastaliq.
        // It can incorrectly determine script/orientation.
        TesseractConfig.pageSegMode: PageSegmentationMode.auto,
      },
    );

    final text = await TesseractOcr.extractText(
      path,
      config: config,
    );

    final cleaned = _cleanOcrText(text);

    final confidence = cleaned.isEmpty ? 0.0 : 0.82;

    return OcrResult(
      text: cleaned,
      language: resolvedLanguage,
      confidence: confidence,
      blocks: cleaned.isEmpty
          ? const []
          : [
              OcrBlock(
                text: cleaned,
                confidence: confidence,
              ),
            ],
    );
  }

  /// Clean OCR artefacts without reversing Urdu/Arabic characters.
  ///
  /// IMPORTANT:
  /// Urdu must NOT be manually reversed. Unicode bidi rendering
  /// handles RTL presentation at the UI level.
  String _cleanOcrText(String text) {
    var value = text;

    // Remove invisible bidirectional control characters that may
    // appear in OCR output.
    value = value.replaceAll(
      RegExp(r'[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]'),
      '',
    );

    // Normalize non-breaking spaces.
    value = value.replaceAll('\u00A0', ' ');

    // Remove trailing spaces from lines.
    value = value.replaceAll(
      RegExp(r'[ \t]+\n'),
      '\n',
    );

    // Remove leading spaces from lines.
    value = value.replaceAll(
      RegExp(r'\n[ \t]+'),
      '\n',
    );

    // Avoid excessive blank lines.
    value = value.replaceAll(
      RegExp(r'\n{3,}'),
      '\n\n',
    );

    // Avoid excessive horizontal spaces.
    value = value.replaceAll(
      RegExp(r'[ \t]{2,}'),
      ' ',
    );

    return value.trim();
  }
}

/// Supported OCR languages.
///
/// The user-facing Urdu code remains `urd`.
/// LocalTesseractProvider internally maps it to `urd_naw`.
const kSupportedOcrLanguages = <String, String>{
  'eng': 'English',
  'urd': 'اردو (Urdu)',
  'ara': 'العربية (Arabic)',
  'hin': 'हिन्दी (Hindi)',
};

typedef OcrProgressCallback = void Function(String stage);

/// Auto-detection languages.
///
/// Urdu and Arabic are intentionally run separately.
///
/// We DO NOT use:
///     urd+ara
///
/// because Urdu Nastaliq and Arabic recognition behave differently.
const _kAutoDetectLanguages = <String, String>{
  'eng': 'Reading English text…',

  // Specialized Urdu Nastaliq model.
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

  /// Main OCR pipeline.
  ///
  /// 1. Preprocess image.
  /// 2. Run each language separately.
  /// 3. Give Urdu Nastaliq a dedicated pass.
  /// 4. Score each result.
  /// 5. Return the strongest result.
  Future<OcrResult> recognize(
    String path, {
    OcrProgressCallback? onProgress,
  }) async {
    onProgress?.call('Preparing image…');

    String preparedPath = path;

    try {
      preparedPath = await _preprocessor.prepare(path);
    } catch (_) {
      // If preprocessing fails, continue with original image.
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
        // A failure in one language must not stop other OCR passes.
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

  /// Script-aware OCR quality scoring.
  ///
  /// Urdu and Arabic both use the Arabic Unicode ranges, so simply
  /// counting Arabic-script characters is not enough. Urdu-specific
  /// characters receive additional weight.
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

    // Common Urdu-specific characters.
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
        scriptLetters =
            arabicScriptLetters + urduSpecificLetters;
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

    final ratio =
        meaningfulCharacters / totalNonSpace;

    int score = (ratio * 1000).round();

    // Reward longer readable text.
    score += scriptLetters * 3;

    // Strongly reward Urdu-specific characters for Urdu passes.
    if (language == 'urd' || language == 'urd_naw') {
      score += urduSpecificLetters * 12;
    }

    // Give the specialized Nastaliq model a small advantage when
    // it actually produces Urdu-specific characters.
    if (language == 'urd_naw' &&
        urduSpecificLetters > 0) {
      score += 80;
    }

    return score;
  }
}
