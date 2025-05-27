import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/expression.dart';

class ExpressionService {
  static const String baseUrl = 'https://english-assistant.m-gh.com/api/v1/exp';

  static Future<ExpressionResponse> getExpressions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/expression/'),
        headers: {
          'Content-Type': 'application/json',
        },
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