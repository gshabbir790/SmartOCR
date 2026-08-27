import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  /// Runs the heavy pixel work (decode/resize/grayscale/normalize/encode)
  /// on a background isolate via [compute].
  ///
  /// PREVIOUSLY this ran directly on the UI isolate. For a full-resolution
  /// gallery/camera photo (often 3000-4000px wide) that pure-Dart pixel
  /// work can take several seconds, during which the UI thread cannot
  /// paint, animate the progress spinner, or respond to input at all —
  /// which is what shows up on-device as the app "freezing"/"stuck"
  /// while scanning. Moving it into `compute()` keeps the UI responsive
  /// (and lets Android know the app is still alive) while the same work
  /// happens on a separate isolate.
  Future<String> prepare(String inputPath) {
    return compute(_prepareSync, inputPath);
  }
}

/// Must be a top-level (or static) function to run via [compute].
String _prepareSync(String inputPath) {
  final bytes = File(inputPath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return inputPath;

  var image = img.bakeOrientation(decoded);

  // Nastaliq has very thin dots and diacritics. Upscaling before contrast
  // work gives the recognizer more pixels to distinguish these marks.
  if (image.width < 1800) {
    image = img.copyResize(image, width: 1800, interpolation: img.Interpolation.cubic);
  } else if (image.width > 2600) {
    image = img.copyResize(image, width: 2600, interpolation: img.Interpolation.cubic);
  }

  image = img.grayscale(image);
  image = img.normalize(image, min: 8, max: 248);
  image = img.adjustColor(image, contrast: 1.08);

  // Keep a high-quality JPEG; aggressive thresholding is intentionally
  // avoided because it can erase Nastaliq dots/diacritics.
  final dir = File(inputPath).parent.path;
  final output = '$dir/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg';
  File(output).writeAsBytesSync(img.encodeJpg(image, quality: 96));
  return output;
}
