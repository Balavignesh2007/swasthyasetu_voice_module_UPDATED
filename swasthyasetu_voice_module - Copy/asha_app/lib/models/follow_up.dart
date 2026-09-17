class PatientFollowUp {
  final String id;
  final String patientId;
  final String? patientName;
  final String ashaId;
  final String? facilityId;
  final String? doctorId;
  final String title;
  final DateTime dueDate;
  final String status; // pending, completed, missed, overdue
  final String priority; // NORMAL, HIGH, URGENT
  final String? notes;
  final bool escalatedToDoctor;
  final DateTime? completedAt;
  final DateTime createdAt;

  PatientFollowUp({
    required this.id,
    required this.patientId,
    this.patientName,
    required this.ashaId,
    this.facilityId,
    this.doctorId,
    required this.title,
    required this.dueDate,
    required this.status,
    required this.priority,
    this.notes,
    required this.escalatedToDoctor,
    this.completedAt,
    required this.createdAt,
  });

  factory PatientFollowUp.fromJson(Map<String, dynamic> json) {
    return PatientFollowUp(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      patientName: json['patient_name'] as String?,
      ashaId: json['asha_id'] as String? ?? '',
      facilityId: json['facility_id'] as String?,
      doctorId: json['doctor_id'] as String?,
      title: json['title'] as String? ?? 'Follow-up visit',
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? 'pending',
      priority: json['priority'] as String? ?? 'NORMAL',
      notes: json['notes'] as String?,
      escalatedToDoctor: json['escalated_to_doctor'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_id': patientId,
        'asha_id': ashaId,
        'facility_id': facilityId,
        'doctor_id': doctorId,
        'title': title,
        'due_date': dueDate.toIso8601String(),
        'status': status,
        'priority': priority,
        'notes': notes,
        'escalated_to_doctor': escalatedToDoctor,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
