import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ChatbotResponse {
  final String reply;
  final String? intent;
  final bool isEmergency;
  final String? triageLevel;
  final List<String> extractedSymptoms;
  final String sessionId;

  ChatbotResponse({
    required this.reply,
    this.intent,
    this.isEmergency = false,
    this.triageLevel,
    this.extractedSymptoms = const [],
    required this.sessionId,
  });

  factory ChatbotResponse.fromJson(Map<String, dynamic> json) {
    final rawSymptoms = json['extracted_symptoms'];
    List<String> symptomsList = [];
    if (rawSymptoms is List) {
      symptomsList = rawSymptoms.map((e) => e.toString()).toList();
    }

    return ChatbotResponse(
      reply: json['reply'] as String? ?? json['response'] as String? ?? '',
      intent: json['intent'] as String?,
      isEmergency: json['is_emergency'] as bool? ?? false,
      triageLevel: json['triage_level'] as String?,
      extractedSymptoms: symptomsList,
      sessionId: json['session_id'] as String? ?? '',
    );
  }
}

class ChatbotService {
  String? authToken;

  Future<ChatbotResponse> sendMessage({
    required String message,
    required String role,
    String? sessionId,
    String? patientId,
    String language = 'en',
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/chatbot/message');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };

    final body = jsonEncode({
      'message': message,
      'role': role,
      'language': language,
      if (sessionId != null && sessionId.isNotEmpty) 'session_id': sessionId,
      if (patientId != null && patientId.isNotEmpty) 'patient_id': patientId,
    });

    try {
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return ChatbotResponse.fromJson(data);
      } else {
        final data = jsonDecode(response.body);
        final detail = data['detail'] ?? 'Service temporarily unavailable.';
        throw Exception(detail.toString());
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection refused')) {
        throw Exception('Cannot connect to SwasthyaSetu server. Please verify backend service.');
      }
      rethrow;
    }
  }

  Future<bool> checkOnlineStatus() async {
    try {
      final url = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/chatbot/faq-topics');
      final res = await http.get(url).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
