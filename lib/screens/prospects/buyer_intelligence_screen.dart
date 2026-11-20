import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/prospect_model.dart';
import '../../models/prospect_consent_event_model.dart';
import '../../models/prospect_activity_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/navigation_provider.dart';
import 'crm_import/crm_import_wizard_dialog.dart';

class BuyerIntelligenceScreen extends StatefulWidget {
  const BuyerIntelligenceScreen({super.key});

  @override
  State<BuyerIntelligenceScreen> createState() => _BuyerIntelligenceScreenState();
}

class _BuyerIntelligenceScreenState extends State<BuyerIntelligenceScreen> {
  int _currentPage = 1;
  final int _pageSize = 15;
  bool _showUnmaskedIc = false;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<AppStateProvider>().prospectSearchQuery,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final filteredProspects = appState.filteredProspects;
    final totalFiltered = filteredProspects.length;
    final totalPages = (totalFiltered / _pageSize).ceil().clamp(1, 9999);

    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }

    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalFiltered);
    final pageProspects = totalFiltered > 0
        ? filteredProspects.sublist(startIndex, endIndex)
        : <ProspectModel>[];

    final isFiltered = appState.prospectSearchQuery.isNotEmpty ||
        appState.prospectStatusFilter != 'All' ||
        appState.prospectEligibilityFilter != 'All' ||
        appState.prospectSourceFilter != 'All' ||
        appState.prospectVerificationFilter != 'All';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. HEADER SECTION ---
            _buildHeader(context, appState, isFiltered, totalFiltered),
            const SizedBox(height: AppTheme.spacingLg),

            // --- 2. KPI METRICS CARDS ROW ---
            _buildKpiMetricsRow(appState),
            const SizedBox(height: AppTheme.spacingLg),

            // --- 3. SEARCH AND FILTERS BAR ---
            _buildFilterBar(context, appState),
            const SizedBox(height: AppTheme.spacingMd),

            // --- 4. MAIN PROSPECT DATABASE TABLE ---
            _buildProspectTableCard(
              context,
              appState,
              pageProspects,
              totalFiltered,
              totalPages,
              startIndex,
              endIndex,
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER WIDGET ---
  Widget _buildHeader(
    BuildContext context,
    AppStateProvider appState,
    bool isFiltered,
    int totalFiltered,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    'Buyer Intelligence & Prospect Discovery',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryDark,
                        ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isFiltered
                          ? '$totalFiltered Filtered (${appState.totalProspectsCount} Total)'
                          : '${appState.totalProspectsCount} Prospects (${appState.demoProspectsCount} DEMO)',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (appState.demoProspectsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${appState.demoProspectsCount} DEMO',
                        style: const TextStyle(
                          color: AppTheme.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Top-of-funnel acquisition pipeline from Malaysian property portals, partner agencies, developer registries, and CRM imports.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _openImportCsvDialog(context, appState),
              icon: const Icon(Icons.upload_file_outlined, size: 18),
              label: const Text('Import CSV'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            if (appState.demoProspectsCount == 0)
              FilledButton.icon(
                onPressed: () async {
                  await appState.generateDemoProspects();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('15 Malaysian demo prospects with PDPA audit trails loaded.'),
                        backgroundColor: AppTheme.secondary,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text('Generate Demo Data'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: () async {
                  await appState.purgeDemoProspects();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Demo prospects removed.'),
                        backgroundColor: AppTheme.textSecondary,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: const Text('Purge Demo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.error,
                  side: const BorderSide(color: AppTheme.error),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // --- 2. KPI METRICS CARDS ROW ---
  Widget _buildKpiMetricsRow(AppStateProvider appState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final cardWidth = isNarrow
            ? (constraints.maxWidth - 16) / 2
            : (constraints.maxWidth - (16 * 4)) / 5;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildKpiCard(
              title: 'Total Prospects',
              value: '${appState.totalProspectsCount}',
              subtitle: 'Pipeline acquisition size',
              icon: Icons.groups_outlined,
              color: AppTheme.primary,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Newly Discovered',
              value: '${appState.discoveredProspectsCount}',
              subtitle: 'Top-of-funnel intake',
              icon: Icons.explore_outlined,
              color: AppTheme.info,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Verified Profiles',
              value: '${appState.verifiedProspectsCount}',
              subtitle: 'Phone / Email / ID check',
              icon: Icons.verified_user_outlined,
              color: Colors.teal,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Contact Eligible',
              value: '${appState.contactEligibleProspectsCount}',
              subtitle: 'PDPA compliant & approved',
              icon: Icons.mark_email_read_outlined,
              color: AppTheme.secondary,
              width: cardWidth,
              isHighlight: true,
            ),
            _buildKpiCard(
              title: 'Qualified Prospects',
              value: '${appState.qualifiedProspectsCount}',
              subtitle: 'Ready for CRM buyer promo',
              icon: Icons.star_border_outlined,
              color: AppTheme.accent,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
    bool isHighlight = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: isHighlight ? color.withValues(alpha: 0.5) : AppTheme.cardBorder,
          width: isHighlight ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: isHighlight ? color : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. SEARCH AND FILTERS BAR ---
  Widget _buildFilterBar(BuildContext context, AppStateProvider appState) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Search Input
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                appState.setProspectSearchQuery(val);
                setState(() => _currentPage = 1);
              },
              decoration: InputDecoration(
                hintText: 'Search by name, phone, city...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                ),
              ),
            ),
          ),

          // Status Filter
          _buildFilterDropdown(
            label: 'Status',
            value: appState.prospectStatusFilter,
            items: const ['All', 'Discovered', 'Imported', 'Verified', 'Qualified', 'Matched', 'Archived'],
            onChanged: (val) {
              if (val != null) {
                appState.setProspectStatusFilter(val);
                setState(() => _currentPage = 1);
              }
            },
          ),

          // Contact Eligibility Filter
          _buildFilterDropdown(
            label: 'Contact Eligibility',
            value: appState.prospectEligibilityFilter,
            items: const ['All', 'Eligible', 'Pending Consent', 'Ineligible', 'Do Not Contact'],
            onChanged: (val) {
              if (val != null) {
                appState.setProspectEligibilityFilter(val);
                setState(() => _currentPage = 1);
              }
            },
          ),

          // Verification Filter
          _buildFilterDropdown(
            label: 'Verification',
            value: appState.prospectVerificationFilter,
            items: const ['All', 'Unverified', 'Phone Verified', 'Email Verified', 'Identity Verified'],
            onChanged: (val) {
              if (val != null) {
                appState.setProspectVerificationFilter(val);
                setState(() => _currentPage = 1);
              }
            },
          ),

          // Primary Source Filter
          _buildFilterDropdown(
            label: 'Source',
            value: appState.prospectSourceFilter,
            items: const ['All', 'Property Portal', 'Partner Agency', 'Developer', 'CRM Import'],
            onChanged: (val) {
              if (val != null) {
                appState.setProspectSourceFilter(val);
                setState(() => _currentPage = 1);
              }
            },
          ),

          // Clear Filters
          TextButton.icon(
            onPressed: () {
              _searchController.clear();
              appState.setProspectSearchQuery('');
              appState.setProspectStatusFilter('All');
              appState.setProspectEligibilityFilter('All');
              appState.setProspectSourceFilter('All');
              appState.setProspectVerificationFilter('All');
              setState(() => _currentPage = 1);
            },
            icon: const Icon(Icons.clear_all, size: 16),
            label: const Text('Clear Filters'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              items: items.map((i) {
                return DropdownMenuItem<String>(
                  value: i,
                  child: Text(i),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  // --- 4. MAIN PROSPECT DATABASE TABLE ---
  Widget _buildProspectTableCard(
    BuildContext context,
    AppStateProvider appState,
    List<ProspectModel> pageProspects,
    int totalFiltered,
    int totalPages,
    int startIndex,
    int endIndex,
  ) {
    if (pageProspects.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            const Icon(Icons.search_off_outlined, size: 48, color: AppTheme.textHint),
            const SizedBox(height: 12),
            const Text(
              'No Prospects Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No prospects match your active search and filter criteria.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                await appState.generateDemoProspects();
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Generate Demo Data'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header & controls
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prospect Records (${totalFiltered > 0 ? startIndex + 1 : 0} - $endIndex of $totalFiltered)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    Text(
                      'Page $_currentPage of $totalPages',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _currentPage < totalPages
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Table for responsive desktop display
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppTheme.background),
              dataRowMinHeight: 64,
              dataRowMaxHeight: 64,
              horizontalMargin: 20,
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Prospect Name & ID', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Primary Source', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Lifecycle Status', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Verification', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Contact Eligibility (PDPA)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Preferences & Budget', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('AI Score', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: pageProspects.map((prospect) {
                return DataRow(
                  cells: [
                    // Name & ID
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                            child: Text(
                              prospect.fullName.isNotEmpty ? prospect.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    prospect.fullName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (prospect.isDemo) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warning.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'DEMO',
                                        style: TextStyle(
                                          color: AppTheme.warning,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${prospect.phone} • ${prospect.maskedIc}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Primary Source
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            prospect.primarySource,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          if (prospect.tags.isNotEmpty)
                            Text(
                              prospect.tags.first,
                              style: const TextStyle(fontSize: 10, color: AppTheme.textHint),
                            ),
                        ],
                      ),
                    ),

                    // Status Badge
                    DataCell(_buildStatusBadge(prospect.status)),

                    // Verification Badge
                    DataCell(_buildVerificationBadge(prospect.verificationStatus)),

                    // Contact Eligibility (Crucial!)
                    DataCell(_buildContactEligibilityBadge(prospect.contactEligibility)),

                    // Preferences & Budget
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            prospect.preferredLocations.isNotEmpty
                                ? '${prospect.preferredLocations.first}, ${prospect.preferredState}'
                                : prospect.preferredState,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'RM ${(prospect.budgetMin / 1000).toStringAsFixed(0)}k - RM ${(prospect.budgetMax / 1000).toStringAsFixed(0)}k (${prospect.propertyTypes.isNotEmpty ? prospect.propertyTypes.first : "Any"})',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),

                    // AI Score
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bolt,
                            size: 14,
                            color: prospect.confidenceScore >= 80
                                ? AppTheme.secondary
                                : (prospect.confidenceScore >= 60 ? AppTheme.accent : AppTheme.textHint),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${prospect.confidenceScore.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: prospect.confidenceScore >= 80
                                  ? AppTheme.secondary
                                  : (prospect.confidenceScore >= 60 ? AppTheme.accent : AppTheme.textHint),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Actions
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonal(
                            onPressed: () {
                              _openProspectInspector(context, appState, prospect);
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text('Inspect', style: TextStyle(fontSize: 11)),
                          ),
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (val) async {
                              if (val == 'convert') {
                                await _convertProspectToBuyer(context, appState, prospect);
                              } else if (val == 'delete') {
                                await appState.deleteProspect(prospect.id);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'convert',
                                child: Row(
                                  children: [
                                    Icon(Icons.person_add_alt, size: 16, color: AppTheme.secondary),
                                    SizedBox(width: 8),
                                    Text('Promote to Active Buyer CRM'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 16, color: AppTheme.error),
                                    SizedBox(width: 8),
                                    Text('Delete Prospect'),
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
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- BADGE BUILDERS ---
  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'Discovered':
        bg = Colors.blue.withValues(alpha: 0.12);
        fg = Colors.blue.shade800;
        break;
      case 'Imported':
        bg = Colors.purple.withValues(alpha: 0.12);
        fg = Colors.purple.shade800;
        break;
      case 'Verified':
        bg = Colors.teal.withValues(alpha: 0.12);
        fg = Colors.teal.shade800;
        break;
      case 'Qualified':
        bg = AppTheme.secondary.withValues(alpha: 0.15);
        fg = AppTheme.secondary;
        break;
      case 'Matched':
        bg = Colors.amber.withValues(alpha: 0.15);
        fg = Colors.amber.shade900;
        break;
      case 'Archived':
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildVerificationBadge(String verification) {
    Color color;
    IconData icon;
    switch (verification) {
      case 'Identity Verified':
        color = Colors.teal;
        icon = Icons.verified;
        break;
      case 'Phone Verified':
        color = Colors.blue;
        icon = Icons.phone_android;
        break;
      case 'Email Verified':
        color = Colors.indigo;
        icon = Icons.email_outlined;
        break;
      case 'Unverified':
      default:
        color = Colors.grey;
        icon = Icons.hourglass_empty;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          verification,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildContactEligibilityBadge(String eligibility) {
    Color bg;
    Color fg;
    IconData icon;
    switch (eligibility) {
      case 'Eligible':
        bg = AppTheme.secondary.withValues(alpha: 0.15);
        fg = AppTheme.secondary;
        icon = Icons.check_circle_outline;
        break;
      case 'Pending Consent':
        bg = AppTheme.warning.withValues(alpha: 0.15);
        fg = AppTheme.warning;
        icon = Icons.pending_actions_outlined;
        break;
      case 'Do Not Contact':
        bg = AppTheme.error.withValues(alpha: 0.15);
        fg = AppTheme.error;
        icon = Icons.block_outlined;
        break;
      case 'Ineligible':
      default:
        bg = Colors.grey.withValues(alpha: 0.15);
        fg = Colors.grey.shade700;
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            eligibility,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. DETAILED PROSPECT INSPECTOR DIALOG ---
  void _openProspectInspector(
    BuildContext context,
    AppStateProvider appState,
    ProspectModel prospect,
  ) {
    appState.selectProspect(prospect);
    setState(() => _showUnmaskedIc = false);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activeProspect = appState.selectedProspect ?? prospect;
            final consents = appState.selectedProspectConsents;
            final activities = appState.selectedProspectActivities;

            return Dialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820, maxHeight: 780),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacingLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Inspector Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                child: Text(
                                  activeProspect.fullName.isNotEmpty ? activeProspect.fullName[0] : '?',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        activeProspect.fullName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryDark,
                                        ),
                                      ),
                                      if (activeProspect.isDemo) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.warning.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'DEMO PROSPECT',
                                            style: TextStyle(
                                              color: AppTheme.warning,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    'ID: ${activeProspect.id} • Captured via ${activeProspect.primarySource}',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      const Divider(height: 1),
                      const SizedBox(height: AppTheme.spacingMd),

                      // Inspector Content (Scrollable)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. PDPA Contact Eligibility Notice Banner
                              _buildEligibilityBanner(context, appState, activeProspect, setDialogState),
                              const SizedBox(height: AppTheme.spacingMd),

                              // 2. Contact Information & Identity
                              _buildIdentitySection(activeProspect, setDialogState),
                              const SizedBox(height: AppTheme.spacingMd),

                              // 3. Property Requirements & Intent
                              _buildPreferencesSection(activeProspect),
                              const SizedBox(height: AppTheme.spacingMd),

                              // 4. PDPA Consent Audit Trail
                              _buildConsentAuditTrail(context, appState, activeProspect, consents),
                              const SizedBox(height: AppTheme.spacingMd),

                              // 5. Activity History Timeline
                              _buildActivityHistoryTimeline(activities),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spacingMd),
                      const Divider(height: 1),
                      const SizedBox(height: AppTheme.spacingSm),

                      // Inspector Footer Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('Lifecycle Status: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              DropdownButton<String>(
                                value: activeProspect.status,
                                isDense: true,
                                items: const ['Discovered', 'Imported', 'Verified', 'Qualified', 'Matched', 'Archived']
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (newStatus) async {
                                  if (newStatus != null) {
                                    await appState.updateProspectStatus(activeProspect.id, newStatus);
                                    setDialogState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  _openRecordConsentDialog(context, appState, activeProspect, setDialogState);
                                },
                                icon: const Icon(Icons.verified_outlined, size: 16),
                                label: const Text('Record Consent'),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: () async {
                                  Navigator.of(dialogCtx).pop();
                                  await _convertProspectToBuyer(context, appState, activeProspect);
                                },
                                icon: const Icon(Icons.person_add_alt_1, size: 16),
                                label: const Text('Convert to Active Buyer CRM'),
                                style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary),
                              ),
                            ],
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
      },
    );
  }

  Widget _buildEligibilityBanner(
    BuildContext context,
    AppStateProvider appState,
    ProspectModel prospect,
    StateSetter setDialogState,
  ) {
    Color border;
    Color bg;
    IconData icon;
    String heading;
    String explanation;

    switch (prospect.contactEligibility) {
      case 'Eligible':
        border = AppTheme.secondary;
        bg = AppTheme.secondary.withValues(alpha: 0.08);
        icon = Icons.verified_user_outlined;
        heading = 'Contact Eligible (PDPA Compliant)';
        explanation = 'Direct contact and marketing communications are authorized by recorded consent or active customer inquiry under Malaysian PDPA 2010.';
        break;
      case 'Pending Consent':
        border = AppTheme.warning;
        bg = AppTheme.warning.withValues(alpha: 0.08);
        icon = Icons.pending_actions;
        heading = 'Pending Consent (Action Required)';
        explanation = 'Imported or portal prospect records require verified opt-in consent before unsolicited outbound messaging or phone marketing.';
        break;
      case 'Do Not Contact':
        border = AppTheme.error;
        bg = AppTheme.error.withValues(alpha: 0.08);
        icon = Icons.do_not_disturb_on_outlined;
        heading = 'Do Not Contact (DNC / Opted Out)';
        explanation = 'This prospect has withdrawn consent or requested exclusion. Any unsolicited contact violates Malaysian PDPA regulations.';
        break;
      case 'Ineligible':
      default:
        border = Colors.grey;
        bg = Colors.grey.withValues(alpha: 0.08);
        icon = Icons.info_outline;
        heading = 'Contact Ineligible';
        explanation = 'Contact details are unverified or consent has not been established.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: border, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: border),
                ),
                const SizedBox(height: 4),
                Text(
                  explanation,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (prospect.contactEligibility != 'Eligible')
            TextButton(
              onPressed: () {
                _openRecordConsentDialog(context, appState, prospect, setDialogState);
              },
              child: const Text('Add Consent Event', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildIdentitySection(ProspectModel prospect, StateSetter setDialogState) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact & Identification', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _buildInfoItem('Phone', prospect.phone, Icons.phone),
              _buildInfoItem('Email', prospect.email, Icons.email),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInfoItem(
                    'NRIC / Passport',
                    _showUnmaskedIc && prospect.icNumber != null
                        ? prospect.icNumber!
                        : prospect.maskedIc,
                    Icons.badge_outlined,
                  ),
                  if (prospect.icNumber != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(_showUnmaskedIc ? Icons.visibility_off : Icons.visibility, size: 16),
                      tooltip: _showUnmaskedIc ? 'Mask NRIC' : 'Show NRIC',
                      onPressed: () {
                        setDialogState(() {
                          _showUnmaskedIc = !_showUnmaskedIc;
                        });
                      },
                    ),
                  ],
                ],
              ),
              _buildInfoItem('Verification Status', prospect.verificationStatus, Icons.shield_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(ProspectModel prospect) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Property Preferences & Intent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _buildInfoItem(
                'Preferred Locations',
                prospect.preferredLocations.isNotEmpty
                    ? '${prospect.preferredLocations.join(", ")} (${prospect.preferredState})'
                    : prospect.preferredState,
                Icons.location_on_outlined,
              ),
              _buildInfoItem(
                'Budget Range',
                'RM ${(prospect.budgetMin).toStringAsFixed(0)} - RM ${(prospect.budgetMax).toStringAsFixed(0)}',
                Icons.account_balance_wallet_outlined,
              ),
              _buildInfoItem(
                'Property Types',
                prospect.propertyTypes.join(', '),
                Icons.home_work_outlined,
              ),
              _buildInfoItem('Purchase Purpose', prospect.purchasePurpose, Icons.track_changes_outlined),
              _buildInfoItem('Timeline', prospect.buyingTimeline, Icons.access_time),
              _buildInfoItem('Bedrooms Needed', '${prospect.bedroomsNeeded}', Icons.bed_outlined),
              _buildInfoItem('AI Confidence Score', '${prospect.confidenceScore.toStringAsFixed(0)}%', Icons.bolt),
            ],
          ),
          if (prospect.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Notes: ${prospect.notes}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ],
        ),
      ],
    );
  }

  Widget _buildConsentAuditTrail(
    BuildContext context,
    AppStateProvider appState,
    ProspectModel prospect,
    List<ProspectConsentEventModel> consents,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PDPA Consent Audit Trail (Append-Only)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              '${consents.length} Event(s) Recorded',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (consents.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No PDPA consent events registered for this prospect. Please record explicit consent prior to outbound marketing.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          )
        else
          ...consents.map((consent) {
            final isGranted = consent.status == 'Granted';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isGranted ? Icons.check_circle : Icons.cancel,
                    size: 16,
                    color: isGranted ? AppTheme.secondary : AppTheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${consent.consentType} (${consent.status})',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            Text(
                              _formatDate(consent.consentTimestamp),
                              style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Source: ${consent.source} • Evidence: ${consent.evidenceText}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildActivityHistoryTimeline(List<ProspectActivityModel> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prospect Activity History',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (activities.isEmpty)
          const Text('No recorded activities.', style: TextStyle(fontSize: 12, color: AppTheme.textHint))
        else
          ...activities.map((act) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.history, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              act.title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            Text(
                              _formatDate(act.timestamp),
                              style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                            ),
                          ],
                        ),
                        if (act.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              act.description,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // --- 6. RECORD CONSENT EVENT DIALOG ---
  void _openRecordConsentDialog(
    BuildContext context,
    AppStateProvider appState,
    ProspectModel prospect,
    StateSetter parentSetState,
  ) {
    String consentType = 'Direct Inquiry Response';
    String consentStatus = 'Granted';
    String source = 'WhatsApp Written Consent';
    final evidenceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setInnerState) {
            return AlertDialog(
              title: const Text('Record PDPA Consent Event', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ensure documented evidence is available before recording explicit consent.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: consentType,
                      decoration: const InputDecoration(labelText: 'Consent Scope / Type', isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'Direct Inquiry Response', child: Text('Direct Inquiry Response')),
                        DropdownMenuItem(value: 'Marketing & Promotion', child: Text('Marketing & Promotion')),
                        DropdownMenuItem(value: 'Property Recommendations', child: Text('Property Recommendations')),
                        DropdownMenuItem(value: 'Developer Co-Broke Sharing', child: Text('Developer Co-Broke Sharing')),
                      ],
                      onChanged: (val) {
                        if (val != null) setInnerState(() => consentType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: consentStatus,
                      decoration: const InputDecoration(labelText: 'Consent Status', isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'Granted', child: Text('Granted (Eligible for contact)')),
                        DropdownMenuItem(value: 'Withdrawn', child: Text('Withdrawn (Mark Do Not Contact)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setInnerState(() => consentStatus = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: source,
                      decoration: const InputDecoration(labelText: 'Consent Source / Channel', isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'WhatsApp Written Consent', child: Text('WhatsApp Written Consent')),
                        DropdownMenuItem(value: 'Signed Showroom Registration', child: Text('Signed Showroom Registration')),
                        DropdownMenuItem(value: 'Web Form Opt-In', child: Text('Web Form Opt-In')),
                        DropdownMenuItem(value: 'Email Authorization', child: Text('Email Authorization')),
                        DropdownMenuItem(value: 'Phone Call Verbal Confirmation', child: Text('Phone Call Verbal Confirmation')),
                      ],
                      onChanged: (val) {
                        if (val != null) setInnerState(() => source = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: evidenceController,
                      decoration: const InputDecoration(
                        labelText: 'Evidence / Notes',
                        hintText: 'e.g. Chat transcript reference, registration card serial #',
                        isDense: true,
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
                FilledButton(
                  onPressed: () async {
                    final consent = ProspectConsentEventModel(
                      id: 'cst-${DateTime.now().millisecondsSinceEpoch}',
                      ownerId: prospect.ownerId,
                      prospectId: prospect.id,
                      consentType: consentType,
                      status: consentStatus,
                      source: source,
                      evidenceText: evidenceController.text.trim().isNotEmpty
                          ? evidenceController.text.trim()
                          : 'Documented consent verified by agent.',
                      consentTimestamp: DateTime.now(),
                    );
                    await appState.recordProspectConsent(consent);
                    parentSetState(() {});
                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Record Event'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 7. CRM IMPORT WIZARD DIALOG ---
  void _openImportCsvDialog(BuildContext context, AppStateProvider appState) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CRMImportWizardDialog(),
    );
  }

  // --- 8. CONVERT PROSPECT TO CRM BUYER ACTION ---
  Future<void> _convertProspectToBuyer(
    BuildContext context,
    AppStateProvider appState,
    ProspectModel prospect,
  ) async {
    final buyer = await appState.convertProspectToBuyer(prospect);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prospect "${prospect.fullName}" converted to Buyer CRM (${buyer.id}).'),
          backgroundColor: AppTheme.secondary,
          action: SnackBarAction(
            label: 'View in Buyers',
            textColor: Colors.white,
            onPressed: () {
              context.read<NavigationProvider>().navigateTo(NavItem.buyers);
            },
          ),
        ),
      );
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
