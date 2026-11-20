import 'package:uuid/uuid.dart';

/// Core entity representing a prospective property buyer in the intelligence pipeline.
/// Kept distinct from active CRM [BuyerModel] records.
class ProspectModel {
  final String id;
  final String ownerId; // Immutable agent UID
  final String fullName;
  final String email;
  final String phone;
  final String? icNumber;
  final List<String> preferredLocations;
  final String preferredState;
  final List<String> propertyTypes;
  final double budgetMin;
  final double budgetMax;
  final String purchasePurpose; // Own Stay, Investment, Both
  final String buyingTimeline; // Immediately, Within 3 months, Within 6 months, 1 year+, Exploring
  final int bedroomsNeeded;
  final String status; // Discovered, Imported, Verified, Qualified, Matched, Archived
  final String verificationStatus; // Unverified, Phone Verified, Email Verified, Identity Verified
  final String contactEligibility; // Ineligible, Pending Consent, Eligible, Do Not Contact
  final List<String> consentedPurposes; // e.g. ['Direct Inquiry Response'], ['Marketing & Promotion']
  final List<String> consentedChannels; // e.g. ['WhatsApp'], ['Email'], ['Phone']
  final String primarySource; // Property Portal, Partner Agency, Developer, CRM Import, Agent Registration
  final String? primarySourceId;
  final double confidenceScore; // 0 - 100
  final String notes;
  final bool isDemo;
  final List<String> tags;
  final DateTime lastActiveAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProspectModel({
    String? id,
    required this.ownerId,
    required this.fullName,
    this.email = '',
    this.phone = '',
    this.icNumber,
    List<String>? preferredLocations,
    required this.preferredState,
    List<String>? propertyTypes,
    required this.budgetMin,
    required this.budgetMax,
    this.purchasePurpose = 'Own Stay',
    this.buyingTimeline = 'Within 3 months',
    this.bedroomsNeeded = 3,
    this.status = 'Discovered',
    this.verificationStatus = 'Unverified',
    this.contactEligibility = 'Pending Consent', // NEVER automatically Eligible
    List<String>? consentedPurposes,
    List<String>? consentedChannels,
    required this.primarySource,
    this.primarySourceId,
    this.confidenceScore = 75.0,
    this.notes = '',
    this.isDemo = false,
    List<String>? tags,
    DateTime? lastActiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        preferredLocations = preferredLocations ?? const [],
        propertyTypes = propertyTypes ?? const [],
        consentedPurposes = consentedPurposes ?? const [],
        consentedChannels = consentedChannels ?? const [],
        tags = tags ?? const [],
        lastActiveAt = lastActiveAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isEligibleForContact => contactEligibility == 'Eligible';
  bool get isPendingConsent => contactEligibility == 'Pending Consent';
  bool get isDoNotContact => contactEligibility == 'Do Not Contact';
  bool get isVerified => verificationStatus != 'Unverified';

  /// True ONLY if the prospect is eligible for contact AND has explicitly granted
  /// consent for 'Marketing & Promotion'. A 'Direct Inquiry Response' grant does NOT
  /// authorize broad promotional marketing.
  bool get isEligibleForMarketing =>
      isEligibleForContact &&
      !isDoNotContact &&
      consentedPurposes.contains('Marketing & Promotion');

  /// True if the prospect is eligible for direct inquiry follow-up.
  bool get isEligibleForInquiryResponse =>
      isEligibleForContact &&
      !isDoNotContact &&
      (consentedPurposes.isEmpty ||
          consentedPurposes.contains('Direct Inquiry Response') ||
          consentedPurposes.contains('Property Recommendations') ||
          consentedPurposes.contains('Marketing & Promotion'));

  /// Evaluates whether the prospect can be contacted for a specific [purpose] and optional [channel].
  bool canContact({
    String purpose = 'Direct Inquiry Response',
    String? channel,
  }) {
    if (isDoNotContact || !isEligibleForContact) return false;

    if (purpose == 'Marketing & Promotion' && !isEligibleForMarketing) {
      return false;
    }

    if (purpose == 'Third-Party Sharing' &&
        !consentedPurposes.contains('Third-Party Sharing')) {
      return false;
    }

    if (channel != null && channel.trim().isNotEmpty && consentedChannels.isNotEmpty) {
      final normChannel = channel.trim().toLowerCase();
      final channelAllowed = consentedChannels.any(
        (c) => c.toLowerCase() == 'all' || c.toLowerCase() == normChannel,
      );
      if (!channelAllowed) return false;
    }

    return true;
  }

  String get maskedIc {
    if (icNumber == null || icNumber!.isEmpty) return 'N/A';
    final clean = icNumber!.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.length >= 12) {
      return '${clean.substring(0, 6)}-${clean.substring(6, 8)}-****';
    } else if (clean.length >= 6) {
      return '${clean.substring(0, clean.length - 4)}****';
    }
    return '******';
  }

  String get budgetDisplay {
    if (budgetMin <= 0 && budgetMax <= 0) return 'Undisclosed';
    return 'RM ${(budgetMin / 1000).toStringAsFixed(0)}k - RM ${(budgetMax / 1000).toStringAsFixed(0)}k';
  }

  ProspectModel copyWith({
    String? id,
    String? ownerId,
    String? fullName,
    String? email,
    String? phone,
    String? icNumber,
    List<String>? preferredLocations,
    String? preferredState,
    List<String>? propertyTypes,
    double? budgetMin,
    double? budgetMax,
    String? purchasePurpose,
    String? buyingTimeline,
    int? bedroomsNeeded,
    String? status,
    String? verificationStatus,
    String? contactEligibility,
    List<String>? consentedPurposes,
    List<String>? consentedChannels,
    String? primarySource,
    String? primarySourceId,
    double? confidenceScore,
    String? notes,
    bool? isDemo,
    List<String>? tags,
    DateTime? lastActiveAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProspectModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      icNumber: icNumber ?? this.icNumber,
      preferredLocations: preferredLocations ?? this.preferredLocations,
      preferredState: preferredState ?? this.preferredState,
      propertyTypes: propertyTypes ?? this.propertyTypes,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      purchasePurpose: purchasePurpose ?? this.purchasePurpose,
      buyingTimeline: buyingTimeline ?? this.buyingTimeline,
      bedroomsNeeded: bedroomsNeeded ?? this.bedroomsNeeded,
      status: status ?? this.status,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      contactEligibility: contactEligibility ?? this.contactEligibility,
      consentedPurposes: consentedPurposes ?? this.consentedPurposes,
      consentedChannels: consentedChannels ?? this.consentedChannels,
      primarySource: primarySource ?? this.primarySource,
      primarySourceId: primarySourceId ?? this.primarySourceId,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      notes: notes ?? this.notes,
      isDemo: isDemo ?? this.isDemo,
      tags: tags ?? this.tags,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'icNumber': icNumber,
      'preferredLocations': preferredLocations,
      'preferredState': preferredState,
      'propertyTypes': propertyTypes,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'purchasePurpose': purchasePurpose,
      'buyingTimeline': buyingTimeline,
      'bedroomsNeeded': bedroomsNeeded,
      'status': status,
      'verificationStatus': verificationStatus,
      'contactEligibility': contactEligibility,
      'consentedPurposes': consentedPurposes,
      'consentedChannels': consentedChannels,
      'primarySource': primarySource,
      'primarySourceId': primarySourceId,
      'confidenceScore': confidenceScore,
      'notes': notes,
      'isDemo': isDemo,
      'tags': tags,
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProspectModel.fromMap(Map<String, dynamic> map) {
    return ProspectModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      icNumber: map['icNumber'] as String?,
      preferredLocations: List<String>.from(map['preferredLocations'] ?? []),
      preferredState: map['preferredState'] as String? ?? '',
      propertyTypes: List<String>.from(map['propertyTypes'] ?? []),
      budgetMin: (map['budgetMin'] as num?)?.toDouble() ?? 0.0,
      budgetMax: (map['budgetMax'] as num?)?.toDouble() ?? 0.0,
      purchasePurpose: map['purchasePurpose'] as String? ?? 'Own Stay',
      buyingTimeline: map['buyingTimeline'] as String? ?? 'Within 3 months',
      bedroomsNeeded: (map['bedroomsNeeded'] as num?)?.toInt() ?? 3,
      status: map['status'] as String? ?? 'Discovered',
      verificationStatus: map['verificationStatus'] as String? ?? 'Unverified',
      contactEligibility: map['contactEligibility'] as String? ?? 'Pending Consent',
      consentedPurposes: List<String>.from(map['consentedPurposes'] ?? []),
      consentedChannels: List<String>.from(map['consentedChannels'] ?? []),
      primarySource: map['primarySource'] as String? ?? 'Property Portal',
      primarySourceId: map['primarySourceId'] as String?,
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 75.0,
      notes: map['notes'] as String? ?? '',
      isDemo: map['isDemo'] as bool? ?? false,
      tags: List<String>.from(map['tags'] ?? []),
      lastActiveAt: map['lastActiveAt'] != null
          ? DateTime.tryParse(map['lastActiveAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
