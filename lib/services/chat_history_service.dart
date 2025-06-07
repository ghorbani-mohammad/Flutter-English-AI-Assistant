import 'dart:convert';
import '../models/chat_history.dart';
import 'auth_service.dart';

class ChatHistoryService {
  final AuthService _authService = AuthService();

  Future<ChatHistoryResponse> getChatHistory({
    required int grammarId,
    int page = 1,
    int pageSize = 50,
    String? messageType,
    String? senderType,
    String? search,
  }) async {
    try {
      // Build query parameters
      final Map<String, String> queryParams = {
        'page': page.toString(),
        'page_size': pageSize.toString(),
      };

      if (messageType != null && messageType.isNotEmpty) {
        queryParams['message_type'] = messageType;
      }

      if (senderType != null && senderType.isNotEmpty) {
        queryParams['sender_type'] = senderType;
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      // Convert query parameters to URL string
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final endpoint = '/cht/history/$grammarId/?$queryString';

      final response = await _authService.authenticatedRequest(
        method: 'GET',
        endpoint: endpoint,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return ChatHistoryResponse.fromJson(jsonData);
      } else {
        throw Exception('Failed to load chat history: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching chat history: $e');
    }
  }

} 