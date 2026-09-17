import 'package:flutter/material.dart';
import '../models/emergency_alert.dart';

Color statusColor(AlertStatus status) {
  switch (status) {
    case AlertStatus.unacknowledged:
      return const Color(0xFFD32F2F); // red — needs immediate action
    case AlertStatus.acknowledged:
      return const Color(0xFFF57C00); // orange
    case AlertStatus.contacting:
      return const Color(0xFFFBC02D); // amber
    case AlertStatus.reached:
      return const Color(0xFF388E3C); // green
    case AlertStatus.escalated:
      return const Color(0xFF7B1FA2); // purple
    case AlertStatus.unableToReach:
      return const Color(0xFF616161); // grey
    case AlertStatus.resolved:
      return const Color(0xFF1976D2); // blue
  }
}

class StatusBadge extends StatelessWidget {
  final AlertStatus status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        alertStatusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
