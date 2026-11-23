import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/navigation_provider.dart';
import 'providers/app_state_provider.dart';
import 'widgets/sidebar_navigation.dart';
import 'widgets/top_bar.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/projects/projects_screen.dart';
import 'screens/audience/audience_discovery_screen.dart';
import 'screens/prospects/buyer_intelligence_screen.dart';
import 'screens/buyers/buyers_screen.dart';
import 'screens/leads/leads_screen.dart';
import 'screens/matching/matching_screen.dart';
import 'screens/marketing/marketing_screen.dart';
import 'screens/campaigns/campaigns_screen.dart';
import 'screens/followups/followups_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/landing/agent_landing_page_screen.dart';
import 'screens/landing/agent_not_found_screen.dart';
import 'services/agent_directory_service.dart';
import 'config/pilot_config.dart';

class PropMatchApp extends StatelessWidget {
  final bool isFirebaseConnected;

  const PropMatchApp({super.key, this.isFirebaseConnected = false});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(
          create: (_) => isFirebaseConnected
              ? AppStateProvider.firebase()
              : AppStateProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'PropMatch AI — Malaysian Property Lead Discovery & Matching',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '/');
          final pathSegments = uri.pathSegments;

          // Check if accessing public agent landing page route: /agent/:slugOrId
          if (pathSegments.isNotEmpty && pathSegments.first == 'agent') {
            final slugOrId = pathSegments.length > 1 ? pathSegments[1] : '';
            final queryParams = uri.queryParameters;

            return MaterialPageRoute(
              settings: settings,
              builder: (context) {
                final appState = context.watch<AppStateProvider>();
                final agent = AgentDirectoryService.findAgent(slugOrId) ??
                    (appState.currentUserProfile?.landingPageSlug == slugOrId ||
                            appState.currentUserProfile?.ownerId == slugOrId
                        ? appState.currentUserProfile
                        : null) ??
                    (PilotConfig.isSingleAgentPilotMode && slugOrId.isEmpty
                        ? AgentDirectoryService.getDesignatedPilotAgent()
                        : null);

                if (agent == null) {
                  return AgentNotFoundScreen(
                    requestedSlug: slugOrId,
                    onReturnHome: () {
                      Navigator.of(context).pushReplacementNamed('/');
                    },
                  );
                }

                final featuredProjects =
                    AgentDirectoryService.getFeaturedProjectsForAgent(
                  agent,
                  availableProjects: appState.projects,
                );

                return AgentLandingPageScreen(
                  agent: agent,
                  featuredProjects: featuredProjects.isNotEmpty
                      ? featuredProjects
                      : appState.projects,
                  campaignId: queryParams['campaign_id'] ?? queryParams['campaignId'],
                  utmSource: queryParams['utm_source'] ?? queryParams['utmSource'],
                  utmMedium: queryParams['utm_medium'] ?? queryParams['utmMedium'],
                  utmCampaign: queryParams['utm_campaign'] ?? queryParams['utmCampaign'],
                  referralSource: queryParams['ref'] ?? queryParams['referral'],
                  onBackToApp: () {
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                );
              },
            );
          }

          // Default entry point for authenticated app
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const AppEntry(),
          );
        },
      ),
    );
  }
}

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final currentUser = appState.authRepository.currentUser;

    if (currentUser == null) {
      return LoginScreen(
        onLoginSuccess: () {
          // Handled reactively by AppStateProvider's authStateChanges listener
        },
      );
    }

    return AppShell(
      onLogout: () async {
        await appState.authRepository.signOut();
      },
    );
  }
}

class AppShell extends StatelessWidget {
  final VoidCallback? onLogout;

  const AppShell({super.key, this.onLogout});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 900;

    return Scaffold(
      drawer: isCompact
          ? Drawer(
              backgroundColor: AppTheme.sidebarBg,
              width: AppTheme.sidebarWidth,
              child: const SafeArea(child: SidebarNavigation()),
            )
          : null,
      body: Row(
        children: [
          // Desktop SaaS Sidebar
          if (!isCompact) const SidebarNavigation(),

          // Main Web Application Content Canvas
          Expanded(
            child: Column(
              children: [
                TopBar(onLogout: onLogout),
                Expanded(
                  child: Container(
                    color: AppTheme.background,
                    child: _buildCurrentScreen(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen(BuildContext context) {
    final nav = context.watch<NavigationProvider>();

    switch (nav.currentItem) {
      case NavItem.dashboard:
        return const DashboardScreen();
      case NavItem.projects:
        return const ProjectsScreen();
      case NavItem.audienceDiscovery:
        return const AudienceDiscoveryScreen();
      case NavItem.buyerIntelligence:
        return const BuyerIntelligenceScreen();
      case NavItem.buyers:
        return const BuyersScreen();
      case NavItem.leads:
        return const LeadsScreen();
      case NavItem.matching:
        return const MatchingScreen();
      case NavItem.marketing:
        return const MarketingScreen();
      case NavItem.campaigns:
        return const CampaignsScreen();
      case NavItem.followups:
        return const FollowupsScreen();
      case NavItem.analytics:
        return const AnalyticsScreen();
      case NavItem.settings:
        return const SettingsScreen();
    }
  }
}
