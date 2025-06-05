import 'user.dart';

class GenerateOtpResponse {
  final String message;
  final String email;
  final int expiresInMinutes;

  GenerateOtpResponse({
    required this.message,
    required this.email,
    required this.expiresInMinutes,
  });

  factory GenerateOtpResponse.fromJson(Map<String, dynamic> json) {
    return GenerateOtpResponse(
      message: json['message'],
      email: json['email'],
      expiresInMinutes: json['expires_in_minutes'],
    );
  }
}

class AuthTokens {
  final String access;
  final String refresh;

  AuthTokens({
    required this.access,
    required this.refresh,
  });

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      access: json['access'],
      refresh: json['refresh'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access': access,
      'refresh': refresh,
    };
  }
}

class TokenInfo {
  final int accessTokenExpiresInDays;
  final int refreshTokenExpiresInDays;

  TokenInfo({
    required this.accessTokenExpiresInDays,
    required this.refreshTokenExpiresInDays,
  });

  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    return TokenInfo(
      accessTokenExpiresInDays: json['access_token_expires_in_days'],
      refreshTokenExpiresInDays: json['refresh_token_expires_in_days'],
    );
  }
}

class VerifyOtpResponse {
  final String message;
  final User user;
  final AuthTokens tokens;
  final TokenInfo tokenInfo;

  VerifyOtpResponse({
    required this.message,
    required this.user,
    required this.tokens,
    required this.tokenInfo,
  });

  factory VerifyOtpResponse.fromJson(Map<String, dynamic> json) {
    return VerifyOtpResponse(
      message: json['message'],
      user: User.fromJson(json['user']),
      tokens: AuthTokens.fromJson(json['tokens']),
      tokenInfo: TokenInfo.fromJson(json['token_info']),
    );
  }
}

class RefreshTokenResponse {
  final String access;
  final String refresh;

  RefreshTokenResponse({
    required this.access,
    required this.refresh,
  });

  factory RefreshTokenResponse.fromJson(Map<String, dynamic> json) {
    return RefreshTokenResponse(
      access: json['access'],
      refresh: json['refresh'],
    );
  }
} 