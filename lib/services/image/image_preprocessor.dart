import 'dart:io';
import 'package:image/image.dart' as img;

class ImagePreprocessor {
  Future<String> prepare(String inputPath) async {
    final bytes = await File(inputPath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return inputPath;
    var image = img.bakeOrientation(decoded);
    if (image.width > 2200) image = img.copyResize(image, width: 2200);
    // Grayscale + normalize give Tesseract cleaner character edges to work
    // with, which matters most on compressed/low-quality phone photos
    // (WhatsApp-forwarded images in particular).
    image = img.grayscale(image);
    image = img.normalize(image, min: 0, max: 255);
    image = img.adjustColor(image, contrast: 1.15);
    final dir = File(inputPath).parent.path;
    final output = '$dir/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await File(output).writeAsBytes(img.encodeJpg(image, quality: 92));
    return output;
  }
}
