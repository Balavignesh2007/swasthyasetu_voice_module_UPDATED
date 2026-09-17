import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class JitsiService {
  /// Base domain for Jitsi Meet (free public WebRTC server).
  static const String jitsiDomain = 'meet.jit.si';

  /// Generates a clean, HIPAA-safe room name without whitespace or special characters.
  static String generateRoomName({
    required String appointmentId,
    String? patientName,
  }) {
    final sanitizedPatient = (patientName ?? 'Patient')
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        .trim();
    final safePatient = sanitizedPatient.isEmpty ? 'Patient' : sanitizedPatient;

    final sanitizedId = appointmentId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final shortId = sanitizedId.length > 8 ? sanitizedId.substring(0, 8) : sanitizedId;

    return 'SwasthyaSetu_TeleConsult_${safePatient}_$shortId';
  }

  /// Generates an ad-hoc room name for instant consultations.
  static String generateInstantRoomName({String? customLabel}) {
    final cleanLabel = (customLabel != null && customLabel.trim().isNotEmpty)
        ? customLabel.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
        : 'Instant';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return 'SwasthyaSetu_TeleConsult_${cleanLabel}_$timestamp';
  }

  /// URL for the doctor to join with pre-configured display name and camera/mic.
  static String getDoctorMeetingUrl({
    required String roomName,
    required String doctorName,
  }) {
    final encodedName = Uri.encodeComponent(doctorName.startsWith('Dr.') ? doctorName : 'Dr. $doctorName');
    return 'https://$jitsiDomain/$roomName#userInfo.displayName="$encodedName"&config.startWithAudioMuted=false&config.startWithVideoMuted=false';
  }

  /// Clean public URL for the patient to join.
  static String getPatientInviteUrl(String roomName) {
    return 'https://$jitsiDomain/$roomName';
  }

  /// WhatsApp direct click-to-chat invite link.
  static String? getWhatsAppInviteUrl({
    required String roomName,
    required String doctorName,
    String? patientPhone,
    String? patientName,
  }) {
    if (patientPhone == null || patientPhone.trim().isEmpty) return null;

    // Clean phone number (digits only, e.g. 919121458655)
    var cleanPhone = patientPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone'; // default India country code
    }

    final greeting = patientName != null && patientName.isNotEmpty ? 'Namaste $patientName ji,' : 'Namaste,';
    final inviteLink = getPatientInviteUrl(roomName);
    final message = '$greeting\n\n'
        '${doctorName.startsWith("Dr.") ? doctorName : "Dr. $doctorName"} is ready for your SwasthyaSetu Teleconsultation.\n\n'
        'Click the link below to join the video call:\n$inviteLink\n\n'
        'SwasthyaSetu Rural Healthcare Portal';

    return 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}';
  }

  /// Launches the Jitsi Meet room in an external browser tab/window.
  static Future<bool> launchMeeting(String url) async {
    final uri = Uri.parse(url);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  /// Copies the invitation link to the clipboard.
  static Future<void> copyInviteLink(String inviteUrl) async {
    await Clipboard.setData(ClipboardData(text: inviteUrl));
  }
}
