import 'package:uuid/uuid.dart';

class UserModel {
  final String id;
  final String ownerId;
  final String fullName;
  final String email;
  final String phone;
  final String agencyName;
  final String renNumber; // Malaysian Real Estate Negotiator (REN) Registration Number
  final bool isRenVerified; // Strictly false until verified with LPPEH registry
  final String region;
  final String bio;
  final String landingPageSlug;
  final List<String> selectedProjectIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    String? id,
    required this.ownerId,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.agencyName = '',
    this.renNumber = '',
    this.isRenVerified = false,
    this.region = 'Penang & Northern Region',
    this.bio = 'Specialising in primary launches and high-growth investments across Penang and Northern corridor.',
    String? landingPageSlug,
    this.selectedProjectIds = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        landingPageSlug = landingPageSlug ?? ownerId,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  UserModel copyWith({
    String? id,
    String? ownerId,
    String? fullName,
    String? email,
    String? phone,
    String? agencyName,
    String? renNumber,
    bool? isRenVerified,
    String? region,
    String? bio,
    String? landingPageSlug,
    List<String>? selectedProjectIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      agencyName: agencyName ?? this.agencyName,
      renNumber: renNumber ?? this.renNumber,
      isRenVerified: isRenVerified ?? this.isRenVerified,
      region: region ?? this.region,
      bio: bio ?? this.bio,
      landingPageSlug: landingPageSlug ?? this.landingPageSlug,
      selectedProjectIds: selectedProjectIds ?? this.selectedProjectIds,
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
      'agencyName': agencyName,
      'renNumber': renNumber,
      'isRenVerified': isRenVerified,
      'region': region,
      'bio': bio,
      'landingPageSlug': landingPageSlug,
      'selectedProjectIds': selectedProjectIds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final created = map['createdAt'] != null
        ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
        : DateTime.now();
    return UserModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      agencyName: map['agencyName'] as String? ?? '',
      renNumber: map['renNumber'] as String? ?? '',
      isRenVerified: map['isRenVerified'] as bool? ?? false,
      region: map['region'] as String? ?? 'Penang & Northern Region',
      bio: map['bio'] as String? ?? 'Specialising in primary launches and high-growth investments across Penang and Northern corridor.',
      landingPageSlug: map['landingPageSlug'] as String?,
      selectedProjectIds: (map['selectedProjectIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: created,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? created
          : created,
    );
  }
}
