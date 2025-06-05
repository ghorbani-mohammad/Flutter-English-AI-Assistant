import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../models/auth_response.dart';
import '../models/user.dart';

class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';

  // Generate OTP
  Future<GenerateOtpResponse> generateOtp(String email) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}${AppConstants.generateOtpEndpoint}');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Request timed out. Please check your internet connection.');
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return GenerateOtpResponse.fromJson(data);
    } else {
      try {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to generate OTP');
      } catch (e) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    }
  }

  // Verify OTP
  Future<VerifyOtpResponse> verifyOtp(String email, String otpCode) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}${AppConstants.verifyOtpEndpoint}');
    
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'otp_code': otpCode,
      }),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Request timed out. Please check your internet connection.');
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final verifyResponse = VerifyOtpResponse.fromJson(data);
      
      // Store tokens and user data
      await _storeAuthData(verifyResponse);
      
      return verifyResponse;
    } else {
      try {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to verify OTP');
      } catch (e) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    }
  }

  // Refresh Token
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        return false;
      }

      final url = Uri.parse('${AppConstants.apiBaseUrl}${AppConstants.refreshTokenEndpoint}');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'refresh': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final refreshResponse = RefreshTokenResponse.fromJson(data);
        
        // Store new tokens
        await _storeTokens(refreshResponse.access, refreshResponse.refresh);
        
        return true;
      } else {
        // Refresh token is invalid, clear stored data
        await clearAuthData();
        return false;
      }
    } catch (e) {
      await clearAuthData();
      return false;
    }
  }

  // Store authentication data
  Future<void> _storeAuthData(VerifyOtpResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, response.tokens.access);
    await prefs.setString(_refreshTokenKey, response.tokens.refresh);
    await prefs.setString(_userDataKey, jsonEncode(response.user.toJson()));
  }

  // Store tokens only
  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  // Get access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshTokenKey);
  }

  // Get stored user data
  Future<User?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataString = prefs.getString(_userDataKey);
    
    if (userDataString != null) {
      final userData = jsonDecode(userDataString);
      return User.fromJson(userData);
    }
    
    return null;
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final accessToken = await getAccessToken();
    final refreshToken = await getRefreshToken();
    return accessToken != null && refreshToken != null;
  }

  // Clear all authentication data
  Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userDataKey);
  }

  // Logout
  Future<void> logout() async {
    await clearAuthData();
  }

  // Get authorization header
  Future<Map<String, String>> getAuthHeaders() async {
    final accessToken = await getAccessToken();
    if (accessToken != null) {
      return {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };
    }
    return {
      'Content-Type': 'application/json',
    };
  }

  // Make authenticated request with automatic token refresh
  Future<http.Response> authenticatedRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
    final authHeaders = await getAuthHeaders();
    final requestHeaders = {...authHeaders, ...?headers};

    late http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await http.get(url, headers: requestHeaders);
        break;
      case 'POST':
        response = await http.post(
          url,
          headers: requestHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'PUT':
        response = await http.put(
          url,
          headers: requestHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
        break;
      case 'DELETE':
        response = await http.delete(url, headers: requestHeaders);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    // If token is expired, try to refresh and retry the request
    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) {
        // Retry the request with new token
        final newAuthHeaders = await getAuthHeaders();
        final newRequestHeaders = {...newAuthHeaders, ...?headers};

        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(url, headers: newRequestHeaders);
            break;
          case 'POST':
            response = await http.post(
              url,
              headers: newRequestHeaders,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'PUT':
            response = await http.put(
              url,
              headers: newRequestHeaders,
              body: body != null ? jsonEncode(body) : null,
            );
            break;
          case 'DELETE':
            response = await http.delete(url, headers: newRequestHeaders);
            break;
        }
      }
    }

    return response;
  }
} 