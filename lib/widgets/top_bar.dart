import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/navigation_provider.dart';
import '../providers/app_state_provider.dart';

class TopBar extends StatelessWidget {
  final VoidCallback? onLogout;

  const TopBar({super.key, this.onLogout});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();
    final appState = context.watch<AppStateProvider>();
    final currentNav = navItems.firstWhere(
      (item) => item.item == nav.currentItem,
    );
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.cardBorder),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
      child: Row(
        children: [
          // Hamburger menu for compact view
          if (isCompact) ...[
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Toggle Navigation',
            ),
            const SizedBox(width: AppTheme.spacingSm),
          ],

          // Page title & subtitle
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentNav.label,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (appState.selectedProject != null && !isCompact) ...[
                  Text(
                    'Active Project: ${appState.selectedProject!.name} (${appState.selectedProject!.location}, ${appState.selectedProject!.state})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacingMd),

          // Project quick switcher dropdown for desktop web
          if (!isCompact && appState.projects.isNotEmpty) ...[
            Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: appState.selectedProject?.id,
                  icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                  hint: const Text('Select Property Project'),
                  isDense: true,
                  isExpanded: true,
                  items: appState.projects.map((proj) {
                    return DropdownMenuItem<String>(
                      value: proj.id,
                      child: Text(
                        '${proj.name} (${proj.state})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (id) {
                    if (id != null) {
                      final selected = appState.projects.firstWhere((p) => p.id == id);
                      appState.selectProject(selected);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacingMd),
          ],

          // Notification action
          IconButton(
            icon: const Badge(
              smallSize: 8,
              backgroundColor: AppTheme.accent,
              child: Icon(Icons.notifications_none, size: 22),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Simulated Notifications: No pending alerts.')),
              );
            },
            tooltip: 'Notifications',
          ),

          const SizedBox(width: AppTheme.spacingSm),

          // User avatar & Agent Profile
          PopupMenuButton<String>(
            offset: const Offset(0, 52),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    'MA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isCompact) ...[
                  const SizedBox(width: AppTheme.spacingSm),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Malaysian Agent',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        'PENANG & KEDAH REGION',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: AppTheme.textHint,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppTheme.spacingXs),
                  const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.textSecondary),
                ],
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Agent Settings'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: AppTheme.error),
                  title: Text('Sign Out', style: TextStyle(color: AppTheme.error)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'settings') {
                nav.navigateTo(NavItem.settings);
              } else if (value == 'logout') {
                if (onLogout != null) {
                  onLogout!();
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
