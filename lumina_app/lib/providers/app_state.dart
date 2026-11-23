import 'package:flutter/material.dart';
import '../core/theme.dart';

class Companion {
  final String name;
  final String trait;
  final List<Color> bgColors;
  final String avatarType; // 'robot', 'cat', 'dog'

  const Companion({
    required this.name,
    required this.trait,
    required this.bgColors,
    required this.avatarType,
  });
}

class ChatMessage {
  final String text;
  final bool isUser;
  final String? audioUrl;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.audioUrl,
  });
}

class LuminaAppState extends ChangeNotifier {
  // Theme Mode
  LuminaThemeMode _themeMode = LuminaThemeMode.light;
  LuminaThemeMode get themeMode => _themeMode;

  // Active Screen
  String _currentScreen = 'loader';
  String get currentScreen => _currentScreen;

  // User Profile
  String _userName = '';
  String get userName => _userName;

  String _userAge = '';
  String get userAge => _userAge;

  String _userMood = 'curious';
  String get userMood => _userMood;

  // Selected Companion
  Companion _selectedCompanion = const Companion(
    name: 'Astra',
    trait: 'Stargazer',
    bgColors: [Color(0xFF818CF8), Color(0xFF312E81)],
    avatarType: 'robot',
  );
  Companion get selectedCompanion => _selectedCompanion;

  // Chat message history
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  // Voice recording & typing states
  bool _isRecording = false;
  bool get isRecording => _isRecording;

  bool _isTyping = false;
  bool get isTyping => _isTyping;

  // Theme Toggle
  void toggleTheme() {
    _themeMode = _themeMode == LuminaThemeMode.light
        ? LuminaThemeMode.dark
        : LuminaThemeMode.light;
    notifyListeners();
  }

  void setTheme(LuminaThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // Navigation
  void setScreen(String screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  // Onboarding submission
  void submitOnboarding({required String name, required String age, required String mood}) {
    _userName = name;
    _userAge = age;
    _userMood = mood.toLowerCase();
    notifyListeners();
  }

  // Companion selection
  void selectCompanion(Companion companion) {
    _selectedCompanion = companion;
    _messages.clear();
    _isTyping = false;
    _isRecording = false;
    notifyListeners();
    
    // Add assistant greeting response
    addGreeting();
  }

  // Generate greeting text
  String getGreetingText() {
    final String name = _userName.isNotEmpty ? _userName : 'friend';
    final lines = {
      'joyful': 'That joy is contagious — I feel it too.',
      'calm': 'A calm explorer is a thoughtful one.',
      'curious': 'Curiosity is my favourite thing in the universe.',
      'adventurous': "Let's go somewhere wonderful together.",
      'tired': "Take it easy. I'll keep things gentle.",
      'silly': "I've been waiting for someone to be silly with.",
    };
    final m = lines[_userMood] ?? "I've been waiting for exactly you.";
    return "Hi $name. I'm ${_selectedCompanion.name}, your ${_selectedCompanion.trait.toLowerCase()}. $m What shall we discover first?";
  }

  void addGreeting() {
    _messages.add(ChatMessage(
      text: getGreetingText(),
      isUser: false,
    ));
    notifyListeners();
  }

  // Clear Chat History
  void clearChat() {
    _messages.clear();
    notifyListeners();
    
    // Add clean start text
    final String name = _userName.isNotEmpty ? _userName : 'friend';
    _messages.add(ChatMessage(
      text: "Starting fresh. What shall we explore, $name?",
      isUser: false,
    ));
    notifyListeners();
  }

  // Message modifications
  void addMessage(ChatMessage msg) {
    _messages.add(msg);
    notifyListeners();
  }

  void updateLastUserMessage(String newText) {
    for (int i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].isUser && _messages[i].text == '(voice message)') {
        _messages[i] = ChatMessage(text: newText, isUser: true);
        notifyListeners();
        break;
      }
    }
  }

  // Recording & Thinking states
  void setRecording(bool val) {
    _isRecording = val;
    notifyListeners();
  }

  void setTyping(bool val) {
    _isTyping = val;
    notifyListeners();
  }
}
