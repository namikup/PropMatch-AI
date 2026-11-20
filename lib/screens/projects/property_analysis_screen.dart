import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/project_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/ai_backend_service.dart';

/// Screen presenting complete AI Property Analysis & Selling Strategy (Phase 3.2).
///
/// Provides deep property intelligence across 7 structured modules:
/// Overview & Positioning, Key Selling Points, Buyer Personas,
/// Competitive Advantages with Evidence Verification, Buyer Objections & Response Scripts,
/// Multi-Channel Marketing Strategy, and Strategic Summary with explicit AI limitations.
class PropertyAnalysisScreen extends StatefulWidget {
  final ProjectModel? initialProject;

  const PropertyAnalysisScreen({
    super.key,
    this.initialProject,
  });

  @override
  State<PropertyAnalysisScreen> createState() => _PropertyAnalysisScreenState();
}

class _PropertyAnalysisScreenState extends State<PropertyAnalysisScreen> {
  ProjectModel? _targetProject;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppStateProvider>();
      final project = widget.initialProject ?? appState.selectedProject;
      if (project != null) {
        setState(() => _targetProject = project);
        // Automatically check cache or run analysis if not available
        if (appState.currentPropertyAnalysis == null ||
            appState.selectedProject?.id != project.id) {
          appState.runPropertyAnalysis(project: project);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final project = widget.initialProject ?? _targetProject ?? appState.selectedProject;

    if (project == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('AI Property Intelligence'),
          backgroundColor: AppTheme.surface,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.apartment_outlined, size: 64, color: AppTheme.textHint),
              const SizedBox(height: AppTheme.spacingMd),
              const Text(
                'No Project Selected for Analysis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTheme.spacingSm),
              const Text(
                'Select a project from the portfolio to generate AI selling strategies.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to Projects'),
              ),
            ],
          ),
        ),
      );
    }

    final analysis = appState.currentPropertyAnalysis;
    final isLoading = appState.isAnalyzingProperty;
    final error = appState.propertyAnalysisError;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(context, project, analysis, isLoading, appState),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingXl,
          vertical: AppTheme.spacingLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Toolbar & AI Provenance Header
            _buildProvenanceHeader(context, project, analysis, isLoading, appState),
            const SizedBox(height: AppTheme.spacingLg),

            // Loading State Banner
            if (isLoading) ...[
              _buildLoadingState(project),
              const SizedBox(height: AppTheme.spacingLg),
            ],

            // Error Banner (if any)
            if (error != null && !isLoading) ...[
              _buildErrorBanner(context, error, project, appState),
              const SizedBox(height: AppTheme.spacingLg),
            ],

            // Content Sections
            if (analysis != null) ...[
              // Section A: Overview & Positioning
              _buildSectionAOverview(context, project, analysis),
              const SizedBox(height: AppTheme.spacingXl),

              // Section B: Key Selling Points
              _buildSectionBSellingPoints(context, analysis),
              const SizedBox(height: AppTheme.spacingXl),

              // Section C: Potential Buyer Personas
              _buildSectionCBuyerPersonas(context, analysis),
              const SizedBox(height: AppTheme.spacingXl),

              // Section D: Competitive Advantages & Evidence
              _buildSectionDCompetitiveAdvantages(context, analysis),
              const SizedBox(height: AppTheme.spacingXl),

              // Section E: Buyer Objections & Response Strategy
              _buildSectionEObjections(context, analysis),
              const SizedBox(height: AppTheme.spacingXl),

              // Section F: Recommended Marketing Strategy
              _buildSectionFMarketingStrategy(context, analysis),
              const SizedBox(height: AppTheme.spacingXl),

              // Section G: Strategic Summary & AI Limitations
              _buildSectionGSummaryAndLimitations(context, analysis),
              const SizedBox(height: AppTheme.spacingXxl),
            ] else if (!isLoading && error == null) ...[
              _buildEmptyState(context, project, appState),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    ProjectModel project,
    PropertyAnalysisResult? analysis,
    bool isLoading,
    AppStateProvider appState,
  ) {
    return AppBar(
      backgroundColor: AppTheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        tooltip: 'Back to Projects',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Row(
        children: [
          const Icon(Icons.psychology_outlined, color: AppTheme.primary, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'AI Property Intelligence — ${project.name}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              project.state.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (analysis != null) ...[
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
            ),
            onPressed: () => _openAudienceDiscovery(context, project, analysis, appState),
            icon: const Icon(Icons.person_search, size: 16),
            label: const Text('Discover Potential Buyers'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _copyFullSummary(context, analysis, project),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Strategy Summary'),
          ),
          const SizedBox(width: 8),
        ],
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: isLoading
              ? null
              : () => appState.runPropertyAnalysis(project: project, forceRefresh: true),
          icon: isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh, size: 16),
          label: Text(isLoading ? 'Analyzing...' : 'Regenerate Analysis'),
        ),
        const SizedBox(width: AppTheme.spacingMd),
      ],
    );
  }

  Widget _buildProvenanceHeader(
    BuildContext context,
    ProjectModel project,
    PropertyAnalysisResult? analysis,
    bool isLoading,
    AppStateProvider appState,
  ) {
    final isLiveAI = analysis?.isLiveAI ?? false;
    final isCached = analysis?.isCached ?? false;
    final model = analysis?.model ?? appState.currentAIModel;
    final confidence = analysis?.analysisConfidence ?? 'High';

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // AI Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isLiveAI
                  ? AppTheme.secondary.withValues(alpha: 0.12)
                  : AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isLiveAI
                    ? AppTheme.secondary.withValues(alpha: 0.3)
                    : AppTheme.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLiveAI ? Icons.auto_awesome : Icons.rule_outlined,
                  size: 14,
                  color: isLiveAI ? AppTheme.secondary : AppTheme.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  isLiveAI ? 'LIVE AI ($model)' : 'RULE-BASED FALLBACK ENGINE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isLiveAI ? AppTheme.secondary : AppTheme.accent,
                  ),
                ),
              ],
            ),
          ),

          // Cache Status Badge
          if (isCached)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cached, size: 14, color: AppTheme.info),
                  SizedBox(width: 4),
                  Text(
                    'Instant Cached Analysis',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.info,
                    ),
                  ),
                ],
              ),
            ),

          // Confidence Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Confidence: $confidence',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),

          if (analysis != null)
            Text(
              'Generated: ${_formatTimestamp(analysis.generatedAt)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),

          if (analysis?.fallbackReason != null)
            Tooltip(
              message: analysis!.fallbackReason!,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppTheme.accent),
                  SizedBox(width: 4),
                  Text(
                    'Offline Fallback Active',
                    style: TextStyle(fontSize: 11, color: AppTheme.accent),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ProjectModel project) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacingMd),
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            'Analyzing ${project.name}...',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Evaluating selling points, matching buyer personas, benchmarking competitive advantages, and formulating objection handling strategies.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingMd),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(
    BuildContext context,
    String error,
    ProjectModel project,
    AppStateProvider appState,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.error, size: 22),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Analysis Incomplete or Failed',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => appState.runPropertyAnalysis(project: project, forceRefresh: true),
            child: const Text('Retry Analysis'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    ProjectModel project,
    AppStateProvider appState,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingXl,
        vertical: 60,
      ),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, size: 32, color: AppTheme.primary),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            'Ready to Analyze ${project.name}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: const Text(
              'Generate 7-part property intelligence: selling points, buyer personas, market differentiators, objection response scripts, and marketing hooks.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: () => appState.runPropertyAnalysis(project: project),
            icon: const Icon(Icons.psychology, size: 18),
            label: const Text('Generate AI Property Analysis'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION A: Overview & Positioning
  // ---------------------------------------------------------------------------
  Widget _buildSectionAOverview(
    BuildContext context,
    ProjectModel project,
    PropertyAnalysisResult analysis,
  ) {
    final overview = analysis.propertyOverview;
    final pricePerSqft = project.builtUpArea > 0
        ? 'RM ${(project.startingPrice / project.builtUpArea).toStringAsFixed(0)} / sqft'
        : 'N/A';

    return _buildCardWrapper(
      title: 'A. Property Overview & Market Positioning',
      subtitle: 'Synthesis of project specifications and strategic submarket positioning.',
      icon: Icons.domain,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Spec Chips Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSpecChip(Icons.location_on_outlined, '${project.location}, ${project.state}'),
              _buildSpecChip(Icons.home_work_outlined, project.propertyType),
              _buildSpecChip(
                Icons.payments_outlined,
                'RM ${project.startingPrice.toStringAsFixed(0)} - RM ${project.maximumPrice.toStringAsFixed(0)}',
              ),
              _buildSpecChip(Icons.square_foot_outlined, '${project.builtUpArea.toStringAsFixed(0)} sqft ($pricePerSqft)'),
              _buildSpecChip(Icons.bed_outlined, '${project.bedrooms} Beds, ${project.bathrooms} Baths'),
              _buildSpecChip(Icons.business_outlined, 'Developer: ${project.developer}'),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Positioning Statement Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.stars, color: AppTheme.primary, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'STRATEGIC POSITIONING',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (overview?.targetBuyerCategory != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          overview!.targetBuyerCategory.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  overview?.positioningStatement ?? analysis.recommendedPricePositioning,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),

          // Executive Summary Text
          Text(
            analysis.projectSummary,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION B: Key Selling Points
  // ---------------------------------------------------------------------------
  Widget _buildSectionBSellingPoints(
    BuildContext context,
    PropertyAnalysisResult analysis,
  ) {
    final sellingPoints = analysis.structuredSellingPoints;

    return _buildCardWrapper(
      title: 'B. Key Selling Points & Buyer Benefits',
      subtitle: '3 to 5 core value propositions anchored directly in verified project features.',
      icon: Icons.verified_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMultiColumn = constraints.maxWidth >= 720;
          return Wrap(
            spacing: AppTheme.spacingMd,
            runSpacing: AppTheme.spacingMd,
            children: sellingPoints.asMap().entries.map((entry) {
              final idx = entry.key + 1;
              final sp = entry.value;
              final cardWidth = isMultiColumn ? (constraints.maxWidth - AppTheme.spacingMd) / 2 : constraints.maxWidth;

              return SizedBox(
                width: cardWidth,
                child: Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$idx',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sp.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: sp.confidence == 'High'
                                  ? AppTheme.secondary.withValues(alpha: 0.12)
                                  : AppTheme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${sp.confidence} Confidence',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: sp.confidence == 'High' ? AppTheme.secondary : AppTheme.accent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        sp.explanation,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      // Supporting Info Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 12, color: AppTheme.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Source: ${sp.supportingInfo}',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Buyer Benefit
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.volunteer_activism_outlined, size: 14, color: AppTheme.secondary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sp.buyerBenefit,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION C: Potential Buyer Personas
  // ---------------------------------------------------------------------------
  Widget _buildSectionCBuyerPersonas(
    BuildContext context,
    PropertyAnalysisResult analysis,
  ) {
    final personas = analysis.buyerPersonas;

    return _buildCardWrapper(
      title: 'C. Potential Buyer Personas',
      subtitle: '3 to 5 demographic and psychographic profiles representing marketing hypotheses.',
      icon: Icons.groups_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMultiColumn = constraints.maxWidth >= 720;
              return Wrap(
                spacing: AppTheme.spacingMd,
                runSpacing: AppTheme.spacingMd,
                children: personas.map((persona) {
                  final cardWidth = isMultiColumn ? (constraints.maxWidth - AppTheme.spacingMd) / 2 : constraints.maxWidth;

                  return SizedBox(
                    width: cardWidth,
                    child: Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Persona Header & Relevance Score
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  persona.segmentName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${persona.relevanceScore}% Fit',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Motivations Chips
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: persona.keyMotivations.map((m) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  m,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.primary),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),

                          // Appealing Features
                          if (persona.appealingFeatures.isNotEmpty) ...[
                            const Text(
                              'Appealing Features:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(height: 2),
                            ...persona.appealingFeatures.map(
                              (feat) => Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 2),
                                child: Text('• $feat', style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Hesitations
                          if (persona.potentialObjections.isNotEmpty) ...[
                            const Text(
                              'Primary Hesitation:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.accent),
                            ),
                            const SizedBox(height: 2),
                            ...persona.potentialObjections.map(
                              (obj) => Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 2),
                                child: Text('• $obj', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Marketing Hook Quote
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Text(
                              'Hook: "${persona.recommendedHook}"',
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_search, color: AppTheme.primary, size: 28),
                const SizedBox(width: AppTheme.spacingMd),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover Actionable Buyer Audiences',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Unlock deeper market demand intelligence distinguishing verified project facts from hypotheses with tailored marketing hooks.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMd),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final appState = context.read<AppStateProvider>();
                    final p = widget.initialProject ?? _targetProject ?? appState.selectedProject;
                    if (p != null) {
                      _openAudienceDiscovery(context, p, analysis, appState);
                    }
                  },
                  icon: const Icon(Icons.person_search, size: 16),
                  label: const Text('Discover Potential Buyers'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION D: Competitive Advantages & Evidence Status
  // ---------------------------------------------------------------------------
  Widget _buildSectionDCompetitiveAdvantages(
    BuildContext context,
    PropertyAnalysisResult analysis,
  ) {
    final advantages = analysis.structuredCompetitiveAdvantages;

    return _buildCardWrapper(
      title: 'D. Competitive Advantages & Market Evidence',
      subtitle: 'Key project differentiators evaluated against typical submarket properties.',
      icon: Icons.thumb_up_alt_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...advantages.map((adv) {
            Color statusColor;
            switch (adv.evidenceStatus.toLowerCase()) {
              case 'verified project data':
                statusColor = AppTheme.secondary;
                break;
              case 'market inference':
                statusColor = AppTheme.info;
                break;
              default:
                statusColor = AppTheme.textHint;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          adv.advantage,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          adv.evidenceStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    adv.explanation,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Supporting Evidence: ${adv.supportingEvidence}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),

          // Competitor Comparison Disclaimer
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppTheme.textHint),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Competitor comparison unavailable: Specific competitor names or external project benchmarks are withheld unless verified competitor data is supplied.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION E: Buyer Objections & Response Strategy
  // ---------------------------------------------------------------------------
  Widget _buildSectionEObjections(
    BuildContext context,
    PropertyAnalysisResult analysis,
  ) {
    final objections = analysis.structuredObjections;

    return _buildCardWrapper(
      title: 'E. Buyer Objections & Professional Response Strategy',
      subtitle: 'Anticipated buyer hesitations paired with structured, professional talking points.',
      icon: Icons.forum_outlined,
      child: Column(
        children: objections.map((obj) {
          return Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        obj.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        obj.objection,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.record_voice_over_outlined, size: 14, color: AppTheme.primary),
                              SizedBox(width: 6),
                              Text(
                                'RECOMMENDED AGENT SCRIPT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 14, color: AppTheme.textSecondary),
                            tooltip: 'Copy script',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: obj.recommendedResponse));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Agent script copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        obj.recommendedResponse,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION F: Recommended Marketing Strategy
  // ---------------------------------------------------------------------------
  Widget _buildSectionFMarketingStrategy(
    BuildContext context,
    PropertyAnalysisResult analysis,
  ) {
    final strategy = analysis.marketingStrategy;
    final headlines = strategy?.headlines ?? analysis.marketingAngles;
    final channels = strategy?.suggestedChannels ?? ['Facebook Ads', 'WhatsApp Broadcast', 'Property Portals'];
    final socialAngles = strategy?.socialMediaAngles ?? [];
    final ctas = strategy?.callToActions ?? ['Register for VIP Preview', 'Download Project Brochure'];

    return _buildCardWrapper(
      title: 'F. Recommended Marketing Strategy',
      subtitle: 'Compelling headlines, high-conversion channels, social hooks, and call-to-actions.',
      icon: Icons.campaign_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Headlines
          const Text(
            'Campaign Headlines & Taglines:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          ...headlines.map((hl) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.format_quote, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hl,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14),
                    tooltip: 'Copy headline',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: hl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Headline copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppTheme.spacingLg),

          // Marketing Channels
          const Text(
            'Suggested Acquisition Channels:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: channels.map((ch) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      ch,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Social Media Angles
          if (socialAngles.isNotEmpty) ...[
            const Text(
              'Social Media Angles & Creative Concepts:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            ...socialAngles.map(
              (angle) => Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text('• $angle', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),
          ],

          // Call to Actions
          const Text(
            'Recommended Calls to Action (CTAs):',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ctas.map((cta) {
              return ActionChip(
                label: Text(cta),
                avatar: const Icon(Icons.touch_app, size: 14),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: cta));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied CTA: "$cta"')),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SECTION G: Strategic Summary & AI Limitations
  // ---------------------------------------------------------------------------
  Widget _buildSectionGSummaryAndLimitations(
    BuildContext context,
    PropertyAnalysisResult analysis,
  ) {
    final summary = analysis.analysisSummary;

    return _buildCardWrapper(
      title: 'G. Strategic Summary & Operational Boundaries',
      subtitle: 'Key execution takeaways and explicit AI analytical boundaries.',
      icon: Icons.checklist_rtl_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Takeaways Grid
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                _buildSummaryRow(
                  'Strongest Selling Point:',
                  summary?.strongestSellingPoint ?? (analysis.keySellingPoints.isNotEmpty ? analysis.keySellingPoints.first : 'N/A'),
                ),
                const Divider(height: 16),
                _buildSummaryRow(
                  'Primary Target Audience:',
                  summary?.primaryTargetAudience ?? (analysis.potentialBuyerSegments.isNotEmpty ? analysis.potentialBuyerSegments.first : 'N/A'),
                ),
                const Divider(height: 16),
                _buildSummaryRow(
                  'Main Expected Objection:',
                  summary?.mainObjection ?? (analysis.potentialObjections.isNotEmpty ? analysis.potentialObjections.first : 'N/A'),
                ),
                const Divider(height: 16),
                _buildSummaryRow(
                  'Recommended Next Step:',
                  summary?.recommendedNextStep ?? 'Launch targeted social campaign and organize private agent briefing.',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final appState = context.read<AppStateProvider>();
                      final p = widget.initialProject ?? _targetProject ?? appState.selectedProject;
                      if (p != null) {
                        _openAudienceDiscovery(context, p, analysis, appState);
                      }
                    },
                    icon: const Icon(Icons.person_search, size: 16),
                    label: const Text('Discover Potential Buyers for this Strategy'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Explicit AI Limitations & Regulatory Notice
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: AppTheme.warning),
                    SizedBox(width: 8),
                    Text(
                      'AI INTELLIGENCE LIMITATIONS & REGULATORY NOTICE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.warning,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  summary?.limitationsText ??
                      'This analysis constitutes an algorithmic marketing hypothesis generated from agent-supplied project parameters. Factual property specifications, statutory permits (APDL), loan eligibility, and final pricing must be verified by the licensed REN/PEA with the developer before dissemination to buyers. Personas are marketing classifications and do not represent individual buyer records.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper widgets
  Widget _buildCardWrapper({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildSpecChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _copyFullSummary(
    BuildContext context,
    PropertyAnalysisResult analysis,
    ProjectModel project,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('=== PropMatch AI Property Intelligence: ${project.name} ===');
    buffer.writeln('Location: ${project.location}, ${project.state}');
    buffer.writeln('Price: RM ${project.startingPrice.toStringAsFixed(0)} - RM ${project.maximumPrice.toStringAsFixed(0)}');
    buffer.writeln('');
    buffer.writeln('--- Executive Summary ---');
    buffer.writeln(analysis.projectSummary);
    buffer.writeln('');
    buffer.writeln('--- Key Selling Points ---');
    for (final sp in analysis.structuredSellingPoints) {
      buffer.writeln('• ${sp.title}: ${sp.explanation} (${sp.buyerBenefit})');
    }
    buffer.writeln('');
    buffer.writeln('--- Top Buyer Personas ---');
    for (final p in analysis.buyerPersonas) {
      buffer.writeln('• ${p.segmentName} (${p.relevanceScore}% fit): Hook: "${p.recommendedHook}"');
    }
    buffer.writeln('');
    buffer.writeln('--- Strategic Recommendations ---');
    if (analysis.analysisSummary != null) {
      buffer.writeln('Strongest Selling Point: ${analysis.analysisSummary!.strongestSellingPoint}');
      buffer.writeln('Top Audience: ${analysis.analysisSummary!.primaryTargetAudience}');
      buffer.writeln('Main Objection: ${analysis.analysisSummary!.mainObjection}');
      buffer.writeln('Next Action: ${analysis.analysisSummary!.recommendedNextStep}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Strategic summary for ${project.name} copied to clipboard!')),
    );
  }

  void _openAudienceDiscovery(
    BuildContext context,
    ProjectModel project,
    PropertyAnalysisResult? analysis,
    AppStateProvider appState,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        final obsController = TextEditingController();
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_search, color: AppTheme.primary),
              SizedBox(width: 8),
              Text(
                'Discover Potential Buyers',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI will analyze ${project.name} along with the property intelligence to discover 3–6 potential buyer segments.',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Local Market Observations (Optional):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: obsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Strong interest from Penang Island upgraders, doctors from nearby hospital, foreign tech workers...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'Notice: Output will be an AI-generated audience hypothesis distinguishing verified facts from assumptions. Relevance scores reflect marketing fit, not actual conversion rates.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final observations = obsController.text.trim();
                Navigator.of(ctx).pop();
                appState.selectProject(project);
                appState.runAudienceDiscovery(
                  project: project,
                  existingAnalysis: analysis,
                  agentObservations: observations.isNotEmpty ? observations : null,
                );
                try {
                  context.read<NavigationProvider>().navigateTo(NavItem.audienceDiscovery);
                } catch (_) {
                  Navigator.of(context).maybePop();
                }
              },
              icon: const Icon(Icons.person_search, size: 16),
              label: const Text('Discover Buyers'),
            ),
          ],
        );
      },
    );
  }
}
