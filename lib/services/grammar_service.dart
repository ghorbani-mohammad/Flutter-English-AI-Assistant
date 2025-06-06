import 'dart:convert';
import '../models/grammar.dart';
import 'auth_service.dart';

class GrammarService {
  final AuthService _authService = AuthService();

  Future<GrammarResponse> getGrammars() async {
    try {
      final response = await _authService.authenticatedRequest(
        method: 'GET',
        endpoint: '/gra/grammar/',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return GrammarResponse.fromJson(jsonData);
      } else {
        throw Exception('Failed to load grammars: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching grammars: $e');
    }
  }
} 