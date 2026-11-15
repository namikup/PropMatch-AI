import 'package:uuid/uuid.dart';

class BuyerModel {
  final String id;
  final String ownerId;
  final String name;
  final String email;
  final String phone;
  final double budgetMin;
  final double budgetMax;
  final String preferredLocation;
  final String preferredState;
  final String propertyType;
  final String purchasePurpose; // Own Stay, Investment, Own Stay & Investment
  final String buyingTimeline; // Immediately, Within 3 months, etc.
  final String leadSource; // Facebook Ads, WhatsApp Enquiry, etc.
  final String status; // New, Contacted, Interested, Viewing Scheduled, Negotiating, Converted, Lost
  final bool isDemo; // Clearly labelled DEMO DATA
  final String? audienceSegment; // Fictional assigned audience segment
  final String notes;
  final DateTime createdAt;

  BuyerModel({
    String? id,
    required this.ownerId,
    required this.name,
    this.email = '',
    this.phone = '',
    required this.budgetMin,
    required this.budgetMax,
    required this.preferredLocation,
    required this.preferredState,
    required this.propertyType,
    required this.purchasePurpose,
    required this.buyingTimeline,
    required this.leadSource,
    this.status = 'New',
    this.isDemo = false,
    this.audienceSegment,
    this.notes = '',
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  BuyerModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? email,
    String? phone,
    double? budgetMin,
    double? budgetMax,
    String? preferredLocation,
    String? preferredState,
    String? propertyType,
    String? purchasePurpose,
    String? buyingTimeline,
    String? leadSource,
    String? status,
    bool? isDemo,
    String? audienceSegment,
    String? notes,
    DateTime? createdAt,
  }) {
    return BuyerModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      preferredLocation: preferredLocation ?? this.preferredLocation,
      preferredState: preferredState ?? this.preferredState,
      propertyType: propertyType ?? this.propertyType,
      purchasePurpose: purchasePurpose ?? this.purchasePurpose,
      buyingTimeline: buyingTimeline ?? this.buyingTimeline,
      leadSource: leadSource ?? this.leadSource,
      status: status ?? this.status,
      isDemo: isDemo ?? this.isDemo,
      audienceSegment: audienceSegment ?? this.audienceSegment,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'email': email,
      'phone': phone,
      'budgetMin': budgetMin,
      'budgetMax': budgetMax,
      'preferredLocation': preferredLocation,
      'preferredState': preferredState,
      'propertyType': propertyType,
      'purchasePurpose': purchasePurpose,
      'buyingTimeline': buyingTimeline,
      'leadSource': leadSource,
      'status': status,
      'isDemo': isDemo,
      'audienceSegment': audienceSegment,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BuyerModel.fromMap(Map<String, dynamic> map) {
    return BuyerModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      budgetMin: (map['budgetMin'] as num?)?.toDouble() ?? 0.0,
      budgetMax: (map['budgetMax'] as num?)?.toDouble() ?? 0.0,
      preferredLocation: map['preferredLocation'] as String? ?? '',
      preferredState: map['preferredState'] as String? ?? '',
      propertyType: map['propertyType'] as String? ?? '',
      purchasePurpose: map['purchasePurpose'] as String? ?? 'Own Stay',
      buyingTimeline: map['buyingTimeline'] as String? ?? 'Within 3 months',
      leadSource: map['leadSource'] as String? ?? 'Direct',
      status: map['status'] as String? ?? 'New',
      isDemo: map['isDemo'] as bool? ?? false,
      audienceSegment: map['audienceSegment'] as String?,
      notes: map['notes'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
