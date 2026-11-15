import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/navigation_provider.dart';

class SidebarNavigation extends StatelessWidget {
  const SidebarNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();
    final collapsed = nav.sidebarCollapsed;
    final width = collapsed ? AppTheme.sidebarCollapsedWidth : AppTheme.sidebarWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: width,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBg,
      ),
      child: Column(
        children: [
          // Logo / Brand header
          _buildHeader(context, collapsed),
          const Divider(color: Colors.white12, height: 1),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSm),
              children: navItems.map((item) {
                return _buildNavItem(context, item, collapsed);
              }).toList(),
            ),
          ),

          // Collapse toggle
          const Divider(color: Colors.white12, height: 1),
          _buildCollapseButton(context, collapsed),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool collapsed) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? AppTheme.spacingSm : AppTheme.spacingMd,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.accent, AppTheme.accentLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: const Icon(
              Icons.real_estate_agent,
              color: Colors.white,
              size: 20,
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    AppConstants.appTagline,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.sidebarText,
                          fontSize: 10,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, NavItemData item, bool collapsed) {
    final nav = context.read<NavigationProvider>();
    final isActive = nav.currentItem == item.item;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? AppTheme.spacingXs : AppTheme.spacingSm,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          onTap: () {
            nav.navigateTo(item.item);
            // Close drawer on mobile
            if (nav.isMobile(context)) {
              Navigator.of(context).maybePop();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? AppTheme.spacingSm : AppTheme.spacingMd,
              vertical: AppTheme.spacingSm + 2,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.sidebarActive
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive
                      ? AppTheme.sidebarActiveText
                      : AppTheme.sidebarText,
                  size: 22,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isActive
                                ? AppTheme.sidebarActiveText
                                : AppTheme.sidebarText,
                            fontWeight:
                                isActive ? FontWeight.w600 : FontWeight.w400,
                            fontSize: 14,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseButton(BuildContext context, bool collapsed) {
    return InkWell(
      onTap: () => context.read<NavigationProvider>().toggleSidebar(),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        child: Icon(
          collapsed ? Icons.chevron_right : Icons.chevron_left,
          color: AppTheme.sidebarText,
          size: 20,
        ),
      ),
    );
  }
}
