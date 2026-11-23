import 'dart:async';
import 'dart:io' show Platform, File;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../utils/web_audio_blob.dart';
import '../utils/web_tts_stub.dart' if (dart.library.html) '../utils/web_tts_web.dart' as web_tts;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_cursor.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Audio players and recorders
  late AudioPlayer _audioPlayer;
  late AudioRecorder _audioRecorder;
  late FlutterTts _flutterTts;
  
  // Services
  late LuminaApiService _apiService;
  
  // Local states
  String? _recordingPath;
  bool _recordPermissionGranted = false;
  bool _greetingPlayed = false;
  late AnimationController _pulseController;
  StreamSubscription<RecordState>? _recordSub;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioRecorder = AudioRecorder();
    _apiService = LuminaApiService();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Monitor recorder status
    _recordSub = _audioRecorder.onStateChanged().listen((state) {
      if (state == RecordState.record) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    });

    _flutterTts = FlutterTts();
    _configureTts();

    _checkPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybePlayInitialGreeting();
    });
  }

  Future<void> _maybePlayInitialGreeting() async {
    try {
      if (_greetingPlayed) return;
      final appState = context.read<LuminaAppState>();
      if (appState.messages.isEmpty) {
        appState.addGreeting();
      }
      final first = appState.messages.first;
      if (first.isUser) return;

      _greetingPlayed = true;

      // Speak the EXACT greeting text shown in the chat — no backend call needed.
      // This ensures what's spoken always matches what's displayed.
      await _speakText(first.text);
    } catch (e) {
      debugPrint('Initial greeting playback error: $e');
    }
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb) {
      _recordPermissionGranted = await _audioRecorder.hasPermission();
      return;
    }
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      _recordPermissionGranted = true;
    } else {
      final request = await Permission.microphone.request();
      _recordPermissionGranted = request.isGranted;
    }
  }

  @override
  void dispose() {
    _recordSub?.cancel();
    _pulseController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _audioRecorder.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _scrollToBottom() {
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

  String _buildHistory() {
    final appState = context.read<LuminaAppState>();
    final buffer = StringBuffer();
    for (final msg in appState.messages) {
      final text = msg.text.trim();
      if (text.isEmpty || text == '(voice message)' || text.startsWith('Starting fresh') || text.contains('What shall we discover first')) {
        continue;
      }
      final role = msg.isUser ? 'User' : 'Assistant';
      buffer.writeln('$role: $text');
    }
    return buffer.toString().trim();
  }

  // ══════════════════════════════════════════════
  // CORE API CALL PROCESS
  // ══════════════════════════════════════════════
  
  Future<void> _sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    _inputController.clear();
    final appState = context.read<LuminaAppState>();
    
    // 1. Add User message to list
    appState.addMessage(ChatMessage(text: text, isUser: true));
    appState.setTyping(true);
    _scrollToBottom();

    // 2. Send to Flask API
    final response = await _apiService.processInteraction(
      text: text,
      history: _buildHistory(),
      name: appState.userName,
      age: appState.userAge,
      mood: appState.userMood,
      companionName: appState.selectedCompanion.name,
      companionTrait: appState.selectedCompanion.trait,
    );

    appState.setTyping(false);

    // 3. Process reply
    if (response.error != null) {
      appState.addMessage(ChatMessage(
        text: 'Oops! Communication error: ${response.error}',
        isUser: false,
      ));
      await _speakText('Oops! Communication error: ${response.error}');
    } else {
      appState.addMessage(ChatMessage(
        text: response.assistantReply,
        isUser: false,
        audioUrl: response.audioUrl,
      ));
      
      if (response.audioUrl != null) {
        await _playVoice(response.audioUrl!, fallbackText: response.assistantReply);
      } else {
        await _speakText(response.assistantReply);
      }
    }
    _scrollToBottom();
  }

  Future<void> _sendAudioBytes(Uint8List bytes, {String filename = 'recording.webm'}) async {
    final appState = context.read<LuminaAppState>();

    appState.addMessage(ChatMessage(text: '(voice message)', isUser: true));
    appState.setTyping(true);
    _scrollToBottom();

    final response = await _apiService.processInteraction(
      audioBytes: bytes,
      audioFilename: filename,
      history: _buildHistory(),
      name: appState.userName,
      age: appState.userAge,
      mood: appState.userMood,
      companionName: appState.selectedCompanion.name,
      companionTrait: appState.selectedCompanion.trait,
    );

    appState.setTyping(false);

    if (response.error != null) {
      appState.addMessage(ChatMessage(
        text: 'Connection fuzzy! ${response.error}',
        isUser: false,
      ));
      await _speakText('Connection fuzzy! ${response.error}');
    } else {
      final userText = response.cleanText.isNotEmpty 
          ? response.cleanText 
          : (response.rawText.isNotEmpty ? response.rawText : '(voice message)');
      appState.updateLastUserMessage(userText);

      appState.addMessage(ChatMessage(
        text: response.assistantReply,
        isUser: false,
        audioUrl: response.audioUrl,
      ));

      if (response.audioUrl != null) {
        await _playVoice(response.audioUrl!, fallbackText: response.assistantReply);
      } else {
        await _speakText(response.assistantReply);
      }
    }
    _scrollToBottom();
  }

  Future<void> _sendAudioFile(String filePath) async {
    final appState = context.read<LuminaAppState>();
    
    // 1. Add User voice notification to list
    appState.addMessage(ChatMessage(text: '(voice message)', isUser: true));
    appState.setTyping(true);
    _scrollToBottom();

    // 2. Send file to Flask API
    final response = await _apiService.processInteraction(
      audioFilePath: filePath,
      history: _buildHistory(),
      name: appState.userName,
      age: appState.userAge,
      mood: appState.userMood,
      companionName: appState.selectedCompanion.name,
      companionTrait: appState.selectedCompanion.trait,
    );

    appState.setTyping(false);

    // 3. Process reply
    if (response.error != null) {
      appState.addMessage(ChatMessage(
        text: 'Connection fuzzy! ${response.error}',
        isUser: false,
      ));
      await _speakText('Connection fuzzy! ${response.error}');
    } else {
      final userText = response.cleanText.isNotEmpty 
          ? response.cleanText 
          : (response.rawText.isNotEmpty ? response.rawText : '(voice message)');
      appState.updateLastUserMessage(userText);

      appState.addMessage(ChatMessage(
        text: response.assistantReply,
        isUser: false,
        audioUrl: response.audioUrl,
      ));
      
      if (response.audioUrl != null) {
        await _playVoice(response.audioUrl!, fallbackText: response.assistantReply);
      } else {
        await _speakText(response.assistantReply);
      }
    }
    _scrollToBottom();
  }

  Future<void> _playVoice(String url, {String? fallbackText}) async {
    try {
      await _audioPlayer.stop();
      String resolvedUrl = url;
      if (resolvedUrl.startsWith('/')) {
        resolvedUrl = '${_apiService.baseUrl}$resolvedUrl';
      }
      if (!kIsWeb && Platform.isAndroid && resolvedUrl.contains('127.0.0.1:5000')) {
        resolvedUrl = resolvedUrl.replaceAll('127.0.0.1:5000', '10.0.2.2:5000');
      }
      await _audioPlayer.play(UrlSource(resolvedUrl));
    } catch (e) {
      debugPrint("Audio Playback Error: $e");
      if (fallbackText != null && fallbackText.trim().isNotEmpty) {
        await _speakText(fallbackText);
      }
    }
  }

  Future<void> _configureTts() async {
    if (kIsWeb) return;
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.95);
    await _flutterTts.setLanguage('en-US');
  }

  String _languageForCompanion(String companionName) {
    switch (companionName.toLowerCase()) {
      case 'lumi':
        return 'en-GB';
      case 'blaze':
        return 'en-AU';
      default:
        return 'en-US';
    }
  }

  Future<void> _speakText(String text) async {
    if (text.trim().isEmpty) return;
    if (kIsWeb) {
      await web_tts.speak(text);
      return;
    }
    try {
      final companionName = context.read<LuminaAppState>().selectedCompanion.name;
      final lang = _languageForCompanion(companionName);
      await _flutterTts.setLanguage(lang);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('TTS Error: $e');
    }
  }

  // ══════════════════════════════════════════════
  // RECORDING ACTIONS
  // ══════════════════════════════════════════════

  Future<void> _startRecording() async {
    final appState = context.read<LuminaAppState>();
    if (appState.isRecording) return;

    if (!_recordPermissionGranted) {
      await _checkPermissions();
      if (!_recordPermissionGranted) {
        appState.addMessage(ChatMessage(
          text: 'Microphone permission denied. Enable it in your settings.',
          isUser: false,
        ));
        _scrollToBottom();
        return;
      }
    }

    if (kIsWeb) {
      if (!await _audioRecorder.hasPermission()) {
        appState.addMessage(ChatMessage(
          text: 'Microphone access was denied. Allow microphone access in your browser and try again.',
          isUser: false,
        ));
        _scrollToBottom();
        return;
      }

      try {
        await _audioRecorder.start(
          const RecordConfig(),
          path: '',
        );
        appState.setRecording(true);
      } catch (e) {
        debugPrint("Web Recording Start Error: $e");
        appState.addMessage(ChatMessage(
          text: 'Could not start recording. Check your microphone and try again.',
          isUser: false,
        ));
        _scrollToBottom();
      }
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: _recordingPath!,
      );
      appState.setRecording(true);
    } catch (e) {
      debugPrint("Recording Start Error: $e");
    }
  }

  Future<void> _stopRecording() async {
    final appState = context.read<LuminaAppState>();
    if (!appState.isRecording) return;

    try {
      final pathResult = await _audioRecorder.stop();
      appState.setRecording(false);

      if (pathResult == null) return;

      if (kIsWeb) {
        final bytes = await readBlobUrl(pathResult);
        if (bytes != null && bytes.isNotEmpty) {
          await _sendAudioBytes(bytes, filename: 'recording.webm');
        } else {
          appState.addMessage(ChatMessage(
            text: 'Recording failed — no audio captured. Please try again.',
            isUser: false,
          ));
          _scrollToBottom();
        }
      } else if (_recordingPath != null) {
        _sendAudioFile(_recordingPath!);
      }
    } catch (e) {
      debugPrint("Recording Stop Error: $e");
      appState.setRecording(false);
    }
  }

  Future<void> _toggleRecording() async {
    final appState = context.read<LuminaAppState>();
    if (appState.isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  // ══════════════════════════════════════════════
  // FILE UPLOAD ACTIONS
  // ══════════════════════════════════════════════

  Future<void> _pickAndUploadAudio() async {
    final appState = context.read<LuminaAppState>();
    appState.setTyping(true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['wav', 'mp3', 'm4a', 'webm', 'ogg', 'aac', 'flac'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        appState.setTyping(false);
        return;
      }

      final file = result.files.single;
      Uint8List? fileBytes = file.bytes;

      // On native desktop/mobile, read bytes from path if bytes is null
      // Never access file.path on web — it throws an exception
      if (fileBytes == null && !kIsWeb) {
        try {
          final String? filePath = file.path;
          if (filePath != null) {
            final f = File(filePath);
            if (await f.exists()) {
              fileBytes = await f.readAsBytes();
            }
          }
        } catch (e) {
          debugPrint('File byte read error: $e');
        }
      }

      appState.addMessage(ChatMessage(
        text: '(voice message)',
        isUser: true,
      ));
      _scrollToBottom();

      LuminaApiResponse response;
      if (fileBytes != null && fileBytes.isNotEmpty) {
        response = await _apiService.processInteraction(
          audioBytes: fileBytes,
          audioFilename: file.name,
          history: _buildHistory(),
          name: appState.userName,
          age: appState.userAge,
          mood: appState.userMood,
          companionName: appState.selectedCompanion.name,
          companionTrait: appState.selectedCompanion.trait,
        );
      } else {
        appState.addMessage(ChatMessage(
          text: 'Could not read the selected audio file. Please try a different file.',
          isUser: false,
        ));
        _scrollToBottom();
        return;
      }

      if (response.error != null) {
        appState.addMessage(ChatMessage(
          text: 'Connection fuzzy! ${response.error}',
          isUser: false,
        ));
        await _speakText('Connection fuzzy! ${response.error}');
      } else {
        final userText = response.cleanText.isNotEmpty 
            ? response.cleanText 
            : (response.rawText.isNotEmpty ? response.rawText : '(Uploaded: ${file.name})');
        appState.updateLastUserMessage(userText);

        appState.addMessage(ChatMessage(
          text: response.assistantReply,
          isUser: false,
          audioUrl: response.audioUrl,
        ));
        
        if (response.audioUrl != null) {
          await _playVoice(response.audioUrl!, fallbackText: response.assistantReply);
        } else {
          await _speakText(response.assistantReply);
        }
      }
      _scrollToBottom();
    } catch (e) {
      debugPrint('File Picker Error: $e');
      appState.addMessage(ChatMessage(
        text: 'Audio upload failed: $e',
        isUser: false,
      ));
      _scrollToBottom();
    } finally {
      appState.setTyping(false);
    }
  }

  // ══════════════════════════════════════════════
  // PRESET PROMPTS
  // ══════════════════════════════════════════════

  void _sendPreset(String presetText) {
    _sendTextMessage(presetText);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LuminaAppState>();
    final isDark = state.themeMode == LuminaThemeMode.dark;

    final Color textColor = isDark ? LuminaColors.darkText : LuminaColors.lightText;
    final Color mutedColor = isDark ? LuminaColors.darkMuted : LuminaColors.lightMuted;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        // Spacebar hold to record for Desktop
        // Detect key down/up
        if (event.logicalKey.keyLabel == ' ') {
          if (event.runtimeType.toString() == 'KeyDownEvent') {
            if (!state.isRecording && _inputController.text.isEmpty) {
              _startRecording();
              return KeyEventResult.handled;
            }
          } else if (event.runtimeType.toString() == 'KeyUpEvent') {
            if (state.isRecording) {
              _stopRecording();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 640.0;
          
          final Widget sidebarWidget = _Sidebar(
            isDark: isDark,
            isMobile: isMobile,
            onPresetSelected: _sendPreset,
            onCloseDrawer: () {
              if (isMobile) Navigator.pop(context);
            },
          );

          return Scaffold(
            backgroundColor: Colors.transparent,
            drawer: isMobile ? Drawer(child: sidebarWidget) : null,
            body: Center(
              child: Container(
                width: isMobile ? double.infinity : math.min(1000.0, constraints.maxWidth * 0.96),
                height: isMobile ? double.infinity : constraints.maxHeight * 0.88,
                margin: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 20.0),
                child: GlassContainer(
                  isDark: isDark,
                  borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(30.0),
                  child: Row(
                    children: [
                      // Sidebar on desktop
                      if (!isMobile) ...[
                        SizedBox(
                          width: 210.0,
                          child: sidebarWidget,
                        ),
                        Container(
                          width: 1.0,
                          color: isDark ? LuminaColors.darkSurfaceB : LuminaColors.lightSurfaceB,
                        ),
                      ],
                      
                      // Main Chat Section
                      Expanded(
                        child: _buildChatMainArea(context, isDark, textColor, mutedColor, isMobile),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════
  // CHAT MAIN VIEWPORT
  // ══════════════════════════════════════════════

  Widget _buildChatMainArea(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color mutedColor,
    bool isMobile,
  ) {
    final state = context.watch<LuminaAppState>();

    return Column(
      children: [
        // 1. Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 17.0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? LuminaColors.darkSurfaceB : LuminaColors.lightSurfaceB,
                width: 1.0,
              ),
            ),
          ),
          child: Row(
            children: [
              // Mobile drawer trigger
              if (isMobile) ...[
                IconButton(
                  icon: Icon(Icons.menu_rounded, color: textColor),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                const SizedBox(width: 8.0),
              ],
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chatting with ${state.selectedCompanion.name}',
                      style: isDark
                          ? LuminaTypography.mono(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w400,
                              color: textColor,
                              letterSpacing: 0.06 * 14.0,
                            )
                          : LuminaTypography.heroFont(
                              isDark,
                              fontSize: 16.0,
                              fontWeight: FontWeight.w400,
                              color: textColor,
                            ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      'Your ${state.selectedCompanion.trait.toLowerCase()} companion is here',
                      style: LuminaTypography.sans(fontSize: 11.0, color: mutedColor),
                    ),
                  ],
                ),
              ),
              
              // World switcher button
              InteractiveCursorRegion(
                child: TextButton(
                  onPressed: () => state.toggleTheme(),
                  style: TextButton.styleFrom(
                    backgroundColor: isDark ? LuminaColors.darkSurfaceB : LuminaColors.lightSurfaceB,
                    padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 10.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50.0),
                      side: BorderSide(
                        color: isDark ? LuminaColors.darkSurfaceB : LuminaColors.lightSurfaceB,
                      ),
                    ),
                  ),
                  child: Text(
                    'Switch world',
                    style: LuminaTypography.sans(
                      fontSize: 11.0,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 2. Chat history messages
        Expanded(
          child: _buildMessagesList(state, isDark, textColor, mutedColor),
        ),
        
        // 3. Input area
        _buildInputBar(state, isDark, textColor, mutedColor),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // MESSAGES BUBBLES LIST
  // ══════════════════════════════════════════════

  Widget _buildMessagesList(
    LuminaAppState state,
    bool isDark,
    Color textColor,
    Color mutedColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 22.0),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.messages.length + (state.isTyping ? 1 : 0),
        itemBuilder: (context, index) {
          // If typing indicator
          if (index == state.messages.length) {
            return _buildTypingIndicator(state, isDark);
          }

          final msg = state.messages[index];
          return _buildMessageRow(msg, state, isDark, textColor);
        },
      ),
    );
  }

  Widget _buildMessageRow(
    ChatMessage msg,
    LuminaAppState state,
    bool isDark,
    Color textColor,
  ) {
    final bool isUser = msg.isUser;
    
    // Bubble gradients
    final Gradient bubbleGrad = isUser
        ? (isDark ? LuminaColors.bubbleUserDark : LuminaColors.bubbleUserLight)
        : (isDark ? LuminaColors.bubbleAIDark : LuminaColors.bubbleAILight);

    final Color bubbleTextColor = isUser
        ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF064E3B))
        : (isDark ? const Color(0xFFDDD6FE) : Colors.white);

    // Avatar configuration
    final Widget avatarIcon = isUser
        ? Center(
            child: Text(
              (state.userName.isNotEmpty ? state.userName[0] : '?').toUpperCase(),
              style: LuminaTypography.sans(
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF064E3B),
              ),
            ),
          )
        : CustomPaint(
            size: const Size(13.0, 13.0),
            painter: _StarPainter(),
          );

    final Widget avatarWidget = Container(
      width: 28.0,
      height: 28.0,
      margin: const EdgeInsets.only(top: 3.0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUser
            ? const LinearGradient(colors: [Color(0xFF6EE7B7), Color(0xFF7DD3FC)])
            : RadialGradient(colors: state.selectedCompanion.bgColors),
      ),
      child: avatarIcon,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 13.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) avatarWidget,
          const SizedBox(width: 8.0),
          
          // Bubble Card
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                gradient: bubbleGrad,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18.0),
                  topRight: const Radius.circular(18.0),
                  bottomLeft: isUser ? const Radius.circular(18.0) : const Radius.circular(4.0),
                  bottomRight: isUser ? const Radius.circular(4.0) : const Radius.circular(18.0),
                ),
                border: isDark
                    ? Border.all(
                        color: isUser
                            ? const Color(0xFF34D399).withValues(alpha: 0.18)
                            : const Color(0xFF6366F1).withValues(alpha: 0.18),
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? const Color(0xFF6EE7B7).withValues(alpha: 0.20)
                        : const Color(0xFFE879F9).withValues(alpha: 0.18),
                    blurRadius: 16.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: LuminaTypography.sans(
                      fontSize: 14.0,
                      fontWeight: FontWeight.w400,
                      color: bubbleTextColor,
                      height: 1.65,
                    ),
                  ),
                  if (msg.audioUrl != null) ...[
                    const SizedBox(height: 10.0),
                    InteractiveCursorRegion(
                      child: TextButton.icon(
                        onPressed: () => _playVoice(msg.audioUrl!),
                        icon: const Icon(Icons.volume_up_rounded, size: 14.0),
                        label: const Text('Replay Voice'),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.06),
                          foregroundColor: bubbleTextColor,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                          textStyle: LuminaTypography.sans(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 8.0),
          if (isUser) avatarWidget,
        ],
      ),
    );
  }

  // Typing/Thinking indicator view
  Widget _buildTypingIndicator(LuminaAppState state, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 13.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 28.0,
            height: 28.0,
            margin: const EdgeInsets.only(top: 3.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: state.selectedCompanion.bgColors),
            ),
            child: CustomPaint(
              size: const Size(13.0, 13.0),
              painter: _StarPainter(),
            ),
          ),
          const SizedBox(width: 8.0),
          
          // Bubbling Dots Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              gradient: isDark ? LuminaColors.bubbleAIDark : LuminaColors.bubbleAILight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18.0),
                topRight: Radius.circular(18.0),
                bottomLeft: Radius.circular(4.0),
                bottomRight: Radius.circular(18.0),
              ),
              border: isDark
                  ? Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.18))
                  : null,
            ),
            child: const _BouncingDots(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // BOTTOM INPUT AREA
  // ══════════════════════════════════════════════

  Widget _buildInputBar(
    LuminaAppState state,
    bool isDark,
    Color textColor,
    Color mutedColor,
  ) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(50.0),
      borderSide: BorderSide(
        color: isDark ? LuminaColors.darkInBorder : LuminaColors.lightInBorder,
        width: 1.0,
      ),
    );
    final focusBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(50.0),
      borderSide: BorderSide(
        color: isDark ? LuminaColors.darkA1 : LuminaColors.lightA1,
        width: 1.5,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? LuminaColors.darkSurfaceB : LuminaColors.lightSurfaceB,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Text message input row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  maxLength: 200,
                  style: LuminaTypography.sans(fontSize: 14.0, color: textColor),
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendTextMessage,
                  decoration: InputDecoration(
                    hintText: 'Ask anything…',
                    hintStyle: LuminaTypography.sans(
                      fontSize: 14.0,
                      color: mutedColor.withValues(alpha: 0.60),
                    ),
                    counterText: "",
                    filled: true,
                    fillColor: isDark ? LuminaColors.darkInBg : LuminaColors.lightInBg,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 17.0, vertical: 12.0),
                    border: border,
                    enabledBorder: border,
                    focusedBorder: focusBorder,
                  ),
                ),
              ),
              const SizedBox(width: 9.0),
              
              // Send Button
              InteractiveCursorRegion(
                child: Container(
                  width: 44.0,
                  height: 44.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isDark
                        ? LuminaColors.btnGradientDark
                        : LuminaColors.btnGradientLight,
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? LuminaColors.darkBtnSh : LuminaColors.lightBtnSh,
                        blurRadius: 16.0,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _sendTextMessage(_inputController.text),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12.0),
          
          // 2. Audio voice actions row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mic Button
              InteractiveCursorRegion(
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.0, end: 1.14).animate(
                    CurvedAnimation(
                      parent: _pulseController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Container(
                    width: 56.0,
                    height: 56.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: state.isRecording
                          ? const LinearGradient(colors: [Color(0xFFEF4444), Color(0xFFB91C1C)])
                          : (isDark ? LuminaColors.btnGradientDark : LuminaColors.btnGradientLight),
                      boxShadow: [
                        BoxShadow(
                          color: state.isRecording 
                              ? Colors.red.withValues(alpha: 0.5) 
                              : (isDark ? LuminaColors.darkBtnSh : LuminaColors.lightBtnSh),
                          blurRadius: 24.0,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _toggleRecording,
                          child: Icon(
                            state.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 20.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12.0),
              
              // Upload audio file button
              InteractiveCursorRegion(
                child: Container(
                  width: 56.0,
                  height: 56.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        isDark ? LuminaColors.darkA2 : LuminaColors.lightA2,
                        isDark ? LuminaColors.darkA3 : LuminaColors.lightA3,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? LuminaColors.darkBtnSh : LuminaColors.lightBtnSh,
                        blurRadius: 24.0,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickAndUploadAudio,
                        child: const Icon(
                          Icons.file_upload_outlined,
                          color: Colors.white,
                          size: 18.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12.0),
              
              // Keyboard label instruction
              Text(
                state.isRecording 
                    ? "RECORDING..."
                    : (kIsWeb ? "CLICK MIC OR FILE" : "HOLD SPACE OR UPLOAD"),
                style: LuminaTypography.sans(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w500,
                  color: state.isRecording ? Colors.redAccent : mutedColor,
                  letterSpacing: 0.10 * 10.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// SIDEBAR / DRAWER IMPLEMENTATION
// ══════════════════════════════════════════════

class _Sidebar extends StatelessWidget {
  final bool isDark;
  final bool isMobile;
  final Function(String) onPresetSelected;
  final VoidCallback onCloseDrawer;

  const _Sidebar({
    required this.isDark,
    required this.isMobile,
    required this.onPresetSelected,
    required this.onCloseDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LuminaAppState>();
    final c = state.selectedCompanion;
    
    final Color textColor = isDark ? LuminaColors.darkText : LuminaColors.lightText;
    final Color mutedColor = isDark ? LuminaColors.darkMuted : LuminaColors.lightMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 26.0),
      color: isMobile 
          ? (isDark ? const Color(0xFF06041C) : const Color(0xFFFFF0F9))
          : Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: Companion Info
          Center(
            child: Column(
              children: [
                // Glowing side-orb
                Container(
                  width: 64.0,
                  height: 64.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: c.bgColors),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? LuminaColors.darkBtnSh : LuminaColors.lightBtnSh,
                        blurRadius: 16.0,
                        spreadRadius: 2.0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(22.0, 22.0),
                      painter: _AvatarPainter(type: c.avatarType),
                    ),
                  ),
                ),
                const SizedBox(height: 11.0),
                
                // Name
                Text(
                  c.name == 'Robot' ? 'AI assistant' : c.name,
                  style: isDark
                      ? LuminaTypography.mono(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w400,
                          color: textColor,
                          letterSpacing: 0.06 * 12.0,
                        )
                      : LuminaTypography.heroFont(
                          isDark,
                          fontSize: 15.0,
                          fontWeight: FontWeight.w400,
                          color: textColor,
                        ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4.0),
                
                // Online Dot indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _DotIndicator(),
                    const SizedBox(width: 5.0),
                    Text(
                      'ONLINE',
                      style: LuminaTypography.sans(
                        fontSize: 9.0,
                        fontWeight: FontWeight.w500,
                        color: LuminaColors.green,
                        letterSpacing: 0.1 * 9.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24.0),
          
          // Section: Explore
          _sidebarLabel('EXPLORE', mutedColor),
          _SidebarItem(
            label: 'Fun facts',
            icon: Icons.info_outline_rounded,
            isDark: isDark,
            onTap: () {
              onCloseDrawer();
              onPresetSelected('Tell me a fascinating fact');
            },
          ),
          _SidebarItem(
            label: 'Stories',
            icon: Icons.notes_rounded,
            isDark: isDark,
            onTap: () {
              onCloseDrawer();
              onPresetSelected('Tell me a short story');
            },
          ),
          _SidebarItem(
            label: 'Games',
            icon: Icons.help_outline_rounded,
            isDark: isDark,
            onTap: () {
              onCloseDrawer();
              onPresetSelected("Let's play a guessing game");
            },
          ),
          _SidebarItem(
            label: 'Learn',
            icon: Icons.school_outlined,
            isDark: isDark,
            onTap: () {
              onCloseDrawer();
              onPresetSelected('Teach me something amazing');
            },
          ),
          
          const SizedBox(height: 16.0),
          
          // Section: Actions
          _sidebarLabel('ACTIONS', mutedColor),
          _SidebarItem(
            label: 'Change buddy',
            icon: Icons.people_outline_rounded,
            isDark: isDark,
            onTap: () {
              onCloseDrawer();
              state.setScreen('companion_select');
            },
          ),
          _SidebarItem(
            label: 'New chat',
            icon: Icons.delete_outline_rounded,
            isDark: isDark,
            onTap: () {
              onCloseDrawer();
              state.clearChat();
            },
          ),
          
          const Spacer(),
          
          // Bottom Mood chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.0),
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.20),
              border: Border.all(
                color: isDark ? LuminaColors.darkSurfaceB : LuminaColors.lightSurfaceB,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'YOUR MOOD',
                  style: LuminaTypography.sans(
                    fontSize: 9.0,
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                    letterSpacing: 0.14 * 9.0,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  state.userMood.toUpperCase(),
                  style: LuminaTypography.sans(
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 3.0, bottom: 7.0),
      child: Text(
        text,
        style: LuminaTypography.sans(
          fontSize: 9.0,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.18 * 9.0,
        ),
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    
    final Color textColor = isDark ? LuminaColors.darkText : LuminaColors.lightText;
    final Color hoverColor = isDark 
        ? const Color(0xFF818CF8).withValues(alpha: 0.07) 
        : const Color(0xFFE879F9).withValues(alpha: 0.07);
    final Color hoverBorder = isDark 
        ? const Color(0xFF818CF8).withValues(alpha: 0.18) 
        : const Color(0xFFE879F9).withValues(alpha: 0.18);

    return InteractiveCursorRegion(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(11.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11.0),
              color: _isHovered ? hoverColor : Colors.transparent,
              border: Border.all(
                color: _isHovered ? hoverBorder : Colors.transparent,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 13.0,
                  color: textColor.withValues(alpha: 0.50),
                ),
                const SizedBox(width: 8.0),
                Text(
                  widget.label,
                  style: LuminaTypography.sans(
                    fontSize: 12.0,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
// HELPER DRAWERS/WIDGETS
// ══════════════════════════════════════════════

class _DotIndicator extends StatefulWidget {
  const _DotIndicator();

  @override
  State<_DotIndicator> createState() => _DotIndicatorState();
}

class _DotIndicatorState extends State<_DotIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1.0, end: 0.28).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 0.55).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
        ),
        child: Container(
          width: 5.0,
          height: 5.0,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: LuminaColors.green,
          ),
        ),
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 700),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: -5.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // Staggered bounce loop
    _startBouncing();
  }

  Future<void> _startBouncing() async {
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      _controllers[i].repeat(reverse: true);
      await Future.delayed(const Duration(milliseconds: 180));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: Container(
                width: 6.0,
                height: 6.0,
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final path = Path();
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double outerRadius = size.width / 2;
    final double innerRadius = outerRadius * 0.42;

    for (int k = 0; k < 5; k++) {
      final double a = (k / 5) * math.pi * 2 - math.pi / 2;
      final double a2 = a + math.pi / 5;
      path.lineTo(cx + math.cos(a) * outerRadius, cy + math.sin(a) * outerRadius);
      path.lineTo(cx + math.cos(a2) * innerRadius, cy + math.sin(a2) * innerRadius);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Reuse Avatar painters from companion select screen
class _AvatarPainter extends CustomPainter {
  final String type;

  _AvatarPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    if (type == 'robot') {
      final robotRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(3.0, 11.0, 18.0, 10.0),
        const Radius.circular(2.0),
      );
      canvas.drawRRect(robotRect, paint);
      canvas.drawCircle(const Offset(12.0, 5.0), 2.0, paint);
      canvas.drawLine(const Offset(12.0, 7.0), const Offset(12.0, 11.0), paint);
      canvas.drawCircle(const Offset(8.0, 16.0), 1.0, fillPaint);
      canvas.drawCircle(const Offset(16.0, 16.0), 1.0, fillPaint);
    } else if (type == 'cat') {
      final path = Path()
        ..moveTo(12.0, 21.0)
        ..quadraticBezierTo(6.0, 16.5, 6.0, 12.0)
        ..arcToPoint(
          const Offset(18.0, 12.0),
          radius: const Radius.circular(6.0),
          largeArc: true,
        )
        ..quadraticBezierTo(18.0, 16.5, 12.0, 21.0)
        ..close();
      canvas.drawPath(path, paint);
      canvas.drawCircle(const Offset(9.0, 10.0), 1.0, fillPaint);
      canvas.drawCircle(const Offset(15.0, 10.0), 1.0, fillPaint);
      canvas.drawLine(const Offset(6.0, 8.0), const Offset(3.0, 5.0), paint);
      canvas.drawLine(const Offset(18.0, 8.0), const Offset(21.0, 5.0), paint);
    } else {
      final path = Path()
        ..moveTo(10.0, 5.17)
        ..lineTo(10.0, 5.5)
        ..quadraticBezierTo(10.0, 7.5, 12.0, 7.5)
        ..quadraticBezierTo(14.0, 7.5, 14.0, 5.5)
        ..lineTo(14.0, 5.17);
      canvas.drawPath(path, paint);
      final dogHead = Rect.fromCircle(center: const Offset(12.0, 12.0), radius: 8.0);
      canvas.drawOval(dogHead, paint);
      canvas.drawCircle(const Offset(9.0, 12.0), 1.0, fillPaint);
      canvas.drawCircle(const Offset(15.0, 12.0), 1.0, fillPaint);
      canvas.drawCircle(const Offset(12.0, 14.5), 1.0, fillPaint);
      canvas.drawLine(const Offset(7.0, 11.0), const Offset(4.0, 8.0), paint);
      canvas.drawLine(const Offset(17.0, 11.0), const Offset(20.0, 8.0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) {
    return oldDelegate.type != type;
  }
}
