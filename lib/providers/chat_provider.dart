import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/philosopher.dart';
import '../services/openai_service.dart';

class ChatProvider with ChangeNotifier {
  Message? _currentQuestion;
  Message? _currentAnswer;
  Philosopher _selectedPhilosopher = Philosopher.philosophers[0];
  bool _isLoading = false;
  String? _error;
  String _currentStreamingResponse = '';

  Message? get currentQuestion => _currentQuestion;
  Message? get currentAnswer => _currentAnswer;
  Philosopher get selectedPhilosopher => _selectedPhilosopher;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get currentStreamingResponse => _currentStreamingResponse;

  OpenAIService _openAIService;

  ChatProvider() : _openAIService = OpenAIService(philosopher: Philosopher.philosophers[0]);

  void selectPhilosopher(Philosopher philosopher) {
    _selectedPhilosopher = philosopher;
    _openAIService.dispose();
    _openAIService = OpenAIService(philosopher: philosopher);
    _resetCurrentConversation();
    notifyListeners();
  }

  void _resetCurrentConversation() {
    _currentQuestion = null;
    _currentAnswer = null;
    _error = null;
    _currentStreamingResponse = '';
  }

  void resetChat() {
    _resetCurrentConversation();
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;

    _currentQuestion = Message(
      content: content,
      role: MessageRole.user,
    );
    _isLoading = true;
    _error = null;
    _currentStreamingResponse = '';
    notifyListeners();

    try {
      // Create a temporary message for the streaming response
      _currentAnswer = Message(
        content: '',
        role: MessageRole.assistant,
      );

      // Stream the response
      await for (final chunk in _openAIService.sendMessageStream(
        content,
        [
          Message(
            role: MessageRole.system,
            content: _selectedPhilosopher.systemPrompt,
          ),
          _currentQuestion!,
        ],
      )) {
        _currentStreamingResponse += chunk;
        _currentAnswer!.content = _currentStreamingResponse;
        notifyListeners();
      }

      // Clear the streaming response after completion
      _currentStreamingResponse = '';
    } catch (e) {
      _error = e.toString();
      _currentAnswer = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _openAIService.dispose();
    super.dispose();
  }
} 