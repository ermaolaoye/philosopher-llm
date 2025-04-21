import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../providers/chat_provider.dart';
import '../models/philosopher.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final GlobalKey _screenshotKey = GlobalKey();
  bool _isListening = false;
  String _lastWords = '';
  bool _speechEnabled = false;
  late TextEditingController _textController;
  bool _manualSubmission = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _textController = TextEditingController();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            setState(() {
              _isListening = false;
              if (_lastWords.isNotEmpty && !_manualSubmission) {
                context.read<ChatProvider>().sendMessage(_lastWords);
                _lastWords = '';
                _textController.clear();
              }
              _manualSubmission = false;
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
            _textController.text = _lastWords;
          });
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
          partialResults: true,
        ),
      );
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speech.stop();
      setState(() {
        _isListening = false;
        _lastWords = '';
      });
      _textController.clear();
    }
  }

  Future<void> _captureAndSaveScreenshot() async {
    try {
      // Wait for the next frame to ensure the widget is properly rendered
      await Future.delayed(const Duration(milliseconds: 100));

      final RenderRepaintBoundary boundary = _screenshotKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      
      // Get the size of the chat bubbles
      final chatBubbles = _screenshotKey.currentContext!.findRenderObject() as RenderBox;
      final size = chatBubbles.size;

      // Create a new image with the original background color
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Fill with the original background color
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFEBEBEB),
      );
      
      // Draw the chat bubbles
      canvas.drawImage(image, Offset.zero, Paint());

      final ui.Image finalImage = await recorder.endRecording().toImage(
        (size.width * 3.0).round(),
        (size.height * 3.0).round(),
      );

      final ByteData? byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final directory = await getDownloadsDirectory();
      if (directory == null) return;

      final fileName = 'philosopher_chat_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Screenshot saved to ${directory.path}/$fileName'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving screenshot: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEBEBEB),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Container(
                padding: const EdgeInsets.fromLTRB(40, 20, 40, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 100),
                    Consumer<ChatProvider>(
                      builder: (context, provider, child) {
                        return Text(
                          provider.selectedPhilosopher.name,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 40,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.grey, size: 48),
                            onPressed: _captureAndSaveScreenshot,
                            tooltip: 'Take Screenshot',
                            padding: const EdgeInsets.all(20),
                            constraints: const BoxConstraints(minWidth: 88, minHeight: 88),
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.more_vert, color: Colors.grey, size: 48),
                            onPressed: () => _showPhilosopherSelection(context),
                            tooltip: 'Select Philosopher',
                            padding: const EdgeInsets.all(20),
                            constraints: const BoxConstraints(minWidth: 88, minHeight: 88),
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Chat messages
              Expanded(
                child: RepaintBoundary(
                  key: _screenshotKey,
                  child: Container(
                    color: const Color(0xFFEBEBEB),
                    child: Consumer<ChatProvider>(
                      builder: (context, provider, child) {
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                          itemCount: (provider.currentQuestion != null ? 1 : 0) + 
                                   (provider.currentAnswer != null ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == 0 && provider.currentQuestion != null) {
                              return ChatMessage(
                                content: provider.currentQuestion!.content,
                                isUser: true,
                              );
                            } else {
                              return ChatMessage(
                                content: provider.currentAnswer!.content,
                                isUser: false,
                                avatarPath: provider.selectedPhilosopher.imagePath,
                                name: provider.selectedPhilosopher.name,
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Input area
              Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 28,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: const TextStyle(
                              color: Colors.grey,
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                            isDense: true,
                          ),
                          maxLines: null,
                          minLines: 1,
                          onSubmitted: (text) {
                            if (text.trim().isNotEmpty) {
                              context.read<ChatProvider>().sendMessage(text);
                              _textController.clear();
                              FocusScope.of(context).unfocus();
                            }
                          },
                        ),
                      ),
                    ),
                    Consumer<ChatProvider>(
                      builder: (context, provider, child) {
                        return Container(
                          margin: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: provider.isLoading
                                ? Colors.grey[200]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            padding: const EdgeInsets.all(20),
                            onPressed: provider.isLoading
                                ? null
                                : () {
                                    final text = _textController.text;
                                    if (text.trim().isNotEmpty) {
                                      provider.sendMessage(text);
                                      _textController.clear();
                                      FocusScope.of(context).unfocus();
                                    }
                                  },
                            icon: provider.isLoading
                                ? const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: CircularProgressIndicator(
                                      color: Colors.grey,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_rounded,
                                    color: Colors.grey,
                                    size: 48,
                                  ),
                            style: IconButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhilosopherSelection(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
            maxWidth: 400,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select a Philosopher',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // List
              Flexible(
                child: SingleChildScrollView(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: Philosopher.philosophers.length,
                    itemBuilder: (context, index) {
                      final philosopher = Philosopher.philosophers[index];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            context.read<ChatProvider>().selectPhilosopher(philosopher);
                            Navigator.pop(context);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    image: DecorationImage(
                                      image: AssetImage(philosopher.imagePath),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        philosopher.name,
                                        style: const TextStyle(
                                          color: Colors.black87,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        philosopher.description,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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

  const AnimatedResponse({super.key, required this.text});

  @override
  State<AnimatedResponse> createState() => _AnimatedResponseState();
}

class _AnimatedResponseState extends State<AnimatedResponse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();

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
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedResponse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      // Scroll to bottom when new content is added
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
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
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(179),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(26), width: 1),
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: MarkdownBody(
              data: widget.text,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.6,
                  letterSpacing: 0.3,
                  fontWeight: FontWeight.w300,
                ),
                strong: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                em: const TextStyle(
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String content;
  final bool isUser;
  final String? avatarPath;
  final String? name;

  const ChatMessage({
    super.key,
    required this.content,
    required this.isUser,
    this.avatarPath,
    this.name,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser && avatarPath != null)
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: AssetImage(avatarPath!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  decoration: BoxDecoration(
                    color: isUser 
                        ? const Color(0xFF95EC69)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 0),
                      bottomRight: Radius.circular(isUser ? 0 : 20),
                    ),
                  ),
                  child: MarkdownBody(
                    data: content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(
                        color: Colors.black87,
                        fontSize: 28,
                        height: 1.4,
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w400,
                      ),
                      strong: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                      em: const TextStyle(
                        color: Colors.black87,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/pkulogo.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
