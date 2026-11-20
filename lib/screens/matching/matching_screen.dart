import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/match_model.dart';
import '../../models/followup_model.dart';
import '../../models/project_model.dart';
import '../../providers/app_state_provider.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final selectedProject = appState.selectedProject;
    final projects = appState.projects;
    final matches = appState.filteredMatches;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Project Selection Bar
          _buildControlHeader(context, appState, selectedProject, projects),
          const SizedBox(height: AppTheme.spacingLg),

          // 2. Matching Overview Statistics Cards
          if (appState.matches.isNotEmpty) ...[
            _buildOverviewStats(context, appState),
            const SizedBox(height: AppTheme.spacingLg),
          ],

          // 3. Error Banner
          if (appState.matchingError != null) ...[
            _buildErrorBanner(context, appState.matchingError!),
            const SizedBox(height: AppTheme.spacingMd),
          ],

          // 4. Main Body: Loading, Empty, or Two-Column Results
          if (appState.isMatching) ...[
            _buildLoadingState(context),
          ] else if (appState.matches.isEmpty) ...[
            _buildEmptyState(context, appState, selectedProject),
          ] else ...[
            // Filter Pills & Sort Bar
            _buildFilterAndSortBar(context, appState),
            const SizedBox(height: AppTheme.spacingMd),

            // Two-column layout for desktop / stacked for narrow
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 950) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Candidate List (Left)
                      Expanded(
                        flex: 5,
                        child: _buildCandidateList(context, matches, appState),
                      ),
                      const SizedBox(width: AppTheme.spacingLg),
                      // Candidate Inspector (Right)
                      Expanded(
                        flex: 6,
                        child: appState.selectedMatch != null
                            ? _buildMatchInspector(context, appState.selectedMatch!, appState)
                            : _buildSelectMatchPrompt(context),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    if (appState.selectedMatch != null) ...[
                      _buildMatchInspector(context, appState.selectedMatch!, appState),
                      const SizedBox(height: AppTheme.spacingLg),
                    ],
                    _buildCandidateList(context, matches, appState),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlHeader(
    BuildContext context,
    AppStateProvider appState,
    ProjectModel? selectedProject,
    List<ProjectModel> projects,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final titleSection = Column(
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
                          child: const Icon(Icons.psychology, color: AppTheme.primary, size: 24),
                        ),
                        const SizedBox(width: AppTheme.spacingMd),
                        Expanded(
                          child: Text(
                            'Intelligent Buyer Matching Engine',
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
                      'Deterministic compatibility scoring across 5 weighted dimensions with Gemini strategic advisory explanations.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );

                final actionButtons = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (appState.matches.isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: appState.isMatching
                            ? null
                            : () => appState.runBuyerMatching(selectedProject, true),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Force Recalculate'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      onPressed: appState.isMatching || selectedProject == null
                          ? null
                          : () => appState.runBuyerMatching(selectedProject),
                      icon: appState.isMatching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.bolt, size: 18),
                      label: Text(appState.isMatching
                          ? 'Evaluating Buyers...'
                          : appState.matches.isEmpty
                              ? 'Run Matching Engine'
                              : 'Re-evaluate Buyers'),
                    ),
                  ],
                );

                if (isWide) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: titleSection),
                      const SizedBox(width: AppTheme.spacingMd),
                      actionButtons,
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleSection,
                    const SizedBox(height: AppTheme.spacingMd),
                    actionButtons,
                  ],
                );
              },
            ),
            const SizedBox(height: AppTheme.spacingLg),
            const Divider(),
            const SizedBox(height: AppTheme.spacingMd),

            // Project Selector Row
            Row(
              children: [
                const Icon(Icons.business, size: 20, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                const Text(
                  'Active Project:',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(width: 12),
                if (projects.isEmpty)
                  const Text('No projects available in portfolio.')
                else
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedProject?.id,
                        isExpanded: true,
                        hint: const Text('Select a property project to match buyers'),
                        items: projects.map((p) {
                          return DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(
                              '${p.name} — ${p.propertyType} in ${p.location}, ${p.state} (RM${p.startingPrice.toStringAsFixed(0)} - RM${p.maximumPrice.toStringAsFixed(0)})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            final proj = projects.firstWhere((p) => p.id == id);
                            appState.selectProject(proj);
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewStats(BuildContext context, AppStateProvider appState) {
    final total = appState.totalEvaluatedMatches;
    final excellent = appState.excellentMatchesCount;
    final good = appState.goodMatchesCount;
    final moderate = appState.moderateMatchesCount;
    final low = appState.lowMatchesCount;
    final avgScore = appState.averageMatchScore;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        final children = [
          _buildStatCard(context, 'Total Evaluated', '$total', Icons.groups_outlined, AppTheme.primary),
          _buildStatCard(context, 'Excellent Match (85%+)', '$excellent', Icons.stars, AppTheme.success),
          _buildStatCard(context, 'Good Match (70-84%)', '$good', Icons.thumb_up_alt_outlined, AppTheme.accent),
          _buildStatCard(context, 'Moderate (50-69%)', '$moderate', Icons.trending_flat, AppTheme.warning),
          _buildStatCard(context, 'Low Match (<50%)', '$low', Icons.remove_circle_outline, AppTheme.textHint),
          _buildStatCard(context, 'Average Match', '${avgScore.toStringAsFixed(1)}%', Icons.analytics_outlined, AppTheme.secondary),
        ];

        if (isWide) {
          return Row(
            children: children
                .map((w) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: w,
                      ),
                    ))
                .toList(),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children.map((w) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: w)).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(icon, size: 16, color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(60),
      alignment: Alignment.center,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Cross-Referencing Buyer Profiles...',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Calculating deterministic scores across budget, location, property type, purpose, and timeline, then synthesizing strategic advisory explanations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
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
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_alt_outlined, size: 48, color: AppTheme.primary),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              Text(
                'No Match Results Yet',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                selectedProject != null
                    ? 'Run the intelligent matching engine to evaluate ${appState.totalBuyerCount} registered buyers against "${selectedProject.name}".'
                    : 'Select a project from the selector bar to begin intelligent buyer matching.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: selectedProject == null ? null : () => appState.runBuyerMatching(selectedProject),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Intelligent Matching'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterAndSortBar(BuildContext context, AppStateProvider appState) {
    final filters = [
      'All',
      'Excellent Match',
      'Good Match',
      'Moderate Match',
      'Low Match',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 750;

            final filterChips = Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Cohort: ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ...filters.map((f) {
                  final isSelected = appState.selectedMatchFilter == f;
                  return ChoiceChip(
                    label: Text(
                      f == 'All'
                          ? 'All (${appState.totalEvaluatedMatches})'
                          : f == 'Excellent Match'
                              ? 'Excellent (${appState.excellentMatchesCount})'
                              : f == 'Good Match'
                                  ? 'Good (${appState.goodMatchesCount})'
                                  : f == 'Moderate Match'
                                      ? 'Moderate (${appState.moderateMatchesCount})'
                                      : 'Low (${appState.lowMatchesCount})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (val) => appState.setMatchFilter(f),
                  );
                }),
                const SizedBox(width: 8),
                Text(
                  '${appState.filteredMatches.length} Candidate Matches',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            );

            final sortControl = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                const Text('Sort by:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: appState.matchSortOrder,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'score', child: Text('Highest Compatibility')),
                      DropdownMenuItem(value: 'budget', child: Text('Budget Score')),
                      DropdownMenuItem(value: 'timeline', child: Text('Urgent Timeline')),
                    ],
                    onChanged: (val) {
                      if (val != null) appState.setMatchSortOrder(val);
                    },
                  ),
                ),
              ],
            );

            if (isWide) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: filterChips),
                  const SizedBox(width: 16),
                  sortControl,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                filterChips,
                const SizedBox(height: 8),
                const Divider(),
                sortControl,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCandidateList(
    BuildContext context,
    List<MatchModel> matches,
    AppStateProvider appState,
  ) {
    if (matches.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingXl),
          child: Center(
            child: Text(
              'No candidate matches meet the "${appState.selectedMatchFilter}" filter.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: matches.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
      itemBuilder: (ctx, index) {
        final match = matches[index];
        final isSelected = appState.selectedMatch?.id == match.id;

        Color scoreColor = AppTheme.primary;
        if (match.isExcellentMatch) {
          scoreColor = AppTheme.success;
        } else if (match.isGoodMatch) {
          scoreColor = AppTheme.accent;
        } else if (match.isModerateMatch) {
          scoreColor = AppTheme.warning;
        } else {
          scoreColor = AppTheme.textHint;
        }

        return Card(
          elevation: isSelected ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            side: BorderSide(
              color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            onTap: () => appState.selectMatch(match),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Name, Badges & Score
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: scoreColor.withValues(alpha: 0.15),
                              child: Text(
                                match.formattedScore,
                                style: TextStyle(color: scoreColor, fontWeight: FontWeight.w800, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          match.buyerName,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (match.isDemoBuyer) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.warning.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                          child: const Text('DEMO',
                                              style: TextStyle(
                                                  color: AppTheme.warning,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: scoreColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          match.matchClassification,
                                          style: TextStyle(color: scoreColor, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (match.confidenceLevel == 'High'
                                                  ? AppTheme.success
                                                  : match.confidenceLevel == 'Medium'
                                                      ? AppTheme.warning
                                                      : AppTheme.error)
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${match.confidenceLevel} Confidence',
                                          style: TextStyle(
                                            color: match.confidenceLevel == 'High'
                                                ? AppTheme.success
                                                : match.confidenceLevel == 'Medium'
                                                    ? AppTheme.warning
                                                    : AppTheme.error,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, size: 20, color: AppTheme.textHint),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Row 2: Explanation
                  Text(
                    match.effectiveExplanation,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 8),

                  // Row 3: Action Buttons
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.info_outline, size: 14),
                        label: const Text('View Full Analysis', style: TextStyle(fontSize: 11)),
                        onPressed: () => _showAnalysisDialog(context, match, appState),
                      ),
                      if (match.suggestedConversationOpener != null)
                        ActionChip(
                          avatar: const Icon(Icons.chat_outlined, size: 14),
                          label: const Text('Copy Opener', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: match.suggestedConversationOpener!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Personalized conversation opener copied to clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.person_add_alt, size: 14),
                        label: Text(
                          appState.hasLeadForBuyerAndProject(match.buyerId, match.projectId)
                              ? 'In Leads'
                              : 'Convert to Lead',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () {
                          if (appState.hasLeadForBuyerAndProject(match.buyerId, match.projectId)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${match.buyerName} is already in the lead pipeline.'),
                                backgroundColor: AppTheme.warning,
                              ),
                            );
                            return;
                          }
                          appState.addLeadFromMatch(match);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added ${match.buyerName} to lead pipeline!'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectMatchPrompt(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXxl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app_outlined, size: 48, color: AppTheme.textHint),
              const SizedBox(height: 12),
              Text('Select a Candidate', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text('Click any buyer on the left to inspect multi-factor matching breakdown.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchInspector(
    BuildContext context,
    MatchModel match,
    AppStateProvider appState,
  ) {
    Color scoreColor = AppTheme.primary;
    if (match.isExcellentMatch) {
      scoreColor = AppTheme.success;
    } else if (match.isGoodMatch) {
      scoreColor = AppTheme.accent;
    } else if (match.isModerateMatch) {
      scoreColor = AppTheme.warning;
    } else {
      scoreColor = AppTheme.textHint;
    }

    final alreadyInPipeline = appState.hasLeadForBuyerAndProject(match.buyerId, match.projectId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              match.buyerName,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (match.isDemoBuyer) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('DEMO RECORD',
                                  style: TextStyle(
                                      color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Target Development: ${match.projectName}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${match.overallMatchPercentage.toStringAsFixed(0)}% MATCH',
                        style: TextStyle(color: scoreColor, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      Text(
                        match.matchClassification,
                        style: TextStyle(color: scoreColor, fontWeight: FontWeight.w700, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // AI Explanation Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        match.isLiveAI ? Icons.auto_awesome : Icons.rule,
                        size: 14,
                        color: match.isLiveAI ? AppTheme.accent : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          match.isLiveAI
                              ? 'Gemini Live Advisory'
                              : 'Deterministic Engine Analysis',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: match.isLiveAI ? AppTheme.accent : AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Confidence: ${match.confidenceLevel}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: match.confidenceLevel == 'High'
                              ? AppTheme.success
                              : match.confidenceLevel == 'Medium'
                                  ? AppTheme.warning
                                  : AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    match.effectiveExplanation,
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Weighted Dimensions
            Text(
              'Weighted Matching Dimensions',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _buildScoreBar('Budget Compatibility (Max 25%)', match.budgetScore, 25.0),
            _buildScoreBar('Location Compatibility (Max 25%)', match.locationScore, 25.0),
            _buildScoreBar('Property Type Compatibility (Max 20%)', match.propertyTypeScore, 20.0),
            _buildScoreBar('Purchase Purpose (Max 15%)', match.purposeScore, 15.0),
            _buildScoreBar('Buying Timeline (Max 15%)', match.timelineScore, 15.0),
            const SizedBox(height: AppTheme.spacingLg),
            const Divider(),
            const SizedBox(height: AppTheme.spacingMd),

            // Positive Factors
            if (match.matchingFactors.isNotEmpty) ...[
              const Text('✅ Key Positive Alignment Factors',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              ...match.matchingFactors.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],

            // Concerns / Mismatches
            if (match.mismatchedCriteria.isNotEmpty || match.potentialConcerns.isNotEmpty) ...[
              const Text('⚠️ Considerations & Hesitations',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              ...(match.mismatchedCriteria.isNotEmpty ? match.mismatchedCriteria : match.potentialConcerns).map((c) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(c, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],

            // Missing Info
            if (match.missingInformation.isNotEmpty) ...[
              const Text('ℹ️ Information Verification Needed',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              ...match.missingInformation.map((info) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: AppTheme.info, fontWeight: FontWeight.bold)),
                        Expanded(child: Text(info, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
            ],

            // Recommended Action Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assistant_direction, size: 20, color: AppTheme.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Recommended Agent Action',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary)),
                        const SizedBox(height: 2),
                        Text(match.recommendedNextAction,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Conversation Opener Box
            if (match.suggestedConversationOpener != null) ...[
              const Text('💬 Suggested Outreach Message (WhatsApp / Phone)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.suggestedConversationOpener!,
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: match.suggestedConversationOpener!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Personalized conversation starter copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copy to Clipboard', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddFollowupDialog(context, match, appState),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: const Text('Add Follow-up'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: alreadyInPipeline ? AppTheme.cardBorder : AppTheme.secondary,
                      foregroundColor: alreadyInPipeline ? AppTheme.textSecondary : Colors.white,
                    ),
                    onPressed: () {
                      if (alreadyInPipeline) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${match.buyerName} is already in the lead pipeline.'),
                            backgroundColor: AppTheme.warning,
                          ),
                        );
                        return;
                      }

                      appState.addLeadFromMatch(match);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Converted ${match.buyerName} to active lead!'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    },
                    icon: Icon(alreadyInPipeline ? Icons.check_circle : Icons.person_add_alt, size: 16),
                    label: Text(alreadyInPipeline ? 'In Lead Pipeline' : 'Convert to Lead'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBar(String label, double score, double maxScore) {
    final pct = (score / maxScore).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${score.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppTheme.background,
              color: pct >= 0.75
                  ? AppTheme.success
                  : pct >= 0.5
                      ? AppTheme.accent
                      : AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }

  void _showAnalysisDialog(
    BuildContext context,
    MatchModel match,
    AppStateProvider appState,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: AppTheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Match Analysis: ${match.buyerName}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Compatibility: ${match.formattedScore} (${match.matchClassification})',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(match.effectiveExplanation, style: const TextStyle(fontSize: 13, height: 1.4)),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Weighted Factor Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                _buildScoreBar('Budget Compatibility (Max 25%)', match.budgetScore, 25.0),
                _buildScoreBar('Location Compatibility (Max 25%)', match.locationScore, 25.0),
                _buildScoreBar('Property Type Compatibility (Max 20%)', match.propertyTypeScore, 20.0),
                _buildScoreBar('Purchase Purpose (Max 15%)', match.purposeScore, 15.0),
                _buildScoreBar('Buying Timeline (Max 15%)', match.timelineScore, 15.0),
                if (match.suggestedConversationOpener != null) ...[
                  const SizedBox(height: 16),
                  const Text('Suggested Opener', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(match.suggestedConversationOpener!, style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddFollowupDialog(
    BuildContext context,
    MatchModel match,
    AppStateProvider appState,
  ) {
    final taskController = TextEditingController(
      text: 'Follow up with ${match.buyerName} regarding ${match.projectName}',
    );
    String followupType = 'WhatsApp Follow-up';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Schedule Follow-up Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Buyer: ${match.buyerName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('Project: ${match.projectName}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              const SizedBox(height: 14),
              const Text('Task Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: taskController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text('Follow-up Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: followupType,
                items: const [
                  DropdownMenuItem(value: 'WhatsApp Follow-up', child: Text('WhatsApp Follow-up')),
                  DropdownMenuItem(value: 'Showroom Viewing', child: Text('Showroom Viewing')),
                  DropdownMenuItem(value: 'Loan Screening', child: Text('Loan Screening')),
                  DropdownMenuItem(value: 'Investor Consultation', child: Text('Investor Consultation')),
                  DropdownMenuItem(value: 'Custom Follow-up', child: Text('Custom Follow-up')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => followupType = v);
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final task = taskController.text.trim();
                if (task.isNotEmpty) {
                  final now = DateTime.now();
                  final dueDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

                  appState.addFollowup(FollowupModel(
                    ownerId: appState.currentOwnerId,
                    buyerName: match.buyerName,
                    buyerId: match.buyerId,
                    projectName: match.projectName,
                    projectId: match.projectId,
                    task: task,
                    dueDate: dueDate,
                    type: followupType,
                  ));

                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Follow-up scheduled successfully!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
