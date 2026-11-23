/// Configuration for PropMatch AI Single-Agent Private Pilot.
/// Controls access, feature flags, and ensures platform features remain
/// scoped exclusively to the designated pilot agent.
class PilotConfig {
  PilotConfig._();

  /// Whether the platform is running in Single-Agent Private Pilot mode.
  /// When true:
  /// - Unrestricted public registration is disabled.
  /// - Multi-agent marketplace, platform-wide lead distribution, rotation,
  ///   and subscription tier UIs are hidden/disabled.
  /// - Only the designated pilot agent (and system administrators) can access
  ///   the internal dashboard.
  /// - Public visitors can access the designated pilot agent's landing page.
  /// - Buyers do not need accounts to submit enquiries.
  static const bool isSingleAgentPilotMode = true;

  /// Default designated pilot agent ownerId and slug.
  static const String defaultPilotAgentOwnerId = 'demo-agent-001';
  static const String defaultPilotAgentSlug = 'alex-tan-penang';
  static const String defaultPilotAgentEmail = 'agent@propmatch.ai';

  /// Pilot registration invite code required to create an account
  /// when unrestricted registration is disabled.
  static const String pilotRegistrationInviteCode = 'PILOT-MY-2026';

  /// Whether unrestricted public agent registration is allowed.
  /// In private pilot mode, this is false.
  static const bool allowUnrestrictedPublicRegistration = false;

  /// List of authorized administrator/developer emails who can sign in
  /// for maintenance, separate from the agent's account.
  static const Set<String> adminEmails = {
    'admin@propmatch.ai',
    'developer@propmatch.ai',
    'pilot-admin@propmatch.ai',
  };

  /// Whether public agent directory is enabled.
  /// In single-agent pilot mode, this is false to prevent agent comparison.
  static const bool enablePublicAgentDirectory = false;

  /// Whether platform-wide lead distribution (Channel B) is enabled in UI.
  /// In single-agent pilot mode, this is false; all enquiries route directly
  /// to the single pilot agent.
  static const bool enablePlatformLeadDistribution = false;

  /// Whether subscription tiers and payment-related UI are displayed.
  /// In single-agent pilot mode, this is false; pilot agent has full access
  /// without artificial quotas or upgrade paywalls.
  static const bool enableSubscriptionTiersUI = false;

  /// Whether multi-agent switching or comparison is enabled.
  static const bool enableMultiAgentSwitching = false;

  /// Check if an email or user ID is authorized to access the dashboard
  /// in Single-Agent Private Pilot mode.
  static bool isUserAuthorized(String? email, String? uid) {
    if (!isSingleAgentPilotMode) return true;

    final cleanEmail = email?.trim().toLowerCase() ?? '';
    final cleanUid = uid?.trim() ?? '';

    // 1. Administrators / developers have separate maintenance access
    if (adminEmails.contains(cleanEmail)) return true;

    // 2. Default pilot agent / demo agent
    if (cleanEmail == defaultPilotAgentEmail || cleanUid == defaultPilotAgentOwnerId) {
      return true;
    }

    // 3. Known pilot agents in directory
    if (cleanUid.startsWith('agent-') || cleanUid.startsWith('usr-') || cleanUid.startsWith('pilot-')) {
      return true;
    }

    return false;
  }
}
