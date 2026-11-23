import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class LuminaApiResponse {
  final String rawText;
  final String cleanText;
  final String assistantReply;
  final String? audioUrl;
  final String? error;

  LuminaApiResponse({
    required this.rawText,
    required this.cleanText,
    required this.assistantReply,
    this.audioUrl,
    this.error,
  });

  factory LuminaApiResponse.fromJson(Map<String, dynamic> json) {
    return LuminaApiResponse(
      rawText: json['raw_text'] ?? '',
      cleanText: json['clean_text'] ?? '',
      assistantReply: json['assistant_reply'] ?? '',
      audioUrl: json['audio_url'],
      error: json['error'],
    );
  }

  factory LuminaApiResponse.error(String msg) {
    return LuminaApiResponse(
      rawText: '',
      cleanText: '',
      assistantReply: '',
      error: msg,
    );
  }
}

class LuminaApiService {
  // Determine default Flask API base URL based on platform
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    
    try {
      if (Platform.isAndroid) {
        // Android emulator loops back to host localhost through 10.0.2.2
        return 'http://10.0.2.2:5000';
      }
    } catch (_) {
      // Fallback if Platform check fails (e.g. some web environments)
    }
    
    return 'http://127.0.0.1:5000';
  }

  final String baseUrl;

  LuminaApiService({String? customBaseUrl}) 
      : baseUrl = customBaseUrl ?? defaultBaseUrl;

  /// Sends a text message or audio file to the `/api/process` endpoint.
  Future<LuminaApiResponse> processInteraction({
    String? text,
    String? audioFilePath,
    Uint8List? audioBytes,
    String audioFilename = 'recording.webm',
    String? history,
    required String name,
    required String age,
    required String mood,
    required String companionName,
    required String companionTrait,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/api/process');
      final request = http.MultipartRequest('POST', uri);

      // Add text input if present
      if (text != null && text.trim().isNotEmpty) {
        request.fields['text'] = text;
      }

      String getMimeSubType(String nameOrExt) {
        final ext = nameOrExt.contains('.') ? nameOrExt.split('.').last.toLowerCase() : nameOrExt.toLowerCase();
        switch (ext) {
          case 'mp3':
            return 'mpeg';
          case 'm4a':
            return 'mp4';
          case 'wav':
            return 'wav';
          case 'ogg':
            return 'ogg';
          default:
            return ext.isEmpty ? 'wav' : ext;
        }
      }

      // Add audio file if present
      if (audioBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'audio',
            audioBytes,
            filename: audioFilename,
            contentType: MediaType('audio', getMimeSubType(audioFilename)),
          ),
        );
      } else if (audioFilePath != null) {
        final filename = audioFilePath.split(RegExp(r'[/\\]')).last;
        final audioFile = await http.MultipartFile.fromPath(
          'audio',
          audioFilePath,
          filename: filename,
          contentType: MediaType('audio', getMimeSubType(filename)),
        );
        request.files.add(audioFile);
      }

      // Add personalization parameters
      request.fields['name'] = name;
      request.fields['age'] = age;
      request.fields['mood'] = mood;
      request.fields['companion_name'] = companionName;
      request.fields['companion_trait'] = companionTrait;
      if (history != null && history.trim().isNotEmpty) {
        request.fields['history'] = history;
      }

      // Send request
      // NOTE: The AI pipeline (Whisper + Phi-3 + TTS) can take several minutes.
      // Timeout is set to 5 minutes to allow the backend to finish processing.
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 300),
        onTimeout: () => throw http.ClientException('Connection timeout! Please verify your local Flask server is running.'),
      );
      
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          return LuminaApiResponse.fromJson(decoded);
        } else {
          return LuminaApiResponse.error('Invalid response format received from stars.');
        }
      } else {
        try {
          final decoded = json.decode(response.body);
          final errorMsg = decoded['error'] ?? 'Server error (${response.statusCode})';
          return LuminaApiResponse.error(errorMsg);
        } catch (_) {
          return LuminaApiResponse.error('Server returned error status code: ${response.statusCode}');
        }
      }
    } catch (e) {
      return LuminaApiResponse.error('Connection fuzzy! Check if Flask backend is running. Details: $e');
    }
  }
}
