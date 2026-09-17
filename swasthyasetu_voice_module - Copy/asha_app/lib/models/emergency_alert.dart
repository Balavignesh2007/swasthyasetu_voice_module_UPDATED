enum AlertStatus {
  unacknowledged,
  acknowledged,
  contacting,
  reached,
  escalated,
  resolved,
  unableToReach,
}

AlertStatus alertStatusFromString(String value) {
  switch (value) {
    case 'UNACKNOWLEDGED':
      return AlertStatus.unacknowledged;
    case 'ACKNOWLEDGED':
      return AlertStatus.acknowledged;
    case 'CONTACTING':
      return AlertStatus.contacting;
    case 'REACHED':
      return AlertStatus.reached;
    case 'ESCALATED':
      return AlertStatus.escalated;
    case 'RESOLVED':
      return AlertStatus.resolved;
    case 'UNABLE_TO_REACH':
      return AlertStatus.unableToReach;
    default:
      return AlertStatus.unacknowledged;
  }
}

String alertStatusLabel(AlertStatus status) {
  switch (status) {
    case AlertStatus.unacknowledged:
      return 'UNACKNOWLEDGED';
    case AlertStatus.acknowledged:
      return 'ACKNOWLEDGED';
    case AlertStatus.contacting:
      return 'CONTACTING';
    case AlertStatus.reached:
      return 'REACHED';
    case AlertStatus.escalated:
      return 'ESCALATED';
    case AlertStatus.resolved:
      return 'RESOLVED';
    case AlertStatus.unableToReach:
      return 'UNABLE TO REACH';
  }
}

class EmergencyAlert {
  final String id;
  final String? patientId;
  final String? callSessionId;
  final String redFlagType;
  final String severity;
  final AlertStatus status;
  final String? assignedAshaId;
  final DateTime createdAt;
  final DateTime? acknowledgedAt;
  final DateTime? resolvedAt;

  EmergencyAlert({
    required this.id,
    required this.patientId,
    this.callSessionId,
    required this.redFlagType,
    required this.severity,
    required this.status,
    required this.assignedAshaId,
    required this.createdAt,
    this.acknowledgedAt,
    this.resolvedAt,
  });

  factory EmergencyAlert.fromJson(Map<String, dynamic> json) {
    return EmergencyAlert(
      id: json['id'] as String,
      patientId: json['patient_id'] as String?,
      callSessionId: json['call_session_id'] as String?,
      redFlagType: json['red_flag_type'] as String,
      severity: json['severity'] as String? ?? 'HIGH',
      status: alertStatusFromString(json['status'] as String? ?? 'UNACKNOWLEDGED'),
      assignedAshaId: json['assigned_asha_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.tryParse(json['acknowledged_at'] as String)
          : null,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'] as String)
          : null,
    );
  }

  bool get isOpen => status != AlertStatus.resolved;
}
