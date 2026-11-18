import 'package:uuid/uuid.dart';

class UserModel {
  final String id;
  final String ownerId;
  final String fullName;
  final String email;
  final String phone;
  final String agencyName;
  final String renNumber; // Malaysian Real Estate Negotiator (REN) Registration Number
  final String region;
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
    this.region = 'Penang & Northern Region',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
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
    String? region,
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
      region: region ?? this.region,
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
      'region': region,
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
      region: map['region'] as String? ?? 'Penang & Northern Region',
      createdAt: created,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? created
          : created,
    );
  }
}
