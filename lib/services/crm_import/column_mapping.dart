/// Target fields available in the PropMatch AI Prospect Database.
enum TargetProspectField {
  fullName,
  phone,
  email,
  budgetMin,
  budgetMax,
  preferredLocation,
  preferredState,
  propertyType,
  purchasePurpose,
  buyingTimeline,
  sourceReference,
  consentStatus,
  consentEvidence,
  notes,
}

class TargetFieldDefinition {
  final TargetProspectField field;
  final String key;
  final String label;
  final String description;
  final bool isRequired;
  final List<String> heuristicAliases;

  const TargetFieldDefinition({
    required this.field,
    required this.key,
    required this.label,
    required this.description,
    this.isRequired = false,
    required this.heuristicAliases,
  });
}

class CRMColumnMappingRegistry {
  static const List<TargetFieldDefinition> definitions = [
    TargetFieldDefinition(
      field: TargetProspectField.fullName,
      key: 'fullName',
      label: 'Prospect Full Name',
      description: 'Primary identity of prospective buyer (individual or representative).',
      isRequired: true,
      heuristicAliases: [
        'full_name',
        'fullname',
        'name',
        'buyer_name',
        'client_name',
        'prospect_name',
        'lead_name',
        'customer',
        'client',
        'nama',
        'buyer',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.phone,
      key: 'phone',
      label: 'Phone Number',
      description: 'Malaysian mobile or contact phone number for communication.',
      isRequired: false,
      heuristicAliases: [
        'phone',
        'mobile',
        'contact',
        'tel',
        'telephone',
        'handphone',
        'hp',
        'phone_number',
        'mobile_number',
        'no_tel',
        'contact_number',
        'phone_no',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.email,
      key: 'email',
      label: 'Email Address',
      description: 'Electronic contact email address.',
      isRequired: false,
      heuristicAliases: [
        'email',
        'email_address',
        'e-mail',
        'mail',
        'emil',
        'alamat_emel',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.budgetMin,
      key: 'budgetMin',
      label: 'Minimum Budget (RM)',
      description: 'Lower limit of acquisition budget bracket.',
      heuristicAliases: [
        'budget_min',
        'min_budget',
        'minimum_budget',
        'budget_from',
        'price_min',
        'min_price',
        'harga_min',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.budgetMax,
      key: 'budgetMax',
      label: 'Maximum Budget (RM)',
      description: 'Upper limit of acquisition budget bracket.',
      heuristicAliases: [
        'budget_max',
        'max_budget',
        'maximum_budget',
        'budget_to',
        'budget',
        'price_max',
        'max_price',
        'price',
        'harga_max',
        'purchasing_power',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.preferredLocation,
      key: 'preferredLocation',
      label: 'Preferred Location / City',
      description: 'Target locality, township, or district in Malaysia.',
      heuristicAliases: [
        'preferred_location',
        'location',
        'area',
        'target_area',
        'city',
        'town',
        'lokasi',
        'kawasan',
        'locality',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.preferredState,
      key: 'preferredState',
      label: 'Preferred State',
      description: 'Malaysian State (e.g. Penang, Selangor, KL, Johor).',
      heuristicAliases: [
        'preferred_state',
        'state',
        'negeri',
        'region',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.propertyType,
      key: 'propertyType',
      label: 'Property Type',
      description: 'Condominium, Landed Terrace, Semi-D, Bungalow, Shophouse, etc.',
      heuristicAliases: [
        'property_type',
        'type',
        'unit_type',
        'jenis_hartanah',
        'property_category',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.purchasePurpose,
      key: 'purchasePurpose',
      label: 'Purchase Purpose',
      description: 'Own Stay, Investment, or Both.',
      heuristicAliases: [
        'purchase_purpose',
        'purpose',
        'buying_purpose',
        'intent',
        'tujuan',
        'use_case',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.buyingTimeline,
      key: 'buyingTimeline',
      label: 'Buying Timeline',
      description: 'Immediately, Within 3 months, Exploring, etc.',
      heuristicAliases: [
        'buying_timeline',
        'timeline',
        'urgency',
        'tempoh',
        'horizon',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.sourceReference,
      key: 'sourceReference',
      label: 'Source Reference / Channel',
      description: 'External campaign name, portal reference, or partner source ID.',
      heuristicAliases: [
        'source_reference',
        'source',
        'lead_source',
        'channel',
        'campaign',
        'referrer',
        'source_ref',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.consentStatus,
      key: 'consentStatus',
      label: 'PDPA Consent Status',
      description: 'Opt-in status provided in source system (Granted / Withdrawn / None).',
      heuristicAliases: [
        'consent_status',
        'consent',
        'pdpa_consent',
        'opt_in',
        'optin',
        'permission',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.consentEvidence,
      key: 'consentEvidence',
      label: 'Consent Evidence / Note',
      description: 'Documented proof of consent (e.g. showroom card number, timestamp, chat quote).',
      heuristicAliases: [
        'consent_evidence',
        'evidence',
        'consent_proof',
        'consent_note',
        'consent_notes',
        'consent_remarks',
        'pdpa_proof',
        'opt_in_evidence',
        'proof_of_consent',
      ],
    ),
    TargetFieldDefinition(
      field: TargetProspectField.notes,
      key: 'notes',
      label: 'Remarks / Notes',
      description: 'Agent remarks and prospect background details.',
      heuristicAliases: [
        'notes',
        'remarks',
        'comments',
        'catatan',
        'description',
      ],
    ),
  ];

  static TargetFieldDefinition getDefinition(TargetProspectField field) {
    return definitions.firstWhere((d) => d.field == field);
  }
}

/// Represents the active column mapping configuration for a file import session.
class ColumnMappingConfig {
  final Map<TargetProspectField, String?> mappings;

  ColumnMappingConfig([Map<TargetProspectField, String?>? initial])
      : mappings = initial != null
            ? Map<TargetProspectField, String?>.from(initial)
            : {for (var d in CRMColumnMappingRegistry.definitions) d.field: null};

  /// Smart auto-mapping heuristic that inspects file headers against target aliases.
  factory ColumnMappingConfig.autoDetect(List<String> fileHeaders) {
    final result = <TargetProspectField, String?>{};
    final usedHeaders = <String>{};

    // Pass 1: Exact matches
    for (final def in CRMColumnMappingRegistry.definitions) {
      String? matchedHeader;

      for (final header in fileHeaders) {
        if (usedHeaders.contains(header)) continue;
        final normalizedHeader = header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').trim();

        for (final alias in def.heuristicAliases) {
          final normalizedAlias = alias.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').trim();
          if (normalizedHeader == normalizedAlias) {
            matchedHeader = header;
            break;
          }
        }
        if (matchedHeader != null) break;
      }

      if (matchedHeader != null) {
        result[def.field] = matchedHeader;
        usedHeaders.add(matchedHeader);
      }
    }

    // Pass 2: Prefix / Suffix matches for remaining unmapped fields
    for (final def in CRMColumnMappingRegistry.definitions) {
      if (result.containsKey(def.field) && result[def.field] != null) continue;
      String? matchedHeader;

      for (final header in fileHeaders) {
        if (usedHeaders.contains(header)) continue;
        final normalizedHeader = header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').trim();

        for (final alias in def.heuristicAliases) {
          final normalizedAlias = alias.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_').trim();
          if (normalizedHeader.startsWith('${normalizedAlias}_') ||
              normalizedHeader.endsWith('_$normalizedAlias')) {
            matchedHeader = header;
            break;
          }
        }
        if (matchedHeader != null) break;
      }

      if (matchedHeader != null) {
        result[def.field] = matchedHeader;
        usedHeaders.add(matchedHeader);
      } else {
        result[def.field] = null;
      }
    }

    return ColumnMappingConfig(result);
  }

  void setMapping(TargetProspectField field, String? header) {
    mappings[field] = header;
  }

  String? getHeader(TargetProspectField field) => mappings[field];

  bool get hasRequiredFields {
    for (final def in CRMColumnMappingRegistry.definitions) {
      if (def.isRequired && (mappings[def.field] == null || mappings[def.field]!.isEmpty)) {
        return false;
      }
    }
    return true;
  }

  List<String> get missingRequiredLabels {
    final missing = <String>[];
    for (final def in CRMColumnMappingRegistry.definitions) {
      if (def.isRequired && (mappings[def.field] == null || mappings[def.field]!.isEmpty)) {
        missing.add(def.label);
      }
    }
    return missing;
  }

  ColumnMappingConfig copyWith() {
    return ColumnMappingConfig(Map<TargetProspectField, String?>.from(mappings));
  }
}
