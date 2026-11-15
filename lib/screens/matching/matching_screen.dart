import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/match_model.dart';
import '../../providers/app_state_provider.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  String _scoreFilter = 'All'; // All, High (>75%), Moderate (50-75%), Low (<50%)

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final selectedProject = appState.selectedProject;

    final filteredMatches = appState.matches.where((m) {
      if (_scoreFilter == 'High (>75%)') return m.overallMatchPercentage >= 75.0;
      if (_scoreFilter == 'Moderate (50-75%)') return m.overallMatchPercentage >= 50.0 && m.overallMatchPercentage < 75.0;
      if (_scoreFilter == 'Low (<50%)') return m.overallMatchPercentage < 50.0;
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              child: Row(
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
                              child: const Icon(Icons.compare_arrows, color: AppTheme.primary, size: 24),
                            ),
                            const SizedBox(width: AppTheme.spacingMd),
                            Expanded(
                              child: Text(
                                'AI Buyer-Project Matching Engine',
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
                          'Evaluates buyer budget (25%), location (25%), property type (20%), purpose (15%), and timeline (15%).',
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),

                  // Run matching button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    ),
                    onPressed: appState.isMatching || selectedProject == null
                        ? null
                        : () => appState.runBuyerMatching(),
                    icon: appState.isMatching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.bolt, size: 18),
                    label: Text(appState.isMatching ? 'Calculating Matches...' : 'Run Matching Engine'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Main 2-Column Desktop layout
          if (appState.isMatching) ...[
            Container(
              padding: const EdgeInsets.all(60),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cross-referencing buyer preferences with property parameters...'),
                ],
              ),
            ),
          ] else if (appState.matches.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingXxl),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.compare_arrows_outlined, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text('No Matches Calculated', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Click "Run Matching Engine" to compare all registered buyers with the active project.'),
                  const SizedBox(height: AppTheme.spacingLg),
                  ElevatedButton.icon(
                    onPressed: () => appState.runBuyerMatching(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Matching'),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Filter Pills
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Score Cohort: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ...['All', 'High (>75%)', 'Moderate (50-75%)', 'Low (<50%)'].map((filter) {
                  final isSel = _scoreFilter == filter;
                  return ChoiceChip(
                    label: Text(filter),
                    selected: isSel,
                    onSelected: (v) => setState(() => _scoreFilter = filter),
                  );
                }),
                const SizedBox(width: 16),
                Text(
                  '${filteredMatches.length} Candidate Matches',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Two-column layout for desktop
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 950) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Candidate List (Left)
                      Expanded(
                        flex: 5,
                        child: _buildCandidateList(context, filteredMatches, appState),
                      ),
                      const SizedBox(width: AppTheme.spacingLg),
                      // Candidate Inspector (Right)
                      Expanded(
                        flex: 6,
                        child: appState.selectedMatch != null
                            ? _buildMatchInspector(context, appState.selectedMatch!, appState)
                            : const SizedBox.shrink(),
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
                    _buildCandidateList(context, filteredMatches, appState),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCandidateList(
    BuildContext context,
    List<MatchModel> matches,
    AppStateProvider appState,
  ) {
    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: matches.length,
        separatorBuilder: (ctx, i) => const Divider(height: 1),
        itemBuilder: (ctx, index) {
          final match = matches[index];
          final isSelected = appState.selectedMatch?.id == match.id;

          Color scoreColor = AppTheme.primary;
          if (match.overallMatchPercentage >= 75) scoreColor = AppTheme.success;
          if (match.overallMatchPercentage < 50) scoreColor = AppTheme.error;

          return ListTile(
            tileColor: isSelected ? AppTheme.primary.withValues(alpha: 0.05) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: scoreColor.withValues(alpha: 0.15),
              child: Text(
                '${match.overallMatchPercentage.toStringAsFixed(0)}%',
                style: TextStyle(color: scoreColor, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
            title: Row(
              children: [
                Text(match.buyerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (match.isDemoBuyer) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('DEMO', style: TextStyle(color: AppTheme.warning, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              match.explanation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => appState.selectMatch(match),
          );
        },
      ),
    );
  }

  Widget _buildMatchInspector(
    BuildContext context,
    MatchModel match,
    AppStateProvider appState,
  ) {
    Color scoreColor = AppTheme.primary;
    if (match.overallMatchPercentage >= 75) scoreColor = AppTheme.success;
    if (match.overallMatchPercentage < 50) scoreColor = AppTheme.error;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        match.buyerName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Targeting: ${match.projectName}',
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${match.overallMatchPercentage.toStringAsFixed(1)}% MATCH',
                    style: TextStyle(color: scoreColor, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),
            Text(match.explanation, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: AppTheme.spacingLg),
            const Divider(),
            const SizedBox(height: AppTheme.spacingMd),

            // Factor Breakdown Bars
            Text('Weighted Matching Dimensions', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
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
              const Text('✅ Key Positive Matching Factors', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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

            // Concerns
            if (match.potentialConcerns.isNotEmpty) ...[
              const Text('⚠️ Potential Concerns / Hesitations', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              ...match.potentialConcerns.map((c) => Padding(
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
              const Text('ℹ️ Information Gaps', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
              const SizedBox(height: 16),
            ],

            // Action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
                onPressed: () {
                  appState.addLeadFromMatch(match);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Converted ${match.buyerName} to active lead!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Convert to Qualified Lead Pipeline'),
              ),
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
              Text('${score.toStringAsFixed(1)} / ${maxScore.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
}
