class AppConstants {
  static const String appVersion = "v1.10.0";
  static const String appName = "English AI Assistant";
  
  // Full app name with version
  static String get appNameWithVersion => "$appName $appVersion";
  
  // API Configuration
  static const String baseUrl = "https://english-assistant.m-gh.com";
  static const String apiVersion = "/api/v1";
  static const String apiBaseUrl = "$baseUrl$apiVersion";
  
  // Auth endpoints
  static const String generateOtpEndpoint = "/usr/auth/generate-otp/";
  static const String verifyOtpEndpoint = "/usr/auth/verify-otp/";
  static const String refreshTokenEndpoint = "/usr/auth/token/refresh/";
} 