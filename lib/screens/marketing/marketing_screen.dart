import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/audience_segment_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/navigation_provider.dart';

class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final nav = context.read<NavigationProvider>();
    final selectedProject = appState.selectedProject;
    final content = appState.generatedMarketingContent;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Controls Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  ),
                                  child: const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 24),
                                ),
                                const SizedBox(width: AppTheme.spacingMd),
                                Expanded(
                                  child: Text(
                                    'Marketing AI Assistant',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Generate tailored property marketing creative for Facebook, Instagram, TikTok, and WhatsApp.',
                              style: TextStyle(color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMd),

                      // Generate button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: appState.isGeneratingMarketing || selectedProject == null
                            ? null
                            : () => appState.generateMarketingContent(),
                        icon: appState.isGeneratingMarketing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          appState.isGeneratingMarketing
                              ? 'Drafting Creative...'
                              : 'Generate Marketing Collateral',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),

                  // Selectors row
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        // Project Selector
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.apartment, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              const Text('Project: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedProject?.id,
                                    isExpanded: true,
                                    hint: const Text('Select Project'),
                                    items: appState.projects.map((p) {
                                      return DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis));
                                    }).toList(),
                                    onChanged: (id) {
                                      if (id != null) {
                                        final p = appState.projects.firstWhere((proj) => proj.id == id);
                                        appState.selectProject(p);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingLg),

                        // Audience Segment Selector
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.people_outline, size: 18, color: AppTheme.secondary),
                              const SizedBox(width: 8),
                              const Text('Audience: ', style: TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<AudienceSegmentModel?>(
                                    value: appState.selectedAudienceForMarketing,
                                    isExpanded: true,
                                    hint: const Text('General Property Seekers'),
                                    items: [
                                      const DropdownMenuItem<AudienceSegmentModel?>(
                                        value: null,
                                        child: Text('General Property Seekers', overflow: TextOverflow.ellipsis),
                                      ),
                                      ...appState.audienceSegments.map((seg) {
                                        return DropdownMenuItem<AudienceSegmentModel?>(
                                          value: seg,
                                          child: Text('${seg.name} (#${seg.rank})', overflow: TextOverflow.ellipsis),
                                        );
                                      }),
                                    ],
                                    onChanged: (seg) => appState.selectAudienceForMarketing(seg),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Generated Content Section
          if (appState.isGeneratingMarketing) ...[
            Container(
              padding: const EdgeInsets.all(60),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  CircularProgressIndicator(color: AppTheme.accent),
                  SizedBox(height: 16),
                  Text('AI is crafting persuasive marketing messages, hashtags, hooks and CTAs...'),
                ],
              ),
            ),
          ] else if (content == null) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXxl),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.auto_awesome_outlined, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text('No Marketing Content Generated', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Select your project and audience segment, then click "Generate Marketing Collateral".'),
                  const SizedBox(height: AppTheme.spacingLg),
                  ElevatedButton.icon(
                    onPressed: () => appState.generateMarketingContent(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Generate Content Now'),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Headline Highlight Banner
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.white, size: 28),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PRIMARY AD HEADLINE',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          content.headline,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white),
                    tooltip: 'Copy Headline',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: content.headline));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied headline to clipboard!')));
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Tabs for multi-channel copy
            Card(
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primary,
                    indicatorColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textSecondary,
                    tabs: const [
                      Tab(icon: Icon(Icons.facebook), text: 'Facebook Ad Copy'),
                      Tab(icon: Icon(Icons.photo_camera_outlined), text: 'Instagram Caption'),
                      Tab(icon: Icon(Icons.video_library_outlined), text: 'TikTok Video Script'),
                      Tab(icon: Icon(Icons.chat_outlined), text: 'WhatsApp Script'),
                      Tab(icon: Icon(Icons.lightbulb_outline), text: 'Campaign Strategy'),
                    ],
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 450,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCopyTab(context, 'Facebook Ad Copy', content.facebookPost, 'Facebook', appState, nav),
                        _buildCopyTab(context, 'Instagram Caption', content.instagramCaption, 'Instagram', appState, nav),
                        _buildCopyTab(context, 'TikTok Video Script & Hook', content.tikTokScript, 'TikTok', appState, nav),
                        _buildCopyTab(context, 'WhatsApp Direct Message', content.whatsAppMessage, 'WhatsApp', appState, nav),
                        _buildCopyTab(context, 'Campaign Strategy & Concept', content.campaignConcept, 'Multi-Channel', appState, nav),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCopyTab(
    BuildContext context,
    String label,
    String text,
    String platform,
    AppStateProvider appState,
    NavigationProvider nav,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $label to clipboard!')));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Text'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
                    onPressed: () {
                      appState.createCampaign(
                        name: '${appState.selectedProject?.name ?? "Project"} - $platform Blast',
                        platform: platform,
                        headline: appState.generatedMarketingContent?.headline ?? '',
                        body: text,
                        callToAction: appState.generatedMarketingContent?.callToAction ?? 'Learn More',
                      );
                      nav.navigateTo(NavItem.campaigns);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Created active campaign in Campaigns tab!'), backgroundColor: AppTheme.success),
                      );
                    },
                    icon: const Icon(Icons.rocket_launch, size: 16),
                    label: const Text('Launch Campaign'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
