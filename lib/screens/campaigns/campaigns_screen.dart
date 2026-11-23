import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/navigation_provider.dart';
import 'meta_ads_intelligence_screen.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});

  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  int _selectedTab = 0; // 0 = Meta Ads Intelligence, 1 = Multi-Channel Creatives

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final nav = context.read<NavigationProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedTab == 0
                          ? 'Meta Ads Intelligence'
                          : 'Multi-Channel Campaigns',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedTab == 0
                          ? 'Track Meta Ads expenditure, Instant Form leads, and correlate spend directly with qualified buyer conversions.'
                          : 'Track ad creative performance across Facebook, Instagram, TikTok and WhatsApp broadcast campaigns.',
                      style: const TextStyle(color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              ElevatedButton.icon(
                onPressed: () => nav.navigateTo(NavItem.marketing),
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Create New via Marketing AI'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Tab Selector Bar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tabButton(
                  index: 0,
                  label: 'Meta Ads Intelligence',
                  icon: Icons.insights_outlined,
                  activeIcon: Icons.insights,
                ),
                const SizedBox(width: 4),
                _tabButton(
                  index: 1,
                  label: 'Multi-Channel Creatives',
                  icon: Icons.campaign_outlined,
                  activeIcon: Icons.campaign,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Tab Content
          if (_selectedTab == 0)
            MetaAdsIntelligenceScreen(ownerId: appState.currentOwnerId)
          else
            _buildMultiChannelView(context, appState, nav),
        ],
      ),
    );
  }

  Widget _tabButton({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiChannelView(BuildContext context, AppStateProvider appState, NavigationProvider nav) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

          // Overview Stats
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 900 ? 3 : 1;
              final totalReach = appState.campaigns.fold(0, (sum, c) => sum + c.reach);
              final totalClicks = appState.campaigns.fold(0, (sum, c) => sum + c.clicks);
              final totalEnquiries = appState.campaigns.fold(0, (sum, c) => sum + c.enquiries);

              return GridView.count(
                crossAxisCount: count,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppTheme.spacingMd,
                mainAxisSpacing: AppTheme.spacingMd,
                childAspectRatio: count == 1 ? 3.0 : 2.0,
                children: [
                  _statItem(context, 'Total Estimated Reach', '$totalReach', Icons.remove_red_eye_outlined, AppTheme.primary),
                  _statItem(context, 'Ad Clicks / Engagements', '$totalClicks', Icons.touch_app_outlined, AppTheme.secondary),
                  _statItem(context, 'Generated Enquiries', '$totalEnquiries', Icons.chat_outlined, AppTheme.accent),
                ],
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Campaigns List
          if (appState.campaigns.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(60),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.campaign_outlined, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text('No Active Campaigns Yet', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Go to Marketing AI Assistant to generate and launch your first targeted property campaign.'),
                  const SizedBox(height: AppTheme.spacingLg),
                  ElevatedButton.icon(
                    onPressed: () => nav.navigateTo(NavItem.marketing),
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Launch a Campaign'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: appState.campaigns.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 24),
                  itemBuilder: (ctx, i) {
                    final camp = appState.campaigns[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    camp.platform.toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.primary),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(camp.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                camp.status,
                                style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Project: ${camp.projectName} • Audience: ${camp.audienceSegmentName.isNotEmpty ? camp.audienceSegmentName : "All"}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            camp.contentHeadline,
                            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _metricChip('Reach: ${camp.reach}'),
                            const SizedBox(width: 12),
                            _metricChip('Clicks: ${camp.clicks}'),
                            const SizedBox(width: 12),
                            _metricChip('Enquiries: ${camp.enquiries}'),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      );
  }

  Widget _statItem(BuildContext context, String title, String val, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              radius: 20,
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
