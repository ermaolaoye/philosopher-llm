import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/chat_provider.dart';
import '../models/philosopher.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _lastWords = '';
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            setState(() {
              _isListening = false;
              if (_lastWords.isNotEmpty) {
                context.read<ChatProvider>().sendMessage(_lastWords);
                _lastWords = '';
              }
            });
          }
        },
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          setState(() {
            _isListening = false;
          });
        },
      );
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing speech: $e');
    }
  }

  void _startListening() async {
    if (!_isListening && _speechEnabled) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _lastWords = result.recognizedWords;
          });
        },
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: true,
        partialResults: true,
      );
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Stack(
        children: [
          // Background with philosopher image
          Consumer<ChatProvider>(
            builder: (context, provider, child) {
              return Center(
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage(provider.selectedPhilosopher.imagePath),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(128),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(204),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Consumer<ChatProvider>(
                    builder: (context, provider, child) {
                      return Text(
                        provider.selectedPhilosopher.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1,
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      _buildIconButton(
                        icon: Icons.refresh,
                        onPressed: () => context.read<ChatProvider>().resetChat(),
                        tooltip: 'Reset Chat',
                      ),
                      const SizedBox(width: 16),
                      _buildIconButton(
                        icon: Icons.person,
                        onPressed: () => _showPhilosopherSelection(context),
                        tooltip: 'Select Philosopher',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Response box at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Consumer<ChatProvider>(
              builder: (context, provider, child) {
                if (provider.currentAnswer == null) {
                  return _buildInputArea(context);
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedResponse(
                      text: provider.currentAnswer!.content,
                    ),
                    const SizedBox(height: 16),
                    _buildInputArea(context),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white70),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final textController = TextEditingController();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha(26),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isListening 
                ? Colors.red.withAlpha(51) 
                : _speechEnabled 
                  ? Colors.white.withAlpha(31) 
                  : Colors.white.withAlpha(13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              padding: const EdgeInsets.all(8),
              onPressed: _speechEnabled 
                ? (_isListening ? _stopListening : _startListening)
                : null,
              icon: Icon(
                _isListening 
                  ? Icons.mic 
                  : _speechEnabled 
                    ? Icons.mic_none 
                    : Icons.mic_off,
                color: _isListening 
                  ? Colors.red 
                  : _speechEnabled 
                    ? Colors.white70 
                    : Colors.white30,
                size: 20,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: textController,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
                decoration: InputDecoration(
                  hintText: _isListening ? 'Listening...' : 'Ask a question...',
                  hintStyle: const TextStyle(
                    color: Colors.white30,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                maxLines: null,
                minLines: 1,
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    context.read<ChatProvider>().sendMessage(text);
                    textController.clear();
                  }
                },
              ),
            ),
          ),
          Consumer<ChatProvider>(
            builder: (context, provider, child) {
              return Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: provider.isLoading ? Colors.white.withAlpha(24) : Colors.white.withAlpha(13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  padding: const EdgeInsets.all(8),
                  onPressed: provider.isLoading
                      ? null
                      : () {
                          final text = textController.text;
                          if (text.trim().isNotEmpty) {
                            provider.sendMessage(text);
                            textController.clear();
                          }
                        },
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPhilosopherSelection(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withAlpha(26),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select a Philosopher',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 400,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: Philosopher.philosophers.length,
                  itemBuilder: (context, index) {
                    final philosopher = Philosopher.philosophers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(13),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withAlpha(26),
                          width: 1,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage: AssetImage(philosopher.imagePath),
                        ),
                        title: Text(
                          philosopher.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        subtitle: Text(
                          philosopher.description,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        onTap: () {
                          context.read<ChatProvider>().selectPhilosopher(philosopher);
                          Navigator.pop(context);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedResponse extends StatefulWidget {
  final String text;

  const AnimatedResponse({
    super.key,
    required this.text,
  });

  @override
  State<AnimatedResponse> createState() => _AnimatedResponseState();
}

class _AnimatedResponseState extends State<AnimatedResponse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(179),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withAlpha(26),
              width: 1,
            ),
          ),
          child: Text(
            widget.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.6,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }
} 