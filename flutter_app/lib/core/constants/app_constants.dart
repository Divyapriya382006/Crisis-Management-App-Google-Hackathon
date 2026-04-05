// lib/core/constants/app_constants.dart

class AppConstants {
  // API - Configurable via --dart-define=API_URL=https://your-public-url
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://192.168.1.9:8000', // Falls back to local dev machine
  );
  static const String apiVersion = '/api/v1';
  static const String apiBaseUrl = '$baseUrl$apiVersion';

  // Session
  static const int sessionDurationHours = 48;

  // Cache
  static const int cacheMaxAge = 3600; // 1 hour in seconds
  static const String cacheBoxName = 'crisis_cache';
  static const String userBoxName = 'user_data';

  // Map defaults (Chennai, India as demo)
  static const double defaultLat = 13.0827;
  static const double defaultLng = 80.2707;
  static const double defaultZoom = 13.0;

  // Emergency
  static const String policeNumber = '100';
  static const String ambulanceNumber = '108';
  static const String fireNumber = '101';
  static const String womenHelpline = '1091';
  static const String disasterManagement = '1078';

  // Polling interval (ms)
  static const int notificationPollMs = 30000; // 30 seconds
  static const int statsPollMs = 60000;        // 60 seconds
}

class StorageKeys {
  static const String accessToken = 'access_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String userRole = 'user_role';
  static const String userName = 'user_name';
  static const String userEmail = 'user_email';
  static const String sessionExpiry = 'session_expiry';
  static const String accessibilityMode = 'accessibility_mode';
  static const String lastLocation = 'last_location';
}

class RouteNames {
  //static const String splash = '/splash';
  static const String login = '/login';
  static const String adminLogin = '/admin/login';
  static const String home = '/home';
  static const String adminDashboard = '/admin/dashboard';
  static const String emergencyDetail = '/emergency/:type';
  static const String requestHelp = '/request-help';
  static const String aiAssistant = '/assistant';
  static const String settings = '/settings';
  
  static const String responderDashboard = '/responder/dashboard';
}
