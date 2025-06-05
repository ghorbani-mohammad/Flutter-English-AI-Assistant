import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../pages/splash_page.dart';
import '../pages/auth_page.dart';
import '../pages/home_page.dart';

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize auth only once when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.authState == AuthState.loading) {
        authProvider.initializeAuth();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        switch (authProvider.authState) {
          case AuthState.loading:
            return const SplashPage();
          case AuthState.authenticated:
            return const HomePage();
          case AuthState.unauthenticated:
            return const AuthPage();
        }
      },
    );
  }
} 