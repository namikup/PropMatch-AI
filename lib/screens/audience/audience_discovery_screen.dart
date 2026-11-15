import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/audience_segment_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/navigation_provider.dart';

class AudienceDiscoveryScreen extends StatelessWidget {
  const AudienceDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final nav = context.read<NavigationProvider>();
    final selectedProject = appState.selectedProject;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner / Control Bar
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
                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                                  ),
                                  child: const Icon(Icons.people_alt, color: AppTheme.primary, size: 24),
                                ),
                                const SizedBox(width: AppTheme.spacingMd),
                                Expanded(
                                  child: Text(
                                    'AI Audience Discovery Engine',
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
                            Text(
                              'Analyze any property project against regional demographic drivers in Malaysia to discover high-propensity buyer segments.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMd),

                      // Trigger Discovery Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        onPressed: appState.isDiscoveringAudience || selectedProject == null
                            ? null
                            : () => appState.runAudienceDiscovery(),
                        icon: appState.isDiscoveringAudience
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          appState.isDiscoveringAudience
                              ? 'Analyzing Demographics...'
                              : 'Run AI Audience Analysis',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingLg),

                  // Project selector and active project metadata
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.apartment, color: AppTheme.primary, size: 20),
                        const SizedBox(width: AppTheme.spacingSm),
                        const Text('Target Project: ', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedProject?.id,
                              isExpanded: true,
                              hint: const Text('Choose Project'),
                              items: appState.projects.map((p) {
                                return DropdownMenuItem(
                                  value: p.id,
                                  child: Text('${p.name} (${p.location}, ${p.state})', overflow: TextOverflow.ellipsis),
                                );
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
                        if (selectedProject != null) ...[
                          const SizedBox(width: AppTheme.spacingMd),
                          Text(
                            'RM${selectedProject.startingPrice.toStringAsFixed(0)} • ${selectedProject.bedrooms}BR',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Mandatory Disclaimer Alert
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppTheme.info, size: 20),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Text(
                    'IMPORTANT NOTICE: These are AI-generated marketing hypotheses and strategic segmentation models, '
                    'NOT verified buyers or real market statistics. Use them to guide targeted ad creative, campaign angles, and consultative sales approaches.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingXl),

          // Audience Segments List
          if (appState.isDiscoveringAudience) ...[
            Container(
              padding: const EdgeInsets.all(60),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI Engine is evaluating income cohorts, commute patterns & demographic drivers...'),
                ],
              ),
            ),
          ] else if (appState.audienceSegments.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXxl),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.psychology_outlined, size: 56, color: AppTheme.textHint),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'No Audience Analysis Generated Yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Click "Run AI Audience Analysis" above to evaluate target demographics for this project.'),
                  const SizedBox(height: AppTheme.spacingLg),
                  ElevatedButton.icon(
                    onPressed: () => appState.runAudienceDiscovery(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Discover Audiences Now'),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Ranked Segments Header
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'Identified Audience Segments (${appState.audienceSegments.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Text('• Ranked by estimated demographic & budget suitability', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Segment cards
            ...appState.audienceSegments.map((segment) {
              return _buildAudienceCard(context, segment, appState, nav);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildAudienceCard(
    BuildContext context,
    AudienceSegmentModel segment,
    AppStateProvider appState,
    NavigationProvider nav,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingLg),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Rank badge, Segment Name, Suitability Score
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#${segment.rank}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            segment.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${segment.suitabilityScore.toStringAsFixed(0)}% SUITABILITY',
                              style: const TextStyle(
                                color: AppTheme.secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        segment.description,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Action: Use in Marketing Assistant
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onPressed: () {
                    appState.selectAudienceForMarketing(segment);
                    nav.navigateTo(NavItem.marketing);
                    appState.generateMarketingContent(audience: segment);
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Create Marketing Strategy'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLg),
            const Divider(),
            const SizedBox(height: AppTheme.spacingMd),

            // 2-Column Info Grid for Web
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 800;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailSection(
                            title: '💡 Why They Are Interested',
                            content: segment.interestReason,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailSection(
                            title: '💰 Estimated Budget Compatibility',
                            content: segment.budgetCompatibility,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailSection(
                            title: '🏠 Property & Layout Preferences',
                            content: segment.propertyPreferences,
                          ),
                          const SizedBox(height: 12),
                          _buildDetailSection(
                            title: '🎯 AI Ranking Rationale',
                            content: segment.reasoning,
                          ),
                        ],
                      ),
                    ),
                    if (isWide) const SizedBox(width: AppTheme.spacingXl),

                    // Right Column
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Objections
                          const Text(
                            '⚠️ Anticipated Buyer Objections',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          ...segment.potentialObjections.map((obj) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                                    Expanded(child: Text(obj, style: const TextStyle(fontSize: 12))),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 12),

                          // Recommended Messages
                          const Text(
                            '📢 Recommended Marketing Messages',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          ...segment.recommendedMarketingMessages.map((msg) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.background,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppTheme.cardBorder),
                                  ),
                                  child: Text(msg, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                ),
                              )),
                          const SizedBox(height: 12),

                          // Channels & CTA
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('📱 Target Channels', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: segment.recommendedChannels.map((c) => Chip(
                                        label: Text(c, style: const TextStyle(fontSize: 10)),
                                        padding: EdgeInsets.zero,
                                      )).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('🎯 Suggested CTA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(
                                      segment.suggestedCallToAction,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
      ],
    );
  }
}
