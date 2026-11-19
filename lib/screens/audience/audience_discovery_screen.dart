import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/audience_segment_model.dart';
import '../../models/project_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/navigation_provider.dart';

class AudienceDiscoveryScreen extends StatefulWidget {
  const AudienceDiscoveryScreen({super.key});

  @override
  State<AudienceDiscoveryScreen> createState() => _AudienceDiscoveryScreenState();
}

class _AudienceDiscoveryScreenState extends State<AudienceDiscoveryScreen> {
  // Track expanded segment cards for deep-dive (marketing generator & geo strategy)
  final Set<String> _expandedSegmentIds = {};
  // Track active marketing tab per segment: 0 = Facebook, 1 = Instagram, 2 = TikTok, 3 = Headlines, 4 = CTAs
  final Map<String, int> _marketingActiveTabs = {};
  // Active top-level subview: 0 = Audience Segments, 1 = Geographic Strategy Analysis
  int _activeViewIndex = 0;

  void _toggleExpanded(String segmentId) {
    setState(() {
      if (_expandedSegmentIds.contains(segmentId)) {
        _expandedSegmentIds.remove(segmentId);
      } else {
        _expandedSegmentIds.add(segmentId);
      }
    });
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

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
          _buildControlHeader(context, appState, selectedProject),
          const SizedBox(height: AppTheme.spacingMd),

          // AI Provenance & Engine Status Banner
          _buildEngineStatusBadge(context, appState),
          const SizedBox(height: AppTheme.spacingMd),

          // Mandatory Disclaimer Alert
          _buildTransparencyBanner(context),
          const SizedBox(height: AppTheme.spacingLg),

          // Project Context Overview Card
          if (selectedProject != null) ...[
            _buildProjectContextCard(context, selectedProject),
            const SizedBox(height: AppTheme.spacingXl),
          ],

          // View Selector & Status
          if (appState.audienceSegments.isNotEmpty) ...[
            _buildViewSelector(context, appState),
            const SizedBox(height: AppTheme.spacingLg),
          ],

          // Body State Handler
          if (appState.isDiscoveringAudience) ...[
            _buildLoadingState(context)
          ] else if (appState.audienceSegments.isEmpty) ...[
            _buildEmptyState(context, appState, selectedProject)
          ] else if (_activeViewIndex == 0) ...[
            _buildSegmentsList(context, appState, nav, selectedProject!)
          ] else ...[
            _buildGeographicStrategyView(context, appState, selectedProject!)
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  //  Control Header & Target Project Selector
  // ───────────────────────────────────────────────────────────

  Widget _buildControlHeader(
    BuildContext context,
    AppStateProvider appState,
    ProjectModel? selectedProject,
  ) {
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
                        'Dynamically evaluate demographics, price elasticity, and interstate migration drivers for your property.',
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

            // Project Selector Bar
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
                  const Text('Selected Project: ', style: TextStyle(fontWeight: FontWeight.w600)),
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
                            child: Text(
                              '${p.name} • ${p.location}, ${p.state} (RM${p.startingPrice.toStringAsFixed(0)})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            final p = appState.projects.firstWhere((proj) => proj.id == id);
                            final wasDiscovered = appState.audienceSegments.isNotEmpty;
                            appState.selectProject(p);
                            if (wasDiscovered) {
                              appState.runAudienceDiscovery(p);
                            }
                          }
                        },
                      ),
                    ),
                  ),
                  if (selectedProject != null) ...[
                    const SizedBox(width: AppTheme.spacingMd),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${selectedProject.propertyType} • ${selectedProject.bedrooms} Bed',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngineStatusBadge(BuildContext context, AppStateProvider appState) {
    if (appState.isUsingAIFallback) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Offline Fallback Engine Active (Rule-Based Analysis)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Live Gemini AI (${appState.currentAIModel}) is currently offline or unreachable. Results are generated via the local rule-based heuristic engine.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade800),
                  ),
                  if (appState.lastAIError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'API Notice: ${appState.lastAIError}',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.amber.shade900),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (appState.audienceSegments.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 18),
            const SizedBox(width: 8),
            Text(
              'Live AI Analysis Verified • Google Gemini 2.5 Flash',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: Colors.green.shade800,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ───────────────────────────────────────────────────────────
  //  Mandatory Transparency & AI Disclaimer Banner
  // ───────────────────────────────────────────────────────────

  Widget _buildTransparencyBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: AppTheme.info, size: 20),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      height: 1.4,
                    ),
                children: const [
                  TextSpan(
                    text: 'DEMO & AI ESTIMATION DISCLOSURE: ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.info),
                  ),
                  TextSpan(
                    text:
                        'All audience segments, suitability ratings, and market sizing below are simulated rule-based marketing hypotheses. '
                        'They are NOT verified real-world transaction statistics or actual registered buyers. '
                        'Use these strategic profiles to tailor advertising angles, digital copy, and lead qualification messaging.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  //  Project Context Analysis Card
  // ───────────────────────────────────────────────────────────

  Widget _buildProjectContextCard(BuildContext context, ProjectModel project) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: AppTheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Project Baseline Profile for Audience Matching',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Purpose: ${project.purpose}',
                    style: const TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _buildContextChip(Icons.location_on_outlined, 'Location', '${project.location}, ${project.state}'),
                _buildContextChip(
                  Icons.payments_outlined,
                  'Price Range',
                  'RM${project.startingPrice.toStringAsFixed(0)} - RM${project.maximumPrice.toStringAsFixed(0)}',
                ),
                _buildContextChip(
                  Icons.bed_outlined,
                  'Layout',
                  '${project.bedrooms} Beds • ${project.bathrooms} Baths • ${project.builtUpArea.toStringAsFixed(0)} sqft',
                ),
                _buildContextChip(Icons.business_outlined, 'Developer', project.developer),
                _buildContextChip(Icons.verified_outlined, 'Status', project.status),
              ],
            ),
            if (project.facilities.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Key Facilities: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  ...project.facilities.take(5).map((f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Text(f, style: const TextStyle(fontSize: 11)),
                      )),
                  if (project.facilities.length > 5)
                    Text('+${project.facilities.length - 5} more', style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContextChip(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textHint, fontWeight: FontWeight.w500)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────
  //  View Selector (Audience Segments vs Geographic Strategy)
  // ───────────────────────────────────────────────────────────

  Widget _buildViewSelector(BuildContext context, AppStateProvider appState) {
    return Row(
      children: [
        ChoiceChip(
          selected: _activeViewIndex == 0,
          label: Text('Audience Segments (${appState.audienceSegments.length})'),
          onSelected: (selected) {
            if (selected) setState(() => _activeViewIndex = 0);
          },
          selectedColor: AppTheme.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: _activeViewIndex == 0 ? AppTheme.primary : AppTheme.textSecondary,
            fontWeight: _activeViewIndex == 0 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(width: AppTheme.spacingMd),
        ChoiceChip(
          selected: _activeViewIndex == 1,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public, size: 16),
              const SizedBox(width: 6),
              Text('Interstate Demographic Strategy (${appState.geoStrategies.values.isNotEmpty ? appState.geoStrategies.values.first.length : 0} Markets)'),
            ],
          ),
          onSelected: (selected) {
            if (selected) setState(() => _activeViewIndex = 1);
          },
          selectedColor: AppTheme.primary.withValues(alpha: 0.15),
          labelStyle: TextStyle(
            color: _activeViewIndex == 1 ? AppTheme.primary : AppTheme.textSecondary,
            fontWeight: _activeViewIndex == 1 ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────
  //  Empty & Loading States
  // ───────────────────────────────────────────────────────────

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(60),
      alignment: Alignment.center,
      child: const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Analyzing property characteristics against demographic cohorts...',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          SizedBox(height: 6),
          Text(
            'Evaluating price elasticity, regional employment hubs, family layout utility, and interstate migration drivers.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppStateProvider appState,
    ProjectModel? selectedProject,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXxl),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.psychology_outlined, size: 64, color: AppTheme.textHint),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'No Audience Analysis Generated Yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Click "Run AI Audience Analysis" to calculate target cohorts, affordability metrics, and campaign positioning.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: selectedProject == null ? null : () => appState.runAudienceDiscovery(),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Discover Audiences Now'),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  //  Audience Segments List View
  // ───────────────────────────────────────────────────────────

  Widget _buildSegmentsList(
    BuildContext context,
    AppStateProvider appState,
    NavigationProvider nav,
    ProjectModel project,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              'Identified Audience Segments (${appState.audienceSegments.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Text(
              '• Dynamically ranked by demographic compatibility, price fit & location affinity',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingMd),

        ...appState.audienceSegments.map((segment) {
          final isExpanded = _expandedSegmentIds.contains(segment.id);
          return _buildEnhancedAudienceCard(
            context,
            segment,
            appState,
            nav,
            project,
            isExpanded,
          );
        }),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────
  //  Enhanced Audience Card (with 10+ Fields, Scoring, & Marketing)
  // ───────────────────────────────────────────────────────────

  Widget _buildEnhancedAudienceCard(
    BuildContext context,
    AudienceSegmentModel segment,
    AppStateProvider appState,
    NavigationProvider nav,
    ProjectModel project,
    bool isExpanded,
  ) {
    final marketingContent = appState.segmentMarketingContent[segment.id];
    final isGeneratingContent = appState.isGeneratingSegmentContent &&
        appState.generatingContentForSegmentId == segment.id;
    final activeTab = _marketingActiveTabs[segment.id] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingLg),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Rank, Title, Score, Action Buttons
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rank Badge
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '#${segment.rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),

                // Name & Metadata Subtitles
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
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
                              color: segment.suitabilityScore >= 85
                                  ? AppTheme.secondary.withValues(alpha: 0.15)
                                  : segment.suitabilityScore >= 70
                                      ? AppTheme.warning.withValues(alpha: 0.15)
                                      : AppTheme.textHint.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: segment.suitabilityScore >= 85
                                    ? AppTheme.secondary
                                    : segment.suitabilityScore >= 70
                                        ? AppTheme.warning
                                        : AppTheme.textHint,
                                width: 0.5,
                              ),
                            ),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 3),
                                      child: Icon(
                                        Icons.bolt,
                                        size: 13,
                                        color: segment.suitabilityScore >= 85
                                            ? AppTheme.secondary
                                            : segment.suitabilityScore >= 70
                                                ? AppTheme.warning
                                                : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '${segment.suitabilityScore.toStringAsFixed(0)}% COMPATIBILITY (AI ESTIMATE)',
                                    style: TextStyle(
                                      color: segment.suitabilityScore >= 85
                                          ? AppTheme.secondary
                                          : segment.suitabilityScore >= 70
                                              ? AppTheme.warning
                                              : AppTheme.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        segment.description,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      // Quick Demographics Bar with Hypothetical Persona Indicator
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (segment.ageRange.isNotEmpty)
                            _buildMiniTag(Icons.cake_outlined, 'Age: ${segment.ageRange}'),
                          if (segment.incomeRange.isNotEmpty)
                            _buildMiniTag(Icons.account_balance_wallet_outlined, 'Income: ${segment.incomeRange}'),
                          _buildMiniTag(Icons.flag_outlined, 'Purpose: ${segment.purchasePurpose}'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBorder.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'HYPOTHETICAL PERSONA',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textHint),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),

                // Action Buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    // Expand/Collapse Deep Dive Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: () => _toggleExpanded(segment.id),
                      icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16),
                      label: Text(isExpanded ? 'Hide Deep Dive' : 'Marketing & Geo Kit'),
                    ),

                    // Launch Full Marketing Module
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
                      icon: const Icon(Icons.rocket_launch, size: 16),
                      label: const Text('Campaign Studio'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLg),
            const Divider(),
            const SizedBox(height: AppTheme.spacingMd),

            // Two-column Core Profile Details
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 850;

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
                          if (segment.marketingAngle.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildDetailSection(
                              title: '🎯 Suggested Marketing Angle',
                              content: segment.marketingAngle,
                            ),
                          ],
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
                          // Positive Compatibility Factors
                          if (segment.scoringFactors.any((f) => f.startsWith('+'))) ...[
                            const Row(
                              children: [
                                Icon(Icons.check_circle, size: 15, color: AppTheme.secondary),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Positive Compatibility Drivers',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: segment.scoringFactors
                                    .where((f) => f.startsWith('+'))
                                    .map((factor) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                                        Expanded(
                                          child: Text(
                                            factor,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Negative Factors & Constraints
                          if (segment.scoringFactors.any((f) => f.startsWith('-'))) ...[
                            const Row(
                              children: [
                                Icon(Icons.remove_circle, size: 15, color: AppTheme.error),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Negative Factors & Constraints',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.background,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: segment.scoringFactors
                                    .where((f) => f.startsWith('-'))
                                    .map((factor) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.error)),
                                        Expanded(
                                          child: Text(
                                            factor,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Missing Information & Data Gaps
                          if (segment.missingInformation.isNotEmpty) ...[
                            const Row(
                              children: [
                                Icon(Icons.help_outline, size: 15, color: AppTheme.warning),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Missing Information That Could Improve Fit',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: segment.missingInformation.map((info) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('⚠️ ', style: TextStyle(fontSize: 10)),
                                        Expanded(
                                          child: Text(
                                            info,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],

                          // Anticipated Objections
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

                          // Target Channels & Call to Action
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('📱 Recommended Channels', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                                    const Text('🎯 Recommended CTA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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

            // Deep Dive Expansion: Direct Marketing Content & Geographic Targeting
            if (isExpanded) ...[
              const SizedBox(height: AppTheme.spacingLg),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Audience Suitability & Deep Explainability Analysis
                    _buildExpandedAudienceExplanation(context, segment),
                    const SizedBox(height: AppTheme.spacingLg),
                    const Divider(),
                    const SizedBox(height: AppTheme.spacingLg),

                    // In-Situ Marketing & Ad Creative Suite
                    Row(
                      children: [
                        const Icon(Icons.campaign, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'In-Situ Marketing & Ad Creative Suite for "${segment.name}"',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const Spacer(),
                        if (marketingContent == null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            onPressed: isGeneratingContent
                                ? null
                                : () => appState.generateSegmentMarketing(segment),
                            icon: isGeneratingContent
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.auto_awesome, size: 14),
                            label: Text(isGeneratingContent ? 'Generating...' : 'Generate Channel Content'),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: () => appState.generateSegmentMarketing(segment),
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Regenerate'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'AI creative copywriting tailored to this cohort’s psychological triggers, budget reality, and anticipated objections.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 14),

                    if (isGeneratingContent) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    ] else if (marketingContent == null) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: TextButton.icon(
                            onPressed: () => appState.generateSegmentMarketing(segment),
                            icon: const Icon(Icons.touch_app),
                            label: const Text('Click here to generate instant Facebook, Instagram, TikTok & Ad copy'),
                          ),
                        ),
                      )
                    ] else ...[
                      // Channel Tabs (Facebook, Instagram, TikTok, Headlines, CTAs)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildTabButton(segment.id, 0, '📘 Facebook Post', activeTab),
                          _buildTabButton(segment.id, 1, '📸 Instagram Caption', activeTab),
                          _buildTabButton(segment.id, 2, '🎬 TikTok Script & Hook', activeTab),
                          _buildTabButton(segment.id, 3, '💡 5 Ad Headlines', activeTab),
                          _buildTabButton(segment.id, 4, '🎯 5 Action CTAs', activeTab),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tab Content Display with Copy Button
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: _buildMarketingTabContent(
                          context,
                          marketingContent,
                          activeTab,
                          segment.name,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMiniTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(icon, size: 13, color: AppTheme.textSecondary),
              ),
            ),
            TextSpan(
              text: text,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String segmentId, int tabIndex, String label, int currentActive) {
    final isSelected = currentActive == tabIndex;
    return InkWell(
      onTap: () {
        setState(() {
          _marketingActiveTabs[segmentId] = tabIndex;
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.cardBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildMarketingTabContent(
    BuildContext context,
    dynamic marketingContent,
    int tabIndex,
    String segmentName,
  ) {
    String textToCopy = '';
    Widget contentWidget;

    switch (tabIndex) {
      case 0: // Facebook
        textToCopy = marketingContent.facebookPost;
        contentWidget = SelectableText(
          marketingContent.facebookPost,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5),
        );
        break;
      case 1: // Instagram
        textToCopy = marketingContent.instagramCaption;
        contentWidget = SelectableText(
          marketingContent.instagramCaption,
          style: const TextStyle(fontSize: 12, height: 1.5),
        );
        break;
      case 2: // TikTok
        textToCopy = marketingContent.tikTokIdea;
        contentWidget = SelectableText(
          marketingContent.tikTokIdea,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.4),
        );
        break;
      case 3: // Headlines
        final List<String> headlines = marketingContent.headlines;
        textToCopy = headlines.join('\n');
        contentWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: headlines.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text('${entry.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Expanded(
                    child: SelectableText(
                      entry.value,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
        break;
      case 4: // CTAs
      default:
        final List<String> ctas = marketingContent.callToActions;
        textToCopy = ctas.join('\n');
        contentWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: ctas.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.arrow_right, color: AppTheme.secondary, size: 18),
                  Expanded(
                    child: SelectableText(
                      entry.value,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Creative Draft',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textHint),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16, color: AppTheme.primary),
              tooltip: 'Copy to Clipboard',
              onPressed: () => _copyToClipboard(context, textToCopy, 'Marketing copy'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        contentWidget,
      ],
    );
  }

  // ───────────────────────────────────────────────────────────
  //  Audience Suitability & Deep Explainability Analysis (Expanded)
  // ───────────────────────────────────────────────────────────

  Widget _buildExpandedAudienceExplanation(
    BuildContext context,
    AudienceSegmentModel segment,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.psychology, color: AppTheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Audience Suitability & Explainability Deep Dive',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'AI EXPLAINABILITY MATRIX',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Detailed compatibility analysis explaining why this segment matches the project, matching property features, objections, and data gaps.',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 14),

        // Demographic Assumption Disclaimer Callout
        if (segment.demographicDisclaimer.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.info.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: AppTheme.info, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Hypothetical Persona Transparency & Rationale',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.info),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        segment.demographicDisclaimer,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Explainer Matrix
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;

            final leftColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExplainerBox(
                  title: '🔍 Matching Property Characteristics',
                  icon: Icons.check_circle_outline,
                  iconColor: AppTheme.secondary,
                  items: segment.matchingPropertyCharacteristics,
                  emptyText: 'No explicit matching characteristics registered.',
                ),
                const SizedBox(height: 12),
                _buildExplainerBox(
                  title: '🎯 Suggested Marketing Strategy',
                  icon: Icons.lightbulb_outline,
                  iconColor: AppTheme.accent,
                  customContent: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        segment.marketingAngle,
                        style: const TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w600),
                      ),
                      if (segment.recommendedMarketingMessages.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('Key Message Hooks:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textHint)),
                        const SizedBox(height: 4),
                        ...segment.recommendedMarketingMessages.take(2).map((msg) => Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Text('• $msg', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                            )),
                      ],
                    ],
                  ),
                ),
              ],
            );

            final rightColumn = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExplainerBox(
                  title: '⚠️ Anticipated Objections & Resistance',
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppTheme.error,
                  items: segment.potentialObjections,
                  emptyText: 'No critical objections flagged.',
                ),
                const SizedBox(height: 12),
                _buildExplainerBox(
                  title: '📋 Missing Information That Could Improve Fit',
                  icon: Icons.help_outline,
                  iconColor: AppTheme.warning,
                  items: segment.missingInformation,
                  emptyText: 'Project specification is comprehensive; no missing criteria detected.',
                ),
              ],
            );

            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: leftColumn),
                      const SizedBox(width: 14),
                      Expanded(child: rightColumn),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftColumn,
                      const SizedBox(height: 12),
                      rightColumn,
                    ],
                  );
          },
        ),
      ],
    );
  }

  Widget _buildExplainerBox({
    required String title,
    required IconData icon,
    required Color iconColor,
    List<String>? items,
    Widget? customContent,
    String? emptyText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (customContent != null)
            customContent
          else if (items != null && items.isNotEmpty)
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: iconColor)),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ))
          else if (emptyText != null)
            Text(
              emptyText,
              style: const TextStyle(fontSize: 11, color: AppTheme.textHint, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────
  //  Interstate Demographic Strategy View
  // ───────────────────────────────────────────────────────────

  Widget _buildGeographicStrategyView(
    BuildContext context,
    AppStateProvider appState,
    ProjectModel project,
  ) {
    final geoTargets = appState.geoStrategies.values.isNotEmpty
        ? appState.geoStrategies.values.first
        : <GeographicTarget>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.map, color: AppTheme.primary, size: 22),
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: Text(
                        'Interstate Demographic & Cross-Border Migration Strategy',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Malaysian property buyers are not confined to the host state (${project.state}). '
                  'Below is a strategic market sizing of outbound buyer pools who can be recruited for ${project.name}. '
                  'All geographic insights represent strategic targeting models, not verified migration statistics or actual property demand.',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacingLg),

        ...geoTargets.map((geo) {
          return Card(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingLg),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.location_city, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: AppTheme.spacingMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              geo.state,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Target Regional Market',
                              style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${geo.relevanceScore.toStringAsFixed(0)}% MARKET AFFINITY',
                          style: const TextStyle(
                            color: AppTheme.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 1. Why it is a potential target
                  const Text(
                    '📍 Why This State Is A Potential Target:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    geo.rationale,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),

                  // 2. Marketing Opportunity
                  if (geo.marketingOpportunity.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.trending_up, size: 16, color: AppTheme.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Marketing Opportunity:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  geo.marketingOpportunity,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 3. Suggested Campaign Angle
                  if (geo.campaignAngle.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.campaign, size: 16, color: AppTheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Suggested Campaign Angle:',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '"${geo.campaignAngle}"',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary, fontStyle: FontStyle.italic),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 4. Assumptions Behind the Recommendation
                  if (geo.assumptions.isNotEmpty) ...[
                    const Text(
                      '📋 Assumptions Behind This Recommendation:',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: geo.assumptions.map((assumption) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textHint)),
                                Expanded(
                                  child: Text(
                                    assumption,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 5. Recommended Acquisition Tactics
                  const Text(
                    '👉 Recommended Acquisition Tactics:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  ...geo.marketingApproach.map((tactic) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            Expanded(child: Text(tactic, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
                  const SizedBox(height: 8),

                  // Disclosure Footer
                  const Text(
                    '⚠️ Strategic targeting assumption • Not verified census migration statistics',
                    style: TextStyle(fontSize: 10, color: AppTheme.textHint, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────
  //  Shared Detail Section Builder
  // ───────────────────────────────────────────────────────────

  Widget _buildDetailSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}
