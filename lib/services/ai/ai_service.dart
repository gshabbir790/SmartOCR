import 'dart:convert';
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
