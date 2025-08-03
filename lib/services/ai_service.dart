import 'dart:convert';
import 'dart:typed_data';
import 'auth_service.dart';
import '../models/user.dart';

class AIService {
  final AuthService _authService = AuthService();

  Future<String> sendTextMessage(
    String message,
    int grammarId,
    String grammarTitle, {
    int? aiWordCountLimit,
  }) async {
    try {
      final body = {
        'message': message,
        'grammar_id': grammarId,
        'grammar_title': grammarTitle,
        'type': 'text',
      };

      // Add max words if provided
      if (aiWordCountLimit != null && aiWordCountLimit > 0) {
        body['ai_word_count_limit'] = aiWordCountLimit;
      }

      final response = await _authService.authenticatedRequest(
        method: 'POST',
        endpoint: '/gra/chat/$grammarId/',
        body: body,
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
    String grammarTitle, {
    int? aiWordCountLimit,
  }) async {
    try {
      final body = {
        'audio': base64Encode(audioBytes),
        'grammar_id': grammarId,
        'grammar_title': grammarTitle,
        'type': 'voice',
      };

      // Add max words if provided
      if (aiWordCountLimit != null && aiWordCountLimit > 0) {
        body['ai_word_count_limit'] = aiWordCountLimit;
      }

      final response = await _authService.authenticatedRequest(
        method: 'POST',
        endpoint: '/gra/chat/$grammarId/',
        body: body,
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

  // Get current user's max words preference
  Future<int?> getUserMaxWords() async {
    try {
      final user = await _authService.getStoredUser();
      return user?.aiWordCountLimit;
    } catch (e) {
      return null;
    }
  }
} 