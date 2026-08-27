import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

abstract interface class AiProvider {
  Future<String> ask({required String ocrText, required String question});
}

class BackendAiProvider implements AiProvider {
  BackendAiProvider(this.baseUrl);
  final String baseUrl;
  
  @override
  Future<String> ask({required String ocrText, required String question}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/conversation'), 
      headers: {'content-type': 'application/json'}, 
      body: jsonEncode({'text': ocrText, 'question': question})
    );
    
    // یہاں ہم نے curly braces { } شامل کر دیے ہیں
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI request failed');
    }
    
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['answer'] ?? '').toString();
  }
}

/// Sends an image to the backend's `/api/ocr` endpoint, which forwards it to
/// a vision-capable AI model. Used as a manual, on-demand fallback for
/// images Tesseract handles poorly (decorative/calligraphic Nastaliq
/// graphics, stylized fonts, low-contrast photos). Requires internet and a
/// configured AI backend URL — never runs automatically.
class CloudOcrProvider {
  CloudOcrProvider(this.baseUrl);
  final String baseUrl;

  Future<String> extractText(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _mimeTypeFor(imagePath);

    final response = await http.post(
      Uri.parse('$baseUrl/api/ocr'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'imageBase64': base64Image,
        'mimeType': mimeType,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI OCR request failed');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['text'] ?? '').toString();
  }

  String _mimeTypeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}
