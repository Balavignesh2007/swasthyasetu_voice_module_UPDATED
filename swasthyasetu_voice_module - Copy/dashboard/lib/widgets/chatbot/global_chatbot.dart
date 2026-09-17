import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/unified_models.dart';
import '../../services/chatbot_service.dart';
import 'chat_message.dart';
import 'chatbot_button.dart';
import 'chatbot_window.dart';

export 'chat_message.dart';
export 'chat_input.dart';
export 'chatbot_button.dart';
export 'chatbot_window.dart';

class GlobalChatbot extends StatefulWidget {
  final UnifiedUserSession session;
  final Color themeColor;

  const GlobalChatbot({
    super.key,
    required this.session,
    required this.themeColor,
  });

  @override
  State<GlobalChatbot> createState() => _GlobalChatbotState();
}

class _GlobalChatbotState extends State<GlobalChatbot> {
  final _service = ChatbotService();
  bool _isOpen = false;
  bool _isLoading = false;
  bool _isOnline = true;
  late String _sessionId;
  final List<ChatbotMessageItem> _messages = [];

  @override
  void initState() {
    super.initState();
    _sessionId = 'session_${widget.session.id}_${Random().nextInt(999999)}';
    _service.authToken = widget.session.token;
    _checkHealth();
  }

  @override
  void didUpdateWidget(covariant GlobalChatbot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.session.token != oldWidget.session.token) {
      _service.authToken = widget.session.token;
    }
  }

  Future<void> _checkHealth() async {
    final online = await _service.checkOnlineStatus();
    if (mounted) {
      setState(() => _isOnline = online);
    }
  }

  String get _backendRoleString {
    switch (widget.session.role) {
      case UserRole.doctor:
        return 'DOCTOR';
      case UserRole.asha:
        return 'ASHA_WORKER';
      case UserRole.patient:
        return 'PATIENT';
      case UserRole.pharmacy:
        return 'PHARMACY';
      case UserRole.lab:
        return 'LAB';
      case UserRole.phcAdmin:
        return 'PHC_ADMIN';
    }
  }

  void _handleSendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userMsg = ChatbotMessageItem(
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });

    try {
      final response = await _service.sendMessage(
        message: text.trim(),
        role: _backendRoleString,
        sessionId: _sessionId,
        patientId: widget.session.role == UserRole.patient ? widget.session.id : null,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isOnline = true;
        _messages.add(
          ChatbotMessageItem(
            text: response.reply.isNotEmpty
                ? response.reply
                : 'I received your inquiry. Please consult your local health center for personalized care.',
            isUser: false,
            timestamp: DateTime.now(),
            isEmergency: response.isEmergency,
            triageLevel: response.triageLevel,
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add(
          ChatbotMessageItem(
            text: 'Connection Error: $e\nPlease verify the backend service or try again in a moment.',
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
      });
    }
  }

  void _handleClear() {
    setState(() {
      _messages.clear();
      _sessionId = 'session_${widget.session.id}_${Random().nextInt(999999)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile && _isOpen) {
      return Positioned(
        left: 8,
        right: 8,
        bottom: 8,
        top: 8,
        child: ChatbotWindow(
          messages: _messages,
          isLoading: _isLoading,
          isOnline: _isOnline,
          themeColor: widget.themeColor,
          onClose: () => setState(() => _isOpen = false),
          onClear: _handleClear,
          onSend: _handleSendMessage,
          onCheckOnline: _checkHealth,
        ),
      );
    }

    return Positioned(
      bottom: isMobile ? 12 : 24,
      right: isMobile ? 12 : 24,
      child: _isOpen
          ? ChatbotWindow(
              messages: _messages,
              isLoading: _isLoading,
              isOnline: _isOnline,
              themeColor: widget.themeColor,
              onClose: () => setState(() => _isOpen = false),
              onClear: _handleClear,
              onSend: _handleSendMessage,
              onCheckOnline: _checkHealth,
            )
          : ChatbotButton(
              isOpen: false,
              themeColor: widget.themeColor,
              onTap: () {
                setState(() => _isOpen = true);
                _checkHealth();
              },
            ),
    );
  }
}
