import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'providers/chat_provider.dart';
import 'screens/chat_screen.dart';
import 'config/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await dotenv.load(fileName: ".env");
  // ApiConfig.apiKey = dotenv.env['OPENWEBUI_API_KEY'];
  
  // Set the API key if needed (might be empty for local OpenWebUI instances)
  ApiConfig.apiKey = 'sk-4adef9e59b4743c391fc2a9cce537b44';
  
  // Initialize window manager only for desktop platforms
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
    await windowManager.ensureInitialized();
    
    // Set window to full screen
    WindowOptions windowOptions = const WindowOptions(
      fullScreen: true,
    );
    
    await windowManager.waitUntilReadyToShow(windowOptions);
    await windowManager.show();
    await windowManager.focus();
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: MaterialApp(
        title: 'Philosopher Chat',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const KeyboardListenerWrapper(child: ChatScreen()),
      ),
    );
  }
}

class KeyboardListenerWrapper extends StatefulWidget {
  final Widget child;
  
  const KeyboardListenerWrapper({
    super.key,
    required this.child,
  });

  @override
  State<KeyboardListenerWrapper> createState() => _KeyboardListenerWrapperState();
}

class _KeyboardListenerWrapperState extends State<KeyboardListenerWrapper> {
  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(_handleKey);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKey);
    super.dispose();
  }

  void _handleKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      if (!kIsWeb && (Platform.isWindows || Platform.isMacOS)) {
        windowManager.close();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}