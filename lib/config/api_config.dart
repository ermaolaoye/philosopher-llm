class ApiConfig {
  // OpenWebUI API settings
  static const String baseUrl = 'http://ermaolaoye.natapp1.cc/api';
  static const String chatEndpoint = '/chat/completions';

  // These will be loaded from .env file
  static String? apiKey;
  static const String model = 'gemma3:27b'; // Default model, can be changed

  // Temperature controls randomness (0.0 to 2.0)
  static const double temperature = 0.7;

  // Maximum tokens in response
  static const int maxTokens = 1000;
}
