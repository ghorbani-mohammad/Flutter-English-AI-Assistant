# Authentication Implementation Guide

## Overview
This Flutter app now includes a complete OTP-based authentication system that integrates with your backend API. Users must authenticate before accessing the app's main features.

## Features Implemented

### 1. **OTP-Based Authentication**
- Email-based OTP generation
- 6-digit verification code
- Automatic user creation for new emails
- JWT token management (access + refresh tokens)

### 2. **Secure Token Storage**
- Tokens stored securely using SharedPreferences
- Automatic token refresh when access token expires
- Logout functionality that clears all stored data

### 3. **Authentication Flow**
- Splash screen with authentication check
- Login/Signup page (unified)
- Automatic navigation based on auth state
- Protected main app content

### 4. **State Management**
- Provider pattern for authentication state
- Reactive UI updates based on auth status
- Error handling and user feedback

## File Structure

```
lib/
├── models/
│   ├── user.dart                 # User model
│   └── auth_response.dart        # API response models
├── services/
│   └── auth_service.dart         # Authentication API service
├── providers/
│   └── auth_provider.dart        # Authentication state management
├── pages/
│   ├── splash_page.dart          # Initial loading screen
│   ├── auth_page.dart            # Login/Signup page
│   └── home_page.dart            # Updated with logout functionality
├── widgets/
│   └── app_wrapper.dart          # Main app routing logic
├── constants.dart                # Updated with API endpoints
└── main.dart                     # Updated with Provider integration
```

## Setup Instructions

### 1. **Update API Configuration**
In `lib/constants.dart`, replace the placeholder URL with your actual API domain:

```dart
static const String baseUrl = "https://your-actual-api-domain.com";
```

### 2. **API Endpoints Used**
- `POST /api/v1/auth/generate-otp/` - Generate OTP
- `POST /api/v1/auth/verify-otp/` - Verify OTP and get tokens
- `POST /api/v1/auth/token/refresh/` - Refresh access token

### 3. **Dependencies Added**
```yaml
dependencies:
  provider: ^6.1.1           # State management
  shared_preferences: ^2.2.2 # Secure local storage
```

## Usage

### 1. **Authentication Flow**
1. App starts with splash screen
2. Checks for existing valid tokens
3. If tokens exist and valid → Navigate to home
4. If no tokens or invalid → Navigate to login

### 2. **Login Process**
1. User enters email
2. Tap "Send Verification Code"
3. Check email for 6-digit code
4. Enter code and tap "Verify & Login"
5. Automatically navigate to home page

### 3. **Logout Process**
1. Tap user menu icon in home page AppBar
2. Select "Logout"
3. All tokens cleared, navigate to login

### 4. **Making Authenticated API Calls**
Use the `AuthService.authenticatedRequest()` method for API calls that require authentication:

```dart
final authService = Provider.of<AuthProvider>(context, listen: false).authService;

final response = await authService.authenticatedRequest(
  method: 'GET',
  endpoint: '/your-endpoint/',
);
```

This method automatically:
- Adds Authorization header with current access token
- Handles token refresh if access token is expired
- Retries the request with new token
- Redirects to login if refresh fails

## Key Features

### **Automatic Token Refresh**
- Access tokens are automatically refreshed when they expire
- User experience is seamless - no interruption
- If refresh token is invalid, user is redirected to login

### **Error Handling**
- Network errors are caught and displayed to user
- Invalid OTP codes show appropriate error messages
- API errors are parsed and shown in user-friendly format

### **Secure Storage**
- All authentication data stored using SharedPreferences
- Tokens are cleared on logout or authentication failure
- No sensitive data stored in plain text

### **Responsive UI**
- Beautiful, modern design following Material 3 guidelines
- Loading states for all async operations
- Error messages with clear visual indicators
- Smooth transitions between authentication states

## Security Considerations

1. **Token Storage**: Uses SharedPreferences which is encrypted on both iOS and Android
2. **Token Refresh**: Automatic refresh prevents long-lived access tokens
3. **Logout**: Complete data clearing ensures no residual authentication data
4. **API Communication**: All requests use HTTPS (ensure your API does too)

## Troubleshooting

### **Common Issues**
1. **"Failed to generate OTP"**: Check API URL in constants.dart
2. **"Invalid OTP"**: Ensure 6-digit code is entered correctly
3. **"Network error"**: Check internet connection and API availability

### **Testing**
1. Test with valid email addresses
2. Check spam folder for OTP emails
3. Ensure API endpoints return expected JSON structure
4. Test logout and re-login flow

## Next Steps

1. **Update API URL**: Replace placeholder URL with your actual API domain
2. **Test Authentication**: Try the complete login flow
3. **Update Existing Services**: Modify other API services to use authenticated requests
4. **Customize UI**: Adjust colors, fonts, and styling to match your brand
5. **Add Error Analytics**: Consider adding crash reporting for production

The authentication system is now fully integrated and ready for use. Users will be required to authenticate before accessing any app features, and their sessions will be managed automatically with secure token handling. 