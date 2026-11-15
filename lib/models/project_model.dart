import 'package:uuid/uuid.dart';

class ProjectModel {
  final String id;
  final String ownerId;
  final String name;
  final String developer;
  final String location;
  final String state; // Penang, Kedah, etc.
  final String propertyType; // Condominium, Terrace House, etc.
  final double startingPrice;
  final double maximumPrice;
  final int bedrooms;
  final int bathrooms;
  final double builtUpArea; // in sqft
  final List<String> facilities;
  final List<String> nearbyAmenities;
  final String description;
  final String purpose; // Own Stay, Investment, Own Stay & Investment
  final List<String> imageUrls;
  final List<String> brochures;
  final String status; // New Launch, Under Construction, Completed, Upcoming
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectModel({
    String? id,
    required this.ownerId,
    required this.name,
    required this.developer,
    required this.location,
    required this.state,
    required this.propertyType,
    required this.startingPrice,
    required this.maximumPrice,
    required this.bedrooms,
    required this.bathrooms,
    required this.builtUpArea,
    this.facilities = const [],
    this.nearbyAmenities = const [],
    required this.description,
    required this.purpose,
    this.imageUrls = const [],
    this.brochures = const [],
    this.status = 'New Launch',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ProjectModel copyWith({
    String? id,
    String? ownerId,
    String? name,
    String? developer,
    String? location,
    String? state,
    String? propertyType,
    double? startingPrice,
    double? maximumPrice,
    int? bedrooms,
    int? bathrooms,
    double? builtUpArea,
    List<String>? facilities,
    List<String>? nearbyAmenities,
    String? description,
    String? purpose,
    List<String>? imageUrls,
    List<String>? brochures,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      developer: developer ?? this.developer,
      location: location ?? this.location,
      state: state ?? this.state,
      propertyType: propertyType ?? this.propertyType,
      startingPrice: startingPrice ?? this.startingPrice,
      maximumPrice: maximumPrice ?? this.maximumPrice,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      builtUpArea: builtUpArea ?? this.builtUpArea,
      facilities: facilities ?? this.facilities,
      nearbyAmenities: nearbyAmenities ?? this.nearbyAmenities,
      description: description ?? this.description,
      purpose: purpose ?? this.purpose,
      imageUrls: imageUrls ?? this.imageUrls,
      brochures: brochures ?? this.brochures,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'developer': developer,
      'location': location,
      'state': state,
      'propertyType': propertyType,
      'startingPrice': startingPrice,
      'maximumPrice': maximumPrice,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'builtUpArea': builtUpArea,
      'facilities': facilities,
      'nearbyAmenities': nearbyAmenities,
      'description': description,
      'purpose': purpose,
      'imageUrls': imageUrls,
      'brochures': brochures,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      developer: map['developer'] as String? ?? '',
      location: map['location'] as String? ?? '',
      state: map['state'] as String? ?? '',
      propertyType: map['propertyType'] as String? ?? '',
      startingPrice: (map['startingPrice'] as num?)?.toDouble() ?? 0.0,
      maximumPrice: (map['maximumPrice'] as num?)?.toDouble() ?? 0.0,
      bedrooms: (map['bedrooms'] as num?)?.toInt() ?? 0,
      bathrooms: (map['bathrooms'] as num?)?.toInt() ?? 0,
      builtUpArea: (map['builtUpArea'] as num?)?.toDouble() ?? 0.0,
      facilities: List<String>.from(map['facilities'] ?? []),
      nearbyAmenities: List<String>.from(map['nearbyAmenities'] ?? []),
      description: map['description'] as String? ?? '',
      purpose: map['purpose'] as String? ?? 'Own Stay',
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      brochures: List<String>.from(map['brochures'] ?? []),
      status: map['status'] as String? ?? 'New Launch',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
