import 'dart:convert';
import '../models/expression.dart';
import 'auth_service.dart';

class ExpressionService {
  final AuthService _authService = AuthService();

  Future<ExpressionResponse> getExpressions() async {
    try {
      final response = await _authService.authenticatedRequest(
        method: 'GET',
        endpoint: '/exp/expression/',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return ExpressionResponse.fromJson(jsonData);
      } else {
        throw Exception('Failed to load expressions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching expressions: $e');
    }
  }
} 