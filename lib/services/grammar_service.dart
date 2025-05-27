import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/grammar.dart';

class GrammarService {
  static const String baseUrl = 'https://english-assistant.m-gh.com/api/v1/gra';

  static Future<GrammarResponse> getGrammars() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/grammar/'),
        headers: {
          'Content-Type': 'application/json',
        },
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