import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/message.dart';
import '../models/philosopher.dart';

class OpenAIService {
  final http.Client _client;
  final Philosopher _philosopher;

  OpenAIService({
    required Philosopher philosopher,
    http.Client? client,
  })  : _philosopher = philosopher,
        _client = client ?? http.Client();

  Stream<String> sendMessageStream(String userMessage, List<Message> chatHistory) async* {
    if (ApiConfig.apiKey == null) {
      throw Exception('OpenAI API key not set');
    }

    final messages = [
      Message(
        role: MessageRole.system,
        content: _philosopher.systemPrompt,
      ),
      ...chatHistory.map((msg) => msg.toJson()),
      Message(
        role: MessageRole.user,
        content: userMessage,
      ).toJson(),
    ];

    final request = http.Request(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.chatEndpoint}'),
    );

    request.headers.addAll({
      'Content-Type': 'application/json',
      // 'Authorization': 'Bearer ${ApiConfig.apiKey}',
    });

    request.body = jsonEncode({
      'model': ApiConfig.model,
      'messages': messages,
      'temperature': ApiConfig.temperature,
      'max_tokens': ApiConfig.maxTokens,
      'stream': true, // Enable streaming
    });

    final response = await _client.send(request);

    if (response.statusCode != 200) {
      throw Exception('Failed to get response from OpenAI: ${response.statusCode}');
    }

    String buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      
      // Split by double newlines to get individual SSE messages
      final lines = buffer.split('\n\n');
      buffer = lines.removeLast(); // Keep the last incomplete line in the buffer
      
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') {
            return;
          }
          
          try {
            final json = jsonDecode(data);
            final content = json['choices'][0]['delta']['content'] ?? '';
            if (content.isNotEmpty) {
              yield content;
            }
          } catch (e) {
            // Skip invalid JSON
          }
        }
      }
    }
  }

  void dispose() {
    _client.close();
  }
} 