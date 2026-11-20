import 'package:flutter/material.dart';
import '../config/constants.dart';

enum NavItem {
  dashboard,
  projects,
  audienceDiscovery,
  buyerIntelligence,
  buyers,
  leads,
  matching,
  marketing,
  campaigns,
  followups,
  analytics,
  settings,
}

class NavItemData {
  final NavItem item;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const NavItemData({
    required this.item,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

const List<NavItemData> navItems = [
  NavItemData(
    item: NavItem.dashboard,
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
  ),
  NavItemData(
    item: NavItem.projects,
    label: 'Projects',
    icon: Icons.apartment_outlined,
    activeIcon: Icons.apartment,
  ),
  NavItemData(
    item: NavItem.audienceDiscovery,
    label: 'AI Audience',
    icon: Icons.people_outline,
    activeIcon: Icons.people,
  ),
  NavItemData(
    item: NavItem.buyerIntelligence,
    label: 'Buyer Intelligence',
    icon: Icons.hub_outlined,
    activeIcon: Icons.hub,
  ),
  NavItemData(
    item: NavItem.buyers,
    label: 'Buyers',
    icon: Icons.person_search_outlined,
    activeIcon: Icons.person_search,
  ),
  NavItemData(
    item: NavItem.leads,
    label: 'Leads',
    icon: Icons.leaderboard_outlined,
    activeIcon: Icons.leaderboard,
  ),
  NavItemData(
    item: NavItem.matching,
    label: 'AI Matching',
    icon: Icons.compare_arrows_outlined,
    activeIcon: Icons.compare_arrows,
  ),
  NavItemData(
    item: NavItem.marketing,
    label: 'Marketing AI',
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome,
  ),
  NavItemData(
    item: NavItem.campaigns,
    label: 'Campaigns',
    icon: Icons.campaign_outlined,
    activeIcon: Icons.campaign,
  ),
  NavItemData(
    item: NavItem.followups,
    label: 'Follow-ups',
    icon: Icons.event_note_outlined,
    activeIcon: Icons.event_note,
  ),
  NavItemData(
    item: NavItem.analytics,
    label: 'Analytics',
    icon: Icons.analytics_outlined,
    activeIcon: Icons.analytics,
  ),
  NavItemData(
    item: NavItem.settings,
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
  ),
];

class NavigationProvider extends ChangeNotifier {
  NavItem _currentItem = NavItem.dashboard;
  bool _sidebarCollapsed = false;

  NavItem get currentItem => _currentItem;
  bool get sidebarCollapsed => _sidebarCollapsed;

  void navigateTo(NavItem item) {
    if (_currentItem != item) {
      _currentItem = item;
      notifyListeners();
    }
  }

  void toggleSidebar() {
    _sidebarCollapsed = !_sidebarCollapsed;
    notifyListeners();
  }

  void setSidebarCollapsed(bool collapsed) {
    if (_sidebarCollapsed != collapsed) {
      _sidebarCollapsed = collapsed;
      notifyListeners();
    }
  }

  bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < AppConstants.tabletBreakpoint;
  }

  bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= AppConstants.desktopBreakpoint;
  }
}
