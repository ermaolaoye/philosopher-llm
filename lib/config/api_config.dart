class ApiConfig {
  static const String baseUrl = 'http://192.168.100.144:15555/v1';
  static const String chatEndpoint = '/chat/completions';
  
  // These will be loaded from .env file
  static String? apiKey;
  static const String model = 'gemma-3-27b-it'; // or 'gpt-3.5-turbo' for faster responses
  
  // Temperature controls randomness (0.0 to 2.0)
  static const double temperature = 0.7;
  
  // Maximum tokens in response
  static const int maxTokens = 1000;
} 