class DoctorProfile {
  final String id;
  final String name;
  final String username;
  final String role;
  final String? speciality;
  final String? facilityId;

  DoctorProfile({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.speciality,
    this.facilityId,
  });

  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      role: json['role'] as String? ?? 'doctor',
      speciality: json['speciality'] as String?,
      facilityId: json['facility_id'] as String?,
    );
  }
}

/// A doctor/admin login account, as returned by the admin-only
/// GET/POST /api/v1/admin/doctors endpoints. Distinct from [DoctorProfile]
/// (which is just "whoever is currently logged in") because this carries
/// account-management fields like is_active and last_login_at.
class DoctorAccount {
  final String id;
  final String name;
  final String username;
  final String role;
  final String? phone;
  final String? speciality;
  final String? facilityId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  DoctorAccount({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.phone,
    this.speciality,
    this.facilityId,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
  });

  factory DoctorAccount.fromJson(Map<String, dynamic> json) {
    return DoctorAccount(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      role: json['role'] as String? ?? 'doctor',
      phone: json['phone'] as String?,
      speciality: json['speciality'] as String?,
      facilityId: json['facility_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLoginAt: json['last_login_at'] != null ? DateTime.parse(json['last_login_at'] as String) : null,
    );
  }
}

class LoginResult {
  final String accessToken;
  final DoctorProfile doctor;

  LoginResult({required this.accessToken, required this.doctor});

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      accessToken: json['access_token'] as String,
      doctor: DoctorProfile.fromJson(json['doctor'] as Map<String, dynamic>),
    );
  }
}

class DashboardStats {
  final int totalCalls;
  final int activeCalls;
  final int completedCalls;
  final int emergencyCalls;
  final int highCases;
  final int lowCases;
  final int ashaAlerts;
  final int unacknowledgedAlerts;
  final int referralRequests;
  final int appointmentBookings;

  DashboardStats({
    required this.totalCalls,
    required this.activeCalls,
    required this.completedCalls,
    required this.emergencyCalls,
    required this.highCases,
    required this.lowCases,
    required this.ashaAlerts,
    required this.unacknowledgedAlerts,
    required this.referralRequests,
    required this.appointmentBookings,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v == null ? 0 : (v as num).toInt();
    return DashboardStats(
      totalCalls: asInt(json['total_calls']),
      activeCalls: asInt(json['active_calls']),
      completedCalls: asInt(json['completed_calls']),
      emergencyCalls: asInt(json['emergency_calls']),
      highCases: asInt(json['high_cases']),
      lowCases: asInt(json['low_cases']),
      ashaAlerts: asInt(json['asha_alerts']),
      unacknowledgedAlerts: asInt(json['unacknowledged_alerts']),
      referralRequests: asInt(json['referral_requests']),
      appointmentBookings: asInt(json['appointment_bookings']),
    );
  }
}

class AdminEmergencyEvent {
  final String id;
  final String? patientId;
  final String redFlagType;
  final String severity;
  final String status;
  final String? assignedAshaId;
  final DateTime createdAt;

  AdminEmergencyEvent({
    required this.id,
    this.patientId,
    required this.redFlagType,
    required this.severity,
    required this.status,
    this.assignedAshaId,
    required this.createdAt,
  });

  factory AdminEmergencyEvent.fromJson(Map<String, dynamic> json) {
    return AdminEmergencyEvent(
      id: json['id'] as String,
      patientId: json['patient_id'] as String?,
      redFlagType: json['red_flag_type'] as String,
      severity: json['severity'] as String? ?? 'HIGH',
      status: json['status'] as String? ?? 'UNACKNOWLEDGED',
      assignedAshaId: json['assigned_asha_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AdminReferral {
  final String id;
  final String patientId;
  final String? toFacilityId;
  final String status;
  final DateTime createdAt;

  AdminReferral({
    required this.id,
    required this.patientId,
    this.toFacilityId,
    required this.status,
    required this.createdAt,
  });

  factory AdminReferral.fromJson(Map<String, dynamic> json) {
    return AdminReferral(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      toFacilityId: json['to_facility_id'] as String?,
      status: json['status'] as String? ?? 'Created',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AdminAppointment {
  final String id;
  final String patientId;
  final String? speciality;
  final int? queueNumber;
  final String status;
  final DateTime createdAt;

  AdminAppointment({
    required this.id,
    required this.patientId,
    this.speciality,
    this.queueNumber,
    required this.status,
    required this.createdAt,
  });

  factory AdminAppointment.fromJson(Map<String, dynamic> json) {
    return AdminAppointment(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      speciality: json['speciality'] as String?,
      queueNumber: json['queue_number'] as int?,
      status: json['status'] as String? ?? 'booked',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
