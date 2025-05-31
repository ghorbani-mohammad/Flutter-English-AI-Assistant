import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String baseUrl = 'https://english-assistant.m-gh.com/api/v1/gra';

  static Future<String> sendTextMessage(
    String message,
    int grammarId,
    String grammarTitle,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'message': message,
          'grammar_id': grammarId,
          'grammar_title': grammarTitle,
          'type': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['response'] ?? 'Sorry, I couldn\'t process your request.';
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }
} 