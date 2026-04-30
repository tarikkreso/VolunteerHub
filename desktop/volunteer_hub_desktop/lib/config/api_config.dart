/// API configuration for the VolunteerHub desktop admin app
/// Configure API URL using: flutter run --dart-define=API_URL=http://your-api-url
class ApiConfig {
  // Get API URL from environment variable or use default
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:7000/api', // Localhost for desktop
  );

  // API version prefix
  static const String apiVersion = '/api';

  // Endpoints
  static const String login = '/auth/login';
  static const String users = '/users';
  static const String events = '/events';
  static const String shifts = '/shifts';
  static const String shiftRegistrations = '/shiftregistrations';
  static const String campaigns = '/campaigns';
  static const String donations = '/donations';
  static const String leaderboard = '/leaderboard';
  static const String blogPosts = '/blogposts';
  static const String blogCategories = '/blogcategories';
  static const String categories = '/categories';
  static const String cities = '/cities';
  static const String countries = '/countries';
  static const String skills = '/skills';
  static const String userSkills = '/userskills';
  static const String dashboard = '/dashboard/stats';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
