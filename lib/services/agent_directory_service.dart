import '../models/user_model.dart';
import '../models/project_model.dart';
import '../config/pilot_config.dart';
import 'demo_data_service.dart';

/// Central directory service for resolving agent profiles for public landing pages.
/// Supports synthetic demo agents (Agent A, Agent B, Agent C) and dynamically
/// registered agent accounts.
class AgentDirectoryService {
  static final Map<String, UserModel> _syntheticAgents = {
    'agent-alex-penang-001': UserModel(
      id: 'usr-agent-alex-001',
      ownerId: 'agent-alex-penang-001',
      landingPageSlug: 'alex-tan-penang',
      fullName: 'Alex Tan Chee Keong',
      email: 'alex.tan@iqirealty.com',
      phone: '+60124455667',
      agencyName: 'IQI Realty Sdn Bhd',
      renNumber: 'REN 45892',
      isRenVerified: true,
      region: 'Penang & Northern Region',
      bio: 'Premier Penang property specialist with 8+ years specializing in Batu Kawan townships and high-yield Gurney residences.',
    ),
    'alex-tan-penang': UserModel(
      id: 'usr-agent-alex-001',
      ownerId: 'agent-alex-penang-001',
      landingPageSlug: 'alex-tan-penang',
      fullName: 'Alex Tan Chee Keong',
      email: 'alex.tan@iqirealty.com',
      phone: '+60124455667',
      agencyName: 'IQI Realty Sdn Bhd',
      renNumber: 'REN 45892',
      isRenVerified: true,
      region: 'Penang & Northern Region',
      bio: 'Premier Penang property specialist with 8+ years specializing in Batu Kawan townships and high-yield Gurney residences.',
    ),
    'agent-brenda-kl-002': UserModel(
      id: 'usr-agent-brenda-002',
      ownerId: 'agent-brenda-kl-002',
      landingPageSlug: 'brenda-lim-kl',
      fullName: 'Brenda Lim Shu Wei',
      email: 'brenda.lim@propnex.com.my',
      phone: '+60162233445',
      agencyName: 'PropNex Realty Malaysia',
      renNumber: 'REN 31204',
      isRenVerified: true,
      region: 'Kuala Lumpur & Klang Valley',
      bio: 'Senior Real Estate Negotiator focusing on Mont Kiara, KLCC luxury condos, and expatriate relocation portfolios.',
    ),
    'brenda-lim-kl': UserModel(
      id: 'usr-agent-brenda-002',
      ownerId: 'agent-brenda-kl-002',
      landingPageSlug: 'brenda-lim-kl',
      fullName: 'Brenda Lim Shu Wei',
      email: 'brenda.lim@propnex.com.my',
      phone: '+60162233445',
      agencyName: 'PropNex Realty Malaysia',
      renNumber: 'REN 31204',
      isRenVerified: true,
      region: 'Kuala Lumpur & Klang Valley',
      bio: 'Senior Real Estate Negotiator focusing on Mont Kiara, KLCC luxury condos, and expatriate relocation portfolios.',
    ),
    'agent-calvin-penang-003': UserModel(
      id: 'usr-agent-calvin-003',
      ownerId: 'agent-calvin-penang-003',
      landingPageSlug: 'calvin-ong-penang',
      fullName: 'Calvin Ong',
      email: 'calvin.ong@cornerstone.my',
      phone: '+60198877665',
      agencyName: 'Cornerstone Xstate',
      renNumber: 'REN 99999',
      isRenVerified: false, // Unverified REN for audit testing
      region: 'Penang & Northern Region',
      bio: 'Subsale landed home negotiator covering Seberang Perai and Mainland Penang corridors.',
    ),
    'calvin-ong-penang': UserModel(
      id: 'usr-agent-calvin-003',
      ownerId: 'agent-calvin-penang-003',
      landingPageSlug: 'calvin-ong-penang',
      fullName: 'Calvin Ong',
      email: 'calvin.ong@cornerstone.my',
      phone: '+60198877665',
      agencyName: 'Cornerstone Xstate',
      renNumber: 'REN 99999',
      isRenVerified: false,
      region: 'Penang & Northern Region',
      bio: 'Subsale landed home negotiator covering Seberang Perai and Mainland Penang corridors.',
    ),
    'demo-agent-001': UserModel(
      id: 'usr-001',
      ownerId: 'demo-agent-001',
      landingPageSlug: 'demo-agent-001',
      fullName: 'Malaysian Agent (REN)',
      email: 'agent@propmatch.ai',
      phone: '+6012-3456789',
      agencyName: 'PropMatch Realty Malaysia',
      renNumber: 'REN 12345',
      isRenVerified: true,
      region: 'Penang & Northern Region',
      bio: 'Specialising in primary launches and high-growth investments across Penang and Northern corridor.',
    ),
  };

  /// Register or update an agent dynamically
  static void registerAgent(UserModel agent) {
    _syntheticAgents[agent.ownerId] = agent;
    if (agent.landingPageSlug.isNotEmpty) {
      _syntheticAgents[agent.landingPageSlug] = agent;
    }
  }

  /// Get the designated pilot agent for Single-Agent Private Pilot mode
  static UserModel getDesignatedPilotAgent() {
    return _syntheticAgents[PilotConfig.defaultPilotAgentSlug] ??
        _syntheticAgents[PilotConfig.defaultPilotAgentOwnerId] ??
        _syntheticAgents.values.first;
  }

  /// Resolve an agent by slug or ownerId
  static UserModel? findAgent(String slugOrId) {
    if (slugOrId.trim().isEmpty) return null;
    final clean = slugOrId.trim().toLowerCase();

    for (final entry in _syntheticAgents.entries) {
      if (entry.key.toLowerCase() == clean ||
          entry.value.ownerId.toLowerCase() == clean ||
          entry.value.landingPageSlug.toLowerCase() == clean) {
        return entry.value;
      }
    }
    return null;
  }

  /// Get featured projects appropriate for the agent's focus territory,
  /// prioritizing the agent's actual registered property portfolio if available.
  static List<ProjectModel> getFeaturedProjectsForAgent(
    UserModel agent, {
    List<ProjectModel>? availableProjects,
  }) {
    // 1. Prioritize real properties registered and owned by this agent
    if (availableProjects != null && availableProjects.isNotEmpty) {
      final ownedProjects = availableProjects
          .where((p) => p.ownerId == agent.ownerId)
          .toList();
      if (ownedProjects.isNotEmpty) {
        return ownedProjects;
      }
    }

    // 2. Fall back to regional recommended properties
    final all = DemoDataService.getInitialProjects();
    final region = agent.region.toLowerCase();
    if (region.contains('penang')) {
      final penangProjects = all.where((p) {
        final loc = p.location.toLowerCase();
        return loc.contains('penang') || loc.contains('batu kawan') || loc.contains('gurney');
      }).toList();
      return penangProjects.isNotEmpty ? penangProjects : all.take(2).toList();
    } else if (region.contains('kl') || region.contains('kuala lumpur') || region.contains('klang')) {
      final klProjects = all.where((p) {
        final loc = p.location.toLowerCase();
        return loc.contains('kuala lumpur') || loc.contains('kl') || loc.contains('mont kiara') || loc.contains('bangsar');
      }).toList();
      return klProjects.isNotEmpty ? klProjects : all.take(2).toList();
    }
    return all.take(2).toList();
  }

  /// Generate public landing page share URL
  static String getPublicLandingPageUrl(String slugOrId, {String baseUrl = 'https://app.propmatch.ai'}) {
    return '$baseUrl/#/agent/$slugOrId';
  }
}
