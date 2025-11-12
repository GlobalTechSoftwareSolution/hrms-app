class ApiConfig {
  // TODO: Update these URLs based on your Django backend setup
  
  // For local development on physical device, use your computer's IP address
  // For iOS Simulator: use 'localhost' or '127.0.0.1'
  // For Android Emulator: use '10.0.2.2'
  // For physical device: use your computer's IP (e.g., '192.168.1.100')
  
  // IMPORTANT: Change this based on your device:
  // - iOS Simulator: 'http://localhost:8000/api' or 'http://127.0.0.1:8000/api'
  // - Android Emulator: 'http://10.0.2.2:8000/api'
  // - Physical Device: 'http://YOUR_COMPUTER_IP:8000/api' (e.g., 'http://192.168.1.100:8000/api')
  
  static const String baseUrl = 'http://10.0.2.2:8000/api'; // Default for Android Emulator
  
  // Alternative configurations for different environments
  static const String localUrl = 'http://localhost:8000/api'; // iOS Simulator
  static const String androidEmulatorUrl = 'http://10.0.2.2:8000/api'; // Android Emulator
  
  // Production URL (when you deploy your Django backend)
  static const String productionUrl = 'https://globaltechsoftwaresolutions.cloud/api';
  
  // Current environment
  static const bool isProduction = true;
  
  // Get the appropriate URL based on environment
  static String get apiUrl => isProduction ? productionUrl : baseUrl;
  
  // API Endpoints
  static const String loginEndpoint = '/auth/login/';
  static const String registerEndpoint = '/auth/register/';
  static const String logoutEndpoint = '/auth/logout/';
  static const String employeesEndpoint = '/employees/';
  static const String attendanceEndpoint = '/attendance/';
  static const String leavesEndpoint = '/leaves/';
  static const String dashboardEndpoint = '/dashboard/stats/';
  
  // Request timeout duration
  static const Duration requestTimeout = Duration(seconds: 30);
  
  // Token storage key
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
}
