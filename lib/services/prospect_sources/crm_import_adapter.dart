import '../../models/prospect_model.dart';
import 'prospect_source_adapter.dart';

/// Adapter interface for CSV, JSON, and standard CRM file exports (Salesforce, HubSpot, custom CSV).
class CRMImportAdapter implements ProspectSourceAdapter {
  final String _systemName;

  CRMImportAdapter([this._systemName = 'CRM Import Engine']);

  @override
  String get sourceName => _systemName;

  @override
  String get sourceType => 'CRM Import';

  @override
  Future<bool> testConnection(Map<String, dynamic> config) async {
    // File or format schema check
    return config.containsKey('format') || config.containsKey('mapping');
  }

  @override
  Future<List<ProspectModel>> fetchProspects({
    required String ownerId,
    Map<String, dynamic>? parameters,
  }) async {
    // Ingests batch records from parameters['records']
    final rawRecords = parameters?['records'] as List<dynamic>? ?? [];
    final prospects = <ProspectModel>[];

    for (final raw in rawRecords) {
      if (raw is Map<String, dynamic> && validateProspectData(raw)) {
        prospects.add(ProspectModel(
          ownerId: ownerId,
          fullName: raw['fullName']?.toString() ?? raw['name']?.toString() ?? 'Prospective Lead',
          email: raw['email']?.toString() ?? '',
          phone: raw['phone']?.toString() ?? '',
          preferredLocations: raw['preferredLocations'] != null
              ? List<String>.from(raw['preferredLocations'])
              : [raw['preferredLocation']?.toString() ?? 'Kuala Lumpur'],
          preferredState: raw['preferredState']?.toString() ?? 'Kuala Lumpur',
          propertyTypes: raw['propertyTypes'] != null
              ? List<String>.from(raw['propertyTypes'])
              : [raw['propertyType']?.toString() ?? 'Condominium'],
          budgetMin: (raw['budgetMin'] as num?)?.toDouble() ?? 500000.0,
          budgetMax: (raw['budgetMax'] as num?)?.toDouble() ?? 900000.0,
          purchasePurpose: raw['purchasePurpose']?.toString() ?? 'Own Stay',
          buyingTimeline: raw['buyingTimeline']?.toString() ?? 'Within 3 months',
          status: 'Imported',
          verificationStatus: 'Unverified',
          contactEligibility: 'Pending Consent', // STRICT: Never default to Eligible
          primarySource: 'CRM Import',
          notes: raw['notes']?.toString() ?? 'Imported via CSV/CRM mapping.',
          isDemo: raw['isDemo'] as bool? ?? false,
        ));
      }
    }

    return prospects;
  }

  @override
  bool validateProspectData(Map<String, dynamic> rawRecord) {
    final name = rawRecord['fullName'] ?? rawRecord['name'];
    return name != null && name.toString().trim().isNotEmpty;
  }

  static String getSampleCsv() {
    return '''full_name,phone,email,ic_number,location,state,budget_min,budget_max,property_type
Tan Wei Hong,+6012-4458921,tan.weihong@gmail.com,910412-07-5519,Batu Kawan,Penang,450000,600000,Condominium
Siti Nurhaliza binti Yusof,+6019-3321908,siti.yusof@outlook.com,880923-08-5432,Bangi,Selangor,500000,750000,Terrace House
Kavitha a/p Ramesh,+6016-8874123,kavitha.ramesh@yahoo.com,940615-14-5820,Petaling Jaya,Selangor,650000,850000,Serviced Residence''';
  }

  List<ProspectModel> parseCsv(String csvString, {required String ownerId}) {
    final lines = csvString.split(RegExp(r'\r?\n')).where((line) => line.trim().isNotEmpty).toList();
    if (lines.length <= 1) return [];

    final prospects = <ProspectModel>[];
    final header = lines.first.split(',').map((h) => h.trim().toLowerCase()).toList();

    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',').map((c) => c.trim()).toList();
      if (cols.length < 3) continue;

      String name = '';
      String phone = '';
      String email = '';
      String? ic;
      String location = 'Penang';
      String state = 'Penang';
      double minB = 400000;
      double maxB = 700000;
      String pType = 'Condominium';

      for (int c = 0; c < cols.length && c < header.length; c++) {
        final h = header[c];
        final val = cols[c];
        if (h == 'full_name' || h == 'name') {
          name = val;
        } else if (h == 'phone') {
          phone = val;
        } else if (h == 'email') {
          email = val;
        } else if (h == 'ic_number' || h == 'ic' || h == 'nric') {
          ic = val.isNotEmpty ? val : null;
        } else if (h == 'location' || h == 'preferred_location') {
          location = val;
        } else if (h == 'state' || h == 'preferred_state') {
          state = val;
        } else if (h == 'budget_min') {
          minB = double.tryParse(val) ?? minB;
        } else if (h == 'budget_max') {
          maxB = double.tryParse(val) ?? maxB;
        } else if (h == 'property_type') {
          pType = val;
        }
      }

      if (name.isNotEmpty) {
        prospects.add(ProspectModel(
          ownerId: ownerId,
          fullName: name,
          phone: phone,
          email: email,
          icNumber: ic,
          preferredLocations: [location],
          preferredState: state,
          propertyTypes: [pType],
          budgetMin: minB,
          budgetMax: maxB,
          purchasePurpose: 'Own Stay',
          buyingTimeline: 'Within 3 months',
          status: 'Imported',
          verificationStatus: 'Unverified',
          contactEligibility: 'Pending Consent', // STRICT: Never default to Eligible
          primarySource: 'CRM Import',
          notes: 'Imported via CSV file.',
          isDemo: false,
        ));
      }
    }

    return prospects;
  }
}
