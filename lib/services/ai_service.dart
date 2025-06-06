import 'dart:convert';
import 'dart:typed_data';
import 'auth_service.dart';

class AIService {
  final AuthService _authService = AuthService();

  Future<String> sendTextMessage(
    String message,
    int grammarId,
    String grammarTitle,
  ) async {
    try {
      final response = await _authService.authenticatedRequest(
        method: 'POST',
        endpoint: '/gra/chat/$grammarId/',
        body: {
          'message': message,
          'grammar_id': grammarId,
          'grammar_title': grammarTitle,
          'type': 'text',
        },
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

  Future<String> sendVoiceMessage(
    Uint8List audioBytes,
    int grammarId,
    String grammarTitle,
  ) async {
    try {
      final response = await _authService.authenticatedRequest(
        method: 'POST',
        endpoint: '/gra/chat/$grammarId/',
        body: {
          'audio': base64Encode(audioBytes),
          'grammar_id': grammarId,
          'grammar_title': grammarTitle,
          'type': 'voice',
        },
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