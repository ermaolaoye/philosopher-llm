import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/message.dart';
import '../models/philosopher.dart';

class OpenAIService {
  final http.Client _client;
  final Philosopher _philosopher;

  OpenAIService({required Philosopher philosopher, http.Client? client})
    : _philosopher = philosopher,
      _client = client ?? http.Client();

  Future<bool> testConnection() async {
    try {
      final url = ApiConfig.baseUrl;
      print('Testing connection to: $url');

      final response = await _client.get(Uri.parse(url));
      print('Test connection response: ${response.statusCode}');
      print('Test connection headers: ${response.headers}');
      print('Test connection body: ${response.body}');

      return response.statusCode == 200;
    } catch (e, stackTrace) {
      print('Test connection error: $e');
      print('Stack trace: $stackTrace');
      return false;
    }
  }

  Stream<String> sendMessageStream(
    String userMessage,
    List<Message> chatHistory,
  ) async* {
    if (ApiConfig.apiKey == null) {
      throw Exception('OpenAI API key not set');
    }

    final messages = [
      Message(role: MessageRole.system, content: _philosopher.systemPrompt),
      ...chatHistory.map((msg) => msg.toJson()),
      Message(role: MessageRole.user, content: userMessage).toJson(),
    ];

    final url = '${ApiConfig.baseUrl}${ApiConfig.chatEndpoint}';
    print('Attempting to connect to: $url');

    try {
      // Use compute for parsing operations to avoid blocking the main thread
      final request = http.Request('POST', Uri.parse(url));

      request.headers.addAll({
        'Content-Type': 'application/json',
        'Connection': 'keep-alive', // Add Connection header
        'Accept': 'application/json',
        // Uncomment if you need to use API key
        // 'Authorization': 'Bearer ${ApiConfig.apiKey}',
      });

      // Ensure request timeout is set appropriately
      final requestBody = {
        'model': ApiConfig.model,
        'messages': messages,
        'temperature': ApiConfig.temperature,
        'max_tokens': ApiConfig.maxTokens,
        'stream': true,
      };

      request.body = jsonEncode(requestBody);
      print('Request body: ${request.body}');

      print('Sending request...');
      // Use a timeout to prevent hanging requests
      final response = await _client
          .send(request)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              print('Request timed out');
              throw TimeoutException('Connection to server timed out');
            },
          );

      print('Response received with status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');

      if (response.statusCode != 200) {
        final errorBody = await response.stream.transform(utf8.decoder).join();
        print('Error response body: $errorBody');
        throw Exception(
          'Failed to get response from OpenAI: ${response.statusCode}\nError: $errorBody',
        );
      }

      String buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        print('Received chunk: $chunk');

        final lines = buffer.split('\n\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') {
              print('Stream completed');
              return;
            }

            try {
              final json = jsonDecode(data);
              final content = json['choices'][0]['delta']['content'] ?? '';
              if (content.isNotEmpty) {
                yield content;
              }
            } catch (e) {
              print('Error parsing JSON: $e\nData: $data');
            }
          }
        }
      }
    } catch (e, stackTrace) {
      print('Error in sendMessageStream: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}
