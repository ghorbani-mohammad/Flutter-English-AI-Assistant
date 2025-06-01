import 'dart:convert';
import 'dart:typed_data';
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
        Uri.parse('$baseUrl/chat/$grammarId/'),
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

  static Future<String> sendVoiceMessage(
    Uint8List audioBytes,
    int grammarId,
    String grammarTitle,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/$grammarId/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'audio': base64Encode(audioBytes),
          'grammar_id': grammarId,
          'grammar_title': grammarTitle,
          'type': 'voice',
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return jsonData['response'] ?? 'Sorry, I couldn\'t process your voice message.';
      } else {
        throw Exception('Failed to send voice message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending voice message: $e');
    }
  }
} 