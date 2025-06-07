import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthState {
  loading,
  authenticated,
  unauthenticated,
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  AuthState _authState = AuthState.loading;
  User? _user;
  String? _errorMessage;

  AuthState get authState => _authState;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _authState == AuthState.authenticated;
  bool get isLoading => _authState == AuthState.loading;

  // Initialize auth state
  Future<void> initializeAuth() async {
    _authState = AuthState.loading;
    notifyListeners();

    try {
      final isLoggedIn = await _authService.isLoggedIn();
      if (isLoggedIn) {
        _user = await _authService.getStoredUser();
        
        // Check if current token is valid by making a light API call
        final isTokenValid = await _authService.validateToken();
        if (isTokenValid) {
          _authState = AuthState.authenticated;
        } else {
          // Token is invalid, try to refresh
          final refreshSuccess = await _authService.refreshToken();
          if (refreshSuccess) {
            _authState = AuthState.authenticated;
          } else {
            // Token refresh failed, user needs to login again
            _authState = AuthState.unauthenticated;
            _user = null;
          }
        }
      } else {
        _authState = AuthState.unauthenticated;
      }
    } catch (e) {
      _authState = AuthState.unauthenticated;
      _user = null;
    }

    notifyListeners();
  }

  // Generate OTP
  Future<bool> generateOtp(String email) async {
    try {
      _errorMessage = null;
      notifyListeners();

      await _authService.generateOtp(email);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // Verify OTP and login
  Future<bool> verifyOtpAndLogin(String email, String otpCode) async {
    try {
      _errorMessage = null;
      
      final response = await _authService.verifyOtp(email, otpCode);
      _user = response.user;
      _authState = AuthState.authenticated;
      notifyListeners();
      
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _authState = AuthState.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Get auth service for making authenticated requests
  AuthService get authService => _authService;
} 