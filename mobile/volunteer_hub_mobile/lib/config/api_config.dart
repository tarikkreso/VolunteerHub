import 'package:flutter/foundation.dart';

/// API configuration for the VolunteerHub mobile app
/// Configure API URL using: flutter run --dart-define=API_URL=http://your-api-url
class ApiConfig {
  static const String _configuredBaseUrl =
      String.fromEnvironment('API_URL', defaultValue: '');

  // Get API URL from environment variable or use a platform-safe default.
  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured;
    }

    if (kIsWeb) {
      return 'http://localhost:7000/api';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:7000/api';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:7000/api';
    }
  }

  // API version prefix
  static const String apiVersion = '/api';

  // Endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String users = '/users';
  static const String events = '/events';
  static const String shifts = '/shifts';
  static const String shiftRegistrations = '/shiftregistrations';
  static const String campaigns = '/campaigns';
  static const String donations = '/donations';
  static const String leaderboard = '/leaderboard';
  static const String notifications = '/notifications';
  static const String blogPosts = '/blogposts';
  static const String categories = '/categories';
  static const String cities = '/cities';
  static const String countries = '/countries';
  static const String skills = '/skills';
  static const String dashboard = '/dashboard';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
