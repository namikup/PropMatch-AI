import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/stat_card.dart';
import '../projects/property_analysis_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final nav = context.read<NavigationProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Data Transparency & Compliance Notice Banner
          _buildTransparencyBanner(context),
          const SizedBox(height: AppTheme.spacingMd),

          // Project Spotlight Header
          _buildProjectSpotlight(context, appState, nav),
          const SizedBox(height: AppTheme.spacingLg),

          // Overview Statistics Grid
          _buildStatsGrid(context, appState, nav),
          const SizedBox(height: AppTheme.spacingLg),

          // Compact Lead Acquisition Overview
          _buildLeadAcquisitionOverview(context, appState, nav),
          const SizedBox(height: AppTheme.spacingLg),

          // Main 2-Column Desktop Content Section
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 950) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _buildRecentLeadsSection(context, appState, nav)),
                    const SizedBox(width: AppTheme.spacingLg),
                    Expanded(flex: 2, child: _buildAiRecommendationsSection(context, appState, nav)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildRecentLeadsSection(context, appState, nav),
                  const SizedBox(height: AppTheme.spacingLg),
                  _buildAiRecommendationsSection(context, appState, nav),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Data Transparency Notice assuring demo isolation & non-misleading AI claims
  Widget _buildTransparencyBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Text(
                  'PropMatch AI Demo Environment',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'DEMO DATA MODE',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppTheme.warning),
                  ),
                ),
                const Text(
                  '• Fictional buyer profiles are strictly isolated with isDemo: true. AI audience segments are algorithmic marketing hypotheses.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSpotlight(
      BuildContext context, AppStateProvider appState, NavigationProvider nav) {
    final project = appState.selectedProject;
    final pricePerSqft = (project != null && project.builtUpArea > 0)
        ? (project.startingPrice / project.builtUpArea).toStringAsFixed(0)
        : null;

    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          gradient: const LinearGradient(
            colors: [AppTheme.primaryDark, AppTheme.primary, AppTheme.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Text(
                    'ACTIVE FOCUS PROJECT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (project != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${project.state.toUpperCase()} CORRIDOR',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    'Developer: ${project.developer} • Status: ${project.status}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(
              project?.name ?? 'No Project Selected',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Text(
              project != null
                  ? 'Price: RM${project.startingPrice.toStringAsFixed(0)} - RM${project.maximumPrice.toStringAsFixed(0)}'
                      '${pricePerSqft != null ? " (~RM$pricePerSqft/sqft)" : ""} '
                      '| ${project.bedrooms} Beds, ${project.bathrooms} Baths '
                      '| ${project.builtUpArea.toStringAsFixed(0)} sqft '
                      '| Suitability: ${project.purpose}'
                  : 'Select or add a property project to activate AI features.',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            Wrap(
              spacing: AppTheme.spacingMd,
              runSpacing: AppTheme.spacingSm,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    elevation: 0,
                  ),
                  onPressed: () {
                    final project = appState.selectedProject;
                    if (project == null) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PropertyAnalysisScreen(initialProject: project),
                      ),
                    );
                  },
                  icon: const Icon(Icons.psychology, size: 18, color: AppTheme.primary),
                  label: const Text(
                    'AI Property Intelligence',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed: () {
                    nav.navigateTo(NavItem.audienceDiscovery);
                    appState.runAudienceDiscovery();
                  },
                  icon: const Icon(Icons.people, size: 18),
                  label: const Text('Discover AI Audiences'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed: () {
                    nav.navigateTo(NavItem.matching);
                    appState.runBuyerMatching();
                  },
                  icon: const Icon(Icons.compare_arrows, size: 18),
                  label: const Text('Run AI Buyer Matching'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  onPressed: () {
                    nav.navigateTo(NavItem.marketing);
                    appState.generateMarketingContent();
                  },
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Generate Marketing Strategy'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, AppStateProvider appState, NavigationProvider nav) {
    final c1 = StatCard(
      title: 'Total Projects',
      value: '${appState.activeProjectCount}',
      icon: Icons.apartment,
      iconColor: AppTheme.primary,
      subtitle: 'Penang & Kedah Focus',
    );
    final c2 = StatCard(
      title: 'Total Buyers Registered',
      value: '${appState.totalBuyerCount}',
      icon: Icons.person_search,
      iconColor: AppTheme.secondary,
      subtitle: appState.hasGeneratedDemoBuyers
          ? '${appState.demoBuyerCount} Demo Profiles Active'
          : 'Tap to generate 100 demo buyers',
    );
    final c3 = StatCard(
      title: 'Qualified Leads',
      value: '${appState.qualifiedLeadCount}',
      icon: Icons.leaderboard,
      iconColor: AppTheme.accent,
      subtitle: '${appState.leads.length} in pipeline (${appState.pipelineConversionRate.toStringAsFixed(0)}% conv)',
    );
    final c4 = StatCard(
      title: 'Avg Match Rate',
      value: appState.matches.isNotEmpty
          ? '${appState.averageMatchRate.toStringAsFixed(1)}%'
          : 'Not Calculated',
      icon: Icons.compare_arrows,
      iconColor: AppTheme.info,
      subtitle: appState.matches.isNotEmpty
          ? '${appState.matches.length} candidates evaluated'
          : 'Run matching to calculate',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 950) {
          return Row(
            children: [
              Expanded(child: c1),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(child: c2),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(child: c3),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(child: c4),
            ],
          );
        } else if (constraints.maxWidth >= 550) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: c1),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(child: c2),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Row(
                children: [
                  Expanded(child: c3),
                  const SizedBox(width: AppTheme.spacingMd),
                  Expanded(child: c4),
                ],
              ),
            ],
          );
        } else {
          return Column(
            children: [
              c1,
              const SizedBox(height: AppTheme.spacingMd),
              c2,
              const SizedBox(height: AppTheme.spacingMd),
              c3,
              const SizedBox(height: AppTheme.spacingMd),
              c4,
            ],
          );
        }
      },
    );
  }

  /// Compact Lead Acquisition Overview Card
  Widget _buildLeadAcquisitionOverview(
      BuildContext context, AppStateProvider appState, NavigationProvider nav) {
    final sources = appState.leadsBySource;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        ),
                        child: const Icon(Icons.insights, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: AppTheme.spacingMd),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lead Acquisition Overview',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Voluntary buyer enquiry capture channels & conversion health (Malaysian Northern Corridor)',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => nav.navigateTo(NavItem.analytics),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Acquisition Analytics'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            const Divider(height: 1),
            const SizedBox(height: AppTheme.spacingMd),

            // Channel Badges & Pipeline Stage Distribution
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                _buildChannelChip(
                  icon: Icons.chat,
                  channel: 'WhatsApp Enquiry Links',
                  count: sources['WhatsApp Enquiry'] ?? 0,
                  color: AppTheme.success,
                ),
                _buildChannelChip(
                  icon: Icons.campaign,
                  channel: 'Facebook & IG Lead Ads',
                  count: sources['Facebook Ads'] ?? 0,
                  color: AppTheme.primaryLight,
                ),
                _buildChannelChip(
                  icon: Icons.search,
                  channel: 'Google Search Demand',
                  count: sources['Google Search'] ?? 0,
                  color: AppTheme.info,
                ),
                _buildChannelChip(
                  icon: Icons.share,
                  channel: 'Direct Referral Network',
                  count: sources['Referral'] ?? 0,
                  color: AppTheme.accent,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Mini Funnel Health Summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildFunnelItem('Awaiting Follow-up / Viewing', '${appState.awaitingFollowupCount}', AppTheme.accent),
                  _buildFunnelItem('Qualified Buyers', '${appState.qualifiedLeadCount}', AppTheme.success),
                  _buildFunnelItem('Pipeline Conversion Rate', '${appState.pipelineConversionRate.toStringAsFixed(0)}%', AppTheme.primary),
                  _buildFunnelItem('Data Segregation', '${appState.demoLeadCount} Demo / ${appState.genuineLeadCount} Real', AppTheme.textSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelChip({
    required IconData icon,
    required String channel,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(channel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunnelItem(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildRecentLeadsSection(
      BuildContext context, AppStateProvider appState, NavigationProvider nav) {
    return Card(
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
                      Text(
                        'High-Priority Leads & Enquiries',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Prospective buyers awaiting response or viewing schedules',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                TextButton.icon(
                  onPressed: () => nav.navigateTo(NavItem.leads),
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View All Leads'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLg),
            if (appState.leads.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingXl),
                alignment: Alignment.center,
                child: const Text('No active leads recorded yet.'),
              ),
            ] else ...[
              // Desktop responsive Table
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.5),
                  1: FlexColumnWidth(2),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.5),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
                    ),
                    children: [
                      _buildTableHeader('Buyer & Channel'),
                      _buildTableHeader('Target Project'),
                      _buildTableHeader('Pipeline Stage'),
                      _buildTableHeader('Est. Deal Value'),
                    ],
                  ),
                  ...appState.leads.take(4).map((lead) {
                    return TableRow(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      lead.buyerName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (lead.isDemo) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warning.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: const Text(
                                        'DEMO',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.warning,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(lead.source, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(lead.projectName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _buildStatusBadge(lead.status),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            lead.dealValue > 0 ? 'RM${lead.dealValue.toStringAsFixed(0)}' : 'TBD',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppTheme.primary;
    if (status == 'Qualified' || status == 'Won') color = AppTheme.success;
    if (status == 'Contacted') color = AppTheme.info;
    if (status == 'Negotiating') color = AppTheme.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Dynamic, contextual AI recommendations with clear "why" rationales
  Widget _buildAiRecommendationsSection(
      BuildContext context, AppStateProvider appState, NavigationProvider nav) {
    final project = appState.selectedProject;
    final hasAudiences = appState.audienceSegments.isNotEmpty;
    final hasMatches = appState.matches.isNotEmpty;
    final topAudience = hasAudiences ? appState.audienceSegments.first : null;
    final topMatch = hasMatches ? appState.matches.first : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 20),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contextual AI Recommendations',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        project != null
                            ? 'Tailored to ${project.name} (${project.location})'
                            : 'Select a project to generate recommendations',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Recommendation 1: Audience Discovery or Campaign Action
            if (!hasAudiences) ...[
              _buildRecTile(
                context: context,
                icon: Icons.people,
                title: 'Discover Audiences for ${project?.name ?? "Project"}',
                subtitle: 'Evaluates demographic clusters and purchase motivators for ${project?.propertyType ?? "properties"} in ${project?.location ?? "Penang"}.',
                whyText: 'WHY: Pinpoints highest-conversion target segments before investing in paid media.',
                actionText: 'Run AI Discovery',
                color: AppTheme.primary,
                onTap: () {
                  nav.navigateTo(NavItem.audienceDiscovery);
                  appState.runAudienceDiscovery();
                },
              ),
            ] else ...[
              _buildRecTile(
                context: context,
                icon: Icons.campaign,
                title: 'Campaign: Target ${topAudience!.name}',
                subtitle: 'Top-ranked segment (${topAudience.suitabilityScore.toStringAsFixed(0)}% suitability) ready for ad messaging.',
                whyText: 'WHY: High budget alignment (${topAudience.budgetCompatibility}) matches project price range.',
                actionText: 'Generate Ad Copy',
                color: AppTheme.accent,
                onTap: () {
                  nav.navigateTo(NavItem.marketing);
                  appState.generateMarketingContent();
                },
              ),
            ],

            const Divider(height: 24),

            // Recommendation 2: Buyer Matching or Follow-up Action
            if (!hasMatches) ...[
              _buildRecTile(
                context: context,
                icon: Icons.compare_arrows,
                title: 'Match Registered Buyers with ${project?.name ?? "Project"}',
                subtitle: 'Calculates 5-factor weighted scores (budget, location, type, purpose, timeline).',
                whyText: 'WHY: Surfaces instant high-intent matches from your database to accelerate deal closing.',
                actionText: 'Evaluate Matches',
                color: AppTheme.info,
                onTap: () {
                  nav.navigateTo(NavItem.matching);
                  appState.runBuyerMatching();
                },
              ),
            ] else ...[
              _buildRecTile(
                context: context,
                icon: Icons.person,
                title: 'Follow Up: ${topMatch!.buyerName} (${topMatch.overallMatchPercentage.toStringAsFixed(0)}% Match)',
                subtitle: 'Prime candidate for ${project?.name ?? "Project"}. Location & budget strongly aligned.',
                whyText: 'WHY: Top match score in database. Schedule viewing or consultation via WhatsApp.',
                actionText: 'Inspect Candidate',
                color: AppTheme.success,
                onTap: () {
                  nav.navigateTo(NavItem.matching);
                  appState.selectMatch(topMatch);
                },
              ),
            ],

            const Divider(height: 24),

            // Recommendation 3: Demo Data Generation or Refresh
            _buildRecTile(
              context: context,
              icon: Icons.person_search,
              title: appState.hasGeneratedDemoBuyers
                  ? 'Refresh 100 Demo Buyer Profiles'
                  : 'Generate 100 Demo Buyers',
              subtitle: 'Populate or refresh synthetic Malaysian buyer profiles with realistic Penang/Kedah parameters.',
              whyText: 'WHY: Benchmark the rule-based AI matching engine across diverse budget tiers.',
              actionText: appState.hasGeneratedDemoBuyers ? 'Regenerate Profiles' : 'Generate Now',
              color: AppTheme.secondary,
              onTap: () {
                appState.generate100DemoBuyers();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generated 100 Fictional Demo Buyer Profiles!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String whyText,
    required String actionText,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  whyText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: onTap,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionText,
                      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 14, color: color),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
