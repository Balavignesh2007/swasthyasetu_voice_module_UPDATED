import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/emergency_alert.dart';
import 'status_badge.dart';

class AlertCard extends StatelessWidget {
  final EmergencyAlert alert;
  final VoidCallback onTap;

  const AlertCard({super.key, required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnacknowledged = alert.status == AlertStatus.unacknowledged;
    final timeLabel = DateFormat('MMM d, h:mm a').format(alert.createdAt.toLocal());

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: isUnacknowledged ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUnacknowledged
            ? const BorderSide(color: Color(0xFFD32F2F), width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      alert.redFlagType,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  StatusBadge(status: alert.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Patient: ${alert.patientId ?? "Unverified caller"}',
                style: const TextStyle(color: Colors.black87),
              ),
              const SizedBox(height: 2),
              Text(
                'Severity: ${alert.severity}  ·  $timeLabel',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
