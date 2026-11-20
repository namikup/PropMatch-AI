import '../../models/prospect_source_model.dart';
import 'prospect_source_adapter.dart';
import 'property_portal_adapter.dart';
import 'partner_agency_adapter.dart';
import 'developer_adapter.dart';
import 'crm_import_adapter.dart';

/// Central registry managing all prospect source adapters and default channel configurations.
class ProspectSourceRegistry {
  static final Map<String, ProspectSourceAdapter> _adapters = {
    'Property Portal': PropertyPortalAdapter(),
    'Partner Agency': PartnerAgencyAdapter(),
    'Developer': DeveloperAdapter(),
    'CRM Import': CRMImportAdapter(),
  };

  /// Returns registered adapter for a given source type.
  static ProspectSourceAdapter? getAdapter(String sourceType) {
    return _adapters[sourceType];
  }

  /// Generates initial standard data source configurations for an agent.
  static List<ProspectSourceModel> getInitialSourcesForAgent(String ownerId) {
    return [
      ProspectSourceModel(
        ownerId: ownerId,
        name: 'Malaysian Property Portals Feed',
        type: 'Property Portal',
        status: 'Active',
        configuration: {
          'channels': ['iProperty Malaysia', 'PropertyGuru', 'EdgeProp'],
          'frequency': 'Hourly Webhook Batch',
          'autoImport': true,
        },
        totalProspectsImported: 42,
        lastSyncAt: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
      ProspectSourceModel(
        ownerId: ownerId,
        name: 'Klang Valley Co-Broke Agency Alliance',
        type: 'Partner Agency',
        status: 'Active',
        configuration: {
          'partnerCount': 18,
          'coBrokeAgreementVersion': '2026.1-MIEA',
          'autoConsentVerification': false,
        },
        totalProspectsImported: 28,
        lastSyncAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ProspectSourceModel(
        ownerId: ownerId,
        name: 'Direct Developer Showroom Visitor Registrations',
        type: 'Developer',
        status: 'Active',
        configuration: {
          'activeDevelopers': ['Mah Sing Group', 'Sime Darby Property', 'Sunway Property'],
          'requireShowroomConsentSlip': true,
        },
        totalProspectsImported: 35,
        lastSyncAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      ProspectSourceModel(
        ownerId: ownerId,
        name: 'Agency Enterprise CRM Database',
        type: 'CRM Import',
        status: 'Configured',
        configuration: {
          'format': 'CSV / JSON REST Sync',
          'defaultContactEligibility': 'Pending Consent',
        },
        totalProspectsImported: 15,
        lastSyncAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }
}
