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
import 'screens/buyers/buyers_screen.dart';
import 'screens/leads/leads_screen.dart';
import 'screens/matching/matching_screen.dart';
import 'screens/marketing/marketing_screen.dart';
import 'screens/campaigns/campaigns_screen.dart';
import 'screens/followups/followups_screen.dart';
import 'screens/analytics/analytics_screen.dart';
import 'screens/settings/settings_screen.dart';

class PropMatchApp extends StatelessWidget {
  const PropMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: MaterialApp(
        title: 'PropMatch AI — Malaysian Property Lead Discovery & Matching',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AppEntry(),
      ),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> {
  bool _isLoggedIn = true; // Default to true in development for immediate web dashboard access

  void _onLoginSuccess() {
    setState(() => _isLoggedIn = true);
  }

  void _onLogout() {
    setState(() => _isLoggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoggedIn) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }
    return AppShell(onLogout: _onLogout);
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
