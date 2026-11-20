import 'package:uuid/uuid.dart';

/// Immutable event log recording granular consent granted or withdrawn by a prospect.
class ProspectConsentEventModel {
  final String id;
  final String ownerId; // Immutable agent UID
  final String prospectId;
  final String consentType; // 'Direct Inquiry Response', 'Marketing & Promotion', 'Property Recommendations', 'Third-Party Sharing'
  final String purpose; // Specific purpose associated with this consent event
  final List<String> communicationChannels; // e.g. ['WhatsApp'], ['Email'], ['Phone'], ['Direct Inquiry Channel']
  final String status; // 'Granted', 'Withdrawn', 'Pending Verification', 'Expired'
  final String source; // 'Web Form Opt-In', 'WhatsApp Written Consent', 'Signed Showroom Registration', 'Email Confirmation'
  final String evidenceText; // Descriptive record or quotation of agreement
  final String? ipAddress;
  final String? userAgent;
  final DateTime consentTimestamp;
  final DateTime? withdrawalTimestamp;
  final DateTime createdAt;

  ProspectConsentEventModel({
    String? id,
    required this.ownerId,
    required this.prospectId,
    required this.consentType,
    String? purpose,
    List<String>? communicationChannels,
    this.status = 'Granted',
    required this.source,
    this.evidenceText = 'Opt-in recorded during prospective buyer interaction.',
    this.ipAddress,
    this.userAgent,
    DateTime? consentTimestamp,
    this.withdrawalTimestamp,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        purpose = (purpose != null && purpose.trim().isNotEmpty) ? purpose.trim() : consentType,
        communicationChannels = (communicationChannels != null && communicationChannels.isNotEmpty)
            ? List<String>.unmodifiable(communicationChannels)
            : _inferChannelsFromText('$source $evidenceText'),
        consentTimestamp = consentTimestamp ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  bool get isGranted => status == 'Granted';
  bool get isWithdrawn => status == 'Withdrawn';

  /// True only if this consent event specifically authorizes promotional/broad marketing.
  bool get permitsBroadMarketing =>
      isGranted &&
      !isWithdrawn &&
      (purpose == 'Marketing & Promotion' || consentType == 'Marketing & Promotion');

  /// True if this consent event authorizes responding to a direct inquiry or recommendation.
  bool get permitsDirectInquiryResponse =>
      isGranted &&
      !isWithdrawn &&
      (purpose == 'Direct Inquiry Response' ||
          purpose == 'Property Recommendations' ||
          purpose == 'Marketing & Promotion');

  /// Checks whether this consent event permits outreach on a specific communication channel.
  bool permitsChannel(String channel) {
    if (!isGranted || isWithdrawn) return false;
    final norm = channel.trim().toLowerCase();
    return communicationChannels.any(
      (c) => c.toLowerCase() == 'all' || c.toLowerCase() == norm,
    );
  }

  static List<String> _inferChannelsFromText(String text) {
    final lower = text.toLowerCase();
    final channels = <String>[];
    if (lower.contains('whatsapp')) channels.add('WhatsApp');
    if (lower.contains('email') || lower.contains('e-mail')) channels.add('Email');
    if (lower.contains('sms')) channels.add('SMS');
    if (lower.contains('call') || lower.contains('phone') || lower.contains('tel')) {
      channels.add('Phone');
    }
    if (channels.isEmpty) {
      channels.add('Direct Inquiry Channel');
    }
    return List<String>.unmodifiable(channels);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'prospectId': prospectId,
      'consentType': consentType,
      'purpose': purpose,
      'communicationChannels': communicationChannels,
      'status': status,
      'source': source,
      'evidenceText': evidenceText,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'consentTimestamp': consentTimestamp.toIso8601String(),
      'withdrawalTimestamp': withdrawalTimestamp?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ProspectConsentEventModel.fromMap(Map<String, dynamic> map) {
    final type = map['consentType'] as String? ?? 'Direct Inquiry Response';
    return ProspectConsentEventModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      prospectId: map['prospectId'] as String? ?? '',
      consentType: type,
      purpose: map['purpose'] as String? ?? type,
      communicationChannels: map['communicationChannels'] != null
          ? List<String>.from(map['communicationChannels'])
          : null,
      status: map['status'] as String? ?? 'Granted',
      source: map['source'] as String? ?? 'Web Form Opt-In',
      evidenceText: map['evidenceText'] as String? ?? '',
      ipAddress: map['ipAddress'] as String?,
      userAgent: map['userAgent'] as String?,
      consentTimestamp: map['consentTimestamp'] != null
          ? DateTime.tryParse(map['consentTimestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      withdrawalTimestamp: map['withdrawalTimestamp'] != null
          ? DateTime.tryParse(map['withdrawalTimestamp'].toString())
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
