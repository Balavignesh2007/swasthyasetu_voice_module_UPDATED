import 'package:flutter/material.dart';
import 'chat_message.dart';
import 'chat_input.dart';

class ChatbotWindow extends StatefulWidget {
  final List<ChatbotMessageItem> messages;
  final bool isLoading;
  final bool isOnline;
  final Color themeColor;
  final VoidCallback onClose;
  final VoidCallback onClear;
  final ValueChanged<String> onSend;
  final VoidCallback onCheckOnline;

  const ChatbotWindow({
    super.key,
    required this.messages,
    required this.isLoading,
    required this.isOnline,
    required this.themeColor,
    required this.onClose,
    required this.onClear,
    required this.onSend,
    required this.onCheckOnline,
  });

  @override
  State<ChatbotWindow> createState() => _ChatbotWindowState();
}

class _ChatbotWindowState extends State<ChatbotWindow> {
  final _scrollController = ScrollController();

  final List<String> _quickPrompts = const [
    'What is SwasthyaSetu?',
    'I have a health problem',
    'When should I see a doctor?',
    'How can I book an appointment?',
    'What is ORS?',
  ];

  @override
  void didUpdateWidget(covariant ChatbotWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length || widget.isLoading) {
      _scrollToBottom();
    }
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;

    final windowWidth = isMobile ? double.infinity : 400.0;
    final windowHeight = isMobile ? double.infinity : 560.0;

    return Container(
      width: windowWidth,
      height: windowHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Chatbot Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: widget.themeColor,
                gradient: LinearGradient(
                  colors: [widget.themeColor, widget.themeColor.withValues(alpha: 0.9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/chatbot_avatar.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.smart_toy_rounded,
                          color: Color(0xFF0F766E),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Health Assistant',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: widget.isOnline
                                    ? const Color(0xFF4ADE80)
                                    : const Color(0xFFFBBF24),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              widget.isOnline
                                  ? 'SwasthyaSetu • Online'
                                  : 'SwasthyaSetu • Connecting...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Clear history
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 19, color: Colors.white70),
                    tooltip: 'Reset Conversation',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onClear,
                  ),
                  const SizedBox(width: 8),
                  // Minimize / Close
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white),
                    tooltip: 'Minimize',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),

            // Messages List & Quick Prompts
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                children: [
                  // Welcome Message Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipOval(
                              child: Image.asset(
                                'assets/images/chatbot_avatar.png',
                                width: 22,
                                height: 22,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.health_and_safety_outlined, size: 18, color: widget.themeColor),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'SwasthyaSetu Assistant',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Hello! I'm the SwasthyaSetu Health Assistant. I can help with general health information, symptoms, appointments, and SwasthyaSetu services.",
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'ℹ️ AI guidance only. Not a doctor. Consult a doctor at your PHC for formal diagnosis.',
                            style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Prompts row/wrap
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suggested Questions:',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _quickPrompts.map((prompt) {
                            return InkWell(
                              onTap: widget.isLoading ? null : () => widget.onSend(prompt),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Text(
                                  prompt,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF334155),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

                  // Render conversation messages
                  ...widget.messages.map((m) => ChatMessageWidget(
                    message: m,
                    themeColor: widget.themeColor,
                  )),

                  // Loading typing indicator
                  if (widget.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/chatbot_avatar.png',
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.smart_toy_rounded,
                                  size: 16,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'AI Assistant is thinking...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Chat input field
            ChatInput(
              onSend: widget.onSend,
              isLoading: widget.isLoading,
              themeColor: widget.themeColor,
            ),
          ],
        ),
      ),
    );
  }
}
