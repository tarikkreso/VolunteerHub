/// API configuration for the VolunteerHub mobile app
/// Configure API URL using: flutter run --dart-define=API_URL=http://your-api-url
class ApiConfig {
  // Get API URL from environment variable or use default
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:7000/api', // Android emulator default
  );

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
