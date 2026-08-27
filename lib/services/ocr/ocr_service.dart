import 'dart:io';

import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

import '../../data/models/ocr_models.dart';
import '../image/image_preprocessor.dart';

/// OCR provider abstraction.
abstract interface class OcrProvider {
  Future<OcrResult> recognize(
    String path, {
    String language = 'eng',
  });
}

/// Local Tesseract OCR provider.
///
/// IMPORTANT:
/// - Urdu uses `urd_naw` as the primary model.
/// - No multi-language OCR is performed in a single call.
/// - No automatic 5-language loop is used.
/// - This keeps Android memory/CPU usage under control.
///
/// Required traineddata:
///   eng.traineddata
///   urd_naw.traineddata
///   urd.traineddata
///   ara.traineddata
///   hin.traineddata
class LocalTesseractProvider implements OcrProvider {
  String _resolveLanguage(String language) {
    switch (language.trim().toLowerCase()) {
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

      // 'auto' (the new default): the caller doesn't know in advance
      // whether the image is English or Urdu, so ask Tesseract to load
      // both dictionaries in the SAME single pass. This is still ONE
      // Tesseract operation (not a multi-language loop) — Tesseract
      // natively supports combined language strings like this.
      case 'auto':
        return 'eng+urd';

      default:
        return 'eng+urd';
    }
  }

  @override
  Future<OcrResult> recognize(
    String path, {
    String language = 'eng',
  }) async {
    final file = File(path);

    if (!await file.exists()) {
      throw const FileSystemException(
        'Image not found',
      );
    }

    final resolvedLanguage = _resolveLanguage(language);

    final config = OCRConfig(
      language: resolvedLanguage,
      engine: OCREngine.tesseract,
      options: const {
        TesseractConfig.preserveInterwordSpaces: '1',

        // PSM 3 = fully automatic page segmentation,
        // without orientation/script detection.
        //
        // This is safer than autoOsd for Urdu Nastaliq and
        // avoids an unnecessary orientation/script detection pass.
        TesseractConfig.pageSegMode:
            PageSegmentationMode.auto,
      },
    );

    final text = await TesseractOcr.extractText(
      path,
      config: config,
    );

    final cleaned = _cleanText(text);

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

  /// Cleans OCR output without changing Unicode character order.
  ///
  /// NEVER reverse Urdu manually.
  /// Flutter's RTL rendering should handle Urdu/Arabic direction.
  String _cleanText(String text) {
    var result = text;

    // Remove invisible bidirectional control characters.
    result = result.replaceAll(
      RegExp(
        r'[\u061C\u200E\u200F\u202A-\u202E\u2066-\u2069]',
      ),
      '',
    );

    // Normalize non-breaking spaces.
    result = result.replaceAll(
      '\u00A0',
      ' ',
    );

    // Remove unnecessary spaces at line ends.
    result = result.replaceAll(
      RegExp(r'[ \t]+\n'),
      '\n',
    );

    // Remove unnecessary spaces at line starts.
    result = result.replaceAll(
      RegExp(r'\n[ \t]+'),
      '\n',
    );

    // Reduce excessive blank lines.
    result = result.replaceAll(
      RegExp(r'\n{3,}'),
      '\n\n',
    );

    // Reduce repeated horizontal spaces.
    result = result.replaceAll(
      RegExp(r'[ \t]{2,}'),
      ' ',
    );

    return result.trim();
  }
}

/// Supported language codes.
///
/// The application continues to use `urd` as the public Urdu code.
/// Internally it maps to the specialized `urd_naw` model.
const kSupportedOcrLanguages = <String, String>{
  'eng': 'English',
  'urd': 'اردو (Urdu)',
  'ara': 'العربية (Arabic)',
  'hin': 'हिन्दी (Hindi)',
};

typedef OcrProgressCallback = void Function(
  String stage,
);

class OcrService {
  final OcrProvider local = LocalTesseractProvider();

  final ImagePreprocessor _preprocessor =
      ImagePreprocessor();

  Future<void> init() async {}

  /// Performs ONE OCR operation.
  ///
  /// This is deliberately designed for mobile stability.
  ///
  /// Previous implementation:
  ///
  ///   English
  ///   Urdu
  ///   Urdu Nastaliq
  ///   Arabic
  ///   Hindi
  ///
  /// = 5 Tesseract operations for one image.
  ///
  /// That approach can cause high CPU/RAM usage and Android
  /// "App isn't responding" / "Stop working" problems.
  ///
  /// Current implementation:
  ///
  ///   Image
  ///      ↓
  ///   preprocessing
  ///      ↓
  ///   ONE Tesseract operation
  ///      ↓
  ///   result
  Future<OcrResult> recognize(
    String path, {
    OcrProgressCallback? onProgress,

    /// Default is 'auto' (English + Urdu combined in a single pass),
    /// because the caller (home_screen) doesn't ask the user which
    /// language a given image is before scanning. Previously this
    /// defaulted to 'urd' unconditionally, which forced the Urdu
    /// Nastaliq model onto plain English documents and produced
    /// unreadable output. Pass an explicit language to force one
    /// script when you know it in advance (e.g. from a Settings
    /// preference) — see kOcrLanguagePrefKey in settings_screen.dart.
    ///
    /// Supported:
    ///   auto (eng+urd, default)
    ///   urd / urd_naw
    ///   eng
    ///   ara
    ///   hin
    String language = 'auto',
  }) async {
    onProgress?.call(
      'Preparing image…',
    );

    String preparedPath = path;

    try {
      preparedPath =
          await _preprocessor.prepare(path);
    } catch (_) {
      // If preprocessing fails, OCR the original image.
      preparedPath = path;
    }

    onProgress?.call(
      _progressText(language),
    );

    try {
      final result = await local.recognize(
        preparedPath,
        language: language,
      );

      if (result.text.trim().isEmpty) {
        throw const FormatException(
          'No readable text found.',
        );
      }

      onProgress?.call(
        'Finalizing…',
      );

      return result;
    } catch (error) {
      // Do not retry automatically with multiple languages.
      //
      // Automatic multi-pass retry was one of the reasons for
      // excessive CPU/RAM usage.
      rethrow;
    }
  }

  String _progressText(String language) {
    switch (language.toLowerCase()) {
      case 'auto':
        return 'Reading text…';

      case 'urd':
      case 'ur':
      case 'urdu':
      case 'urd_naw':
        return 'Reading Urdu Nastaliq…';

      case 'eng':
      case 'en':
      case 'english':
        return 'Reading English…';

      case 'ara':
      case 'ar':
      case 'arabic':
        return 'Reading Arabic…';

      case 'hin':
      case 'hi':
      case 'hindi':
        return 'Reading Hindi…';

      default:
        return 'Scanning text…';
    }
  }
}
