import 'package:flutter/material.dart';

class ChatbotMessageItem {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isEmergency;
  final String? triageLevel;
  final bool isError;

  ChatbotMessageItem({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isEmergency = false,
    this.triageLevel,
    this.isError = false,
  });
}

class ChatMessageWidget extends StatelessWidget {
  final ChatbotMessageItem message;
  final Color themeColor;

  const ChatMessageWidget({
    super.key,
    required this.message,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    height: 1.35,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 13,
              backgroundColor: themeColor.withValues(alpha: 0.15),
              child: Icon(Icons.person, size: 16, color: themeColor),
            ),
          ],
        ),
      );
    }

    // Bot / Assistant response
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: message.isEmergency
                    ? Colors.red.shade200
                    : const Color(0xFFBFDBFE),
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/chatbot_avatar.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  message.isEmergency
                      ? Icons.warning_rounded
                      : Icons.smart_toy_rounded,
                  size: 16,
                  color: message.isEmergency ? Colors.red.shade700 : const Color(0xFF2563EB),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Visually prominent Emergency Banner if isEmergency is true
                if (message.isEmergency)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('⚠️', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text(
                              'MEDICAL EMERGENCY DETECTED',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '⚠️ This may be a medical emergency. Please seek immediate medical help. In India, call 108 or go to the nearest emergency department. Do not wait for the chatbot.',
                          style: TextStyle(
                            color: Colors.red.shade800,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Error indicator card
                if (message.isError)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            message.text,
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontSize: 12.5,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Standard Assistant Reply Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: SelectableText(
                      message.text,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
