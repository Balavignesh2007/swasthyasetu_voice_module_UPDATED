import 'package:flutter/material.dart';

class ChatbotButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isOpen;
  final Color themeColor;

  const ChatbotButton({
    super.key,
    required this.onTap,
    required this.isOpen,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isOpen) {
      return const SizedBox.shrink();
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(30),
      shadowColor: themeColor.withValues(alpha: 0.4),
      color: themeColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 16,
            vertical: isMobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: [themeColor, themeColor.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isMobile ? 24 : 28,
                height: isMobile ? 24 : 28,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/chatbot_avatar.png',
                    width: isMobile ? 24 : 28,
                    height: isMobile ? 24 : 28,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.smart_toy_rounded,
                      color: const Color(0xFF0F766E),
                      size: isMobile ? 16 : 20,
                    ),
                  ),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 8),
                const Text(
                  'Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
