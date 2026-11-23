import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/pilot_config.dart';
import '../../models/prospect_model.dart';
import '../../models/prospect_consent_event_model.dart';
import '../../models/prospect_activity_model.dart';
import '../../models/enquiry_model.dart';
import '../../models/user_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/navigation_provider.dart';
import '../landing/agent_landing_page_screen.dart';
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
  late final TextEditingController _enquirySearchController;
  late final TextEditingController _campaignNameController;
  late final TextEditingController _campaignIdController;
  String _selectedUtmSource = 'facebook';
  String _selectedUtmMedium = 'cpc';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: context.read<AppStateProvider>().prospectSearchQuery,
    );
    _enquirySearchController = TextEditingController(
      text: context.read<AppStateProvider>().enquirySearchQuery,
    );
    _campaignNameController = TextEditingController(
      text: 'Penang Roadshow Nov 2026',
    );
    _campaignIdController = TextEditingController(
      text: 'penang-roadshow-2026',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _enquirySearchController.dispose();
    _campaignNameController.dispose();
    _campaignIdController.dispose();
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

    final showChannelB = PilotConfig.enablePlatformLeadDistribution;

    return DefaultTabController(
      length: showChannelB ? 5 : 4,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Column(
          children: [
            // Top App Bar / Title Header
            Container(
              padding: const EdgeInsets.fromLTRB(AppTheme.spacingXl, AppTheme.spacingLg, AppTheme.spacingXl, 0),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, appState, isFiltered, totalFiltered),
                  const SizedBox(height: AppTheme.spacingMd),
                  TabBar(
                    isScrollable: true,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    tabs: [
                      Tab(
                        child: Row(
                          children: [
                            const Icon(Icons.people_alt_outlined, size: 18),
                            const SizedBox(width: 8),
                            const Text('Prospect Database'),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${appState.totalProspectsCount}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          children: [
                            const Icon(Icons.move_to_inbox_outlined, size: 18),
                            const SizedBox(width: 8),
                            const Text('Incoming Enquiries (Pipeline)'),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${appState.totalEnquiriesCount}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Tab(
                        child: Row(
                          children: [
                            Icon(Icons.campaign_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Agent Landing Page & Campaigns (Channel A)'),
                          ],
                        ),
                      ),
                      if (showChannelB)
                        const Tab(
                          child: Row(
                            children: [
                              Icon(Icons.tune_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Platform Lead Preferences (Channel B)'),
                            ],
                          ),
                        ),
                      const Tab(
                        child: Row(
                          children: [
                            Icon(Icons.hub_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Sources & Integrations'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab Views Content
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Prospect Database
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spacingXl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildKpiMetricsRow(appState),
                        const SizedBox(height: AppTheme.spacingLg),
                        _buildFilterBar(context, appState),
                        const SizedBox(height: AppTheme.spacingMd),
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

                  // Tab 2: Incoming Enquiries (Pipeline)
                  _buildIncomingEnquiriesTab(context, appState),

                  // Tab 3: Agent Landing Page & Campaigns (Channel A)
                  _buildAgentLandingPageTab(context, appState),

                  // Tab 4: Platform Lead Preferences (Channel B)
                  if (showChannelB)
                    _buildPlatformLeadPreferencesTab(context, appState),

                  // Tab 5: Sources & Integrations
                  _buildSourcesAndIntegrationsTab(context, appState),
                ],
              ),
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

  // ============================================================================
  // TAB 2: INCOMING ENQUIRIES PIPELINE (PHASE 4.3)
  // ============================================================================
  Widget _buildIncomingEnquiriesTab(BuildContext context, AppStateProvider appState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sub-header with pipeline controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Multi-Source Ingestion Pipeline',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, size: 14, color: Colors.green),
                              SizedBox(width: 4),
                              Text(
                                'Live Ingestion Engine',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Real-time ingestion, Malaysian phone sanitization (+601X), duplicate suppression, and deterministic AI project matching.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => _showSimulateEnquiryDialog(context, appState),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Simulate Ingestion'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await appState.generateDemoEnquiries();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('10 multi-source demo enquiries loaded with AI recommendations.'),
                            backgroundColor: AppTheme.secondary,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Demo Leads'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.secondary,
                      side: const BorderSide(color: AppTheme.secondary),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await appState.purgeDemoEnquiries();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Demo enquiries removed.'),
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
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Enquiry KPI Cards
          _buildEnquiryKpis(appState),
          const SizedBox(height: AppTheme.spacingLg),

          // Source breakdown chips
          _buildEnquirySourceChips(appState),
          const SizedBox(height: AppTheme.spacingMd),

          // Filters bar
          _buildEnquiryFilterBar(appState),
          const SizedBox(height: AppTheme.spacingMd),

          // Enquiries Data Table
          _buildEnquiriesTableCard(context, appState),
        ],
      ),
    );
  }

  Widget _buildEnquiryKpis(AppStateProvider appState) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final cardWidth = isNarrow
            ? (constraints.maxWidth - 16) / 2
            : (constraints.maxWidth - (16 * 3)) / 4;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Dual Acquisition Channels
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard(
                  title: 'Total Inquiries',
                  value: '${appState.totalEnquiriesCount}',
                  subtitle: 'All acquisition sources',
                  icon: Icons.inbox_outlined,
                  color: AppTheme.primary,
                  width: cardWidth,
                ),
                _buildKpiCard(
                  title: 'Channel A (Agent)',
                  value: '${appState.channelAEnquiriesCount}',
                  subtitle: 'Landing page & campaigns',
                  icon: Icons.campaign_outlined,
                  color: Colors.blue.shade700,
                  width: cardWidth,
                ),
                _buildKpiCard(
                  title: 'Channel B (Platform)',
                  value: '${appState.channelBEnquiriesCount}',
                  subtitle: 'Portals & partner network',
                  icon: Icons.alt_route_outlined,
                  color: Colors.purple.shade700,
                  width: cardWidth,
                ),
                _buildKpiCard(
                  title: 'Unassigned Queue',
                  value: '${appState.unassignedEnquiriesCount}',
                  subtitle: 'No qualifying agent',
                  icon: Icons.pending_actions_outlined,
                  color: Colors.orange.shade800,
                  width: cardWidth,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Ingestion Pipeline Health
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildKpiCard(
                  title: 'AI Qualified',
                  value: '${appState.qualifiedEnquiriesCount}',
                  subtitle: 'Persisted to database',
                  icon: Icons.verified_outlined,
                  color: Colors.green,
                  width: cardWidth,
                  isHighlight: true,
                ),
                _buildKpiCard(
                  title: 'Pending Review',
                  value: '${appState.pendingEnquiriesCount}',
                  subtitle: 'Awaiting phone check',
                  icon: Icons.hourglass_top_outlined,
                  color: Colors.amber.shade800,
                  width: cardWidth,
                ),
                _buildKpiCard(
                  title: 'Duplicate Blocked',
                  value: '${appState.duplicateEnquiriesCount}',
                  subtitle: 'Suppressed & merged',
                  icon: Icons.copy_all_outlined,
                  color: Colors.indigo,
                  width: cardWidth,
                ),
                _buildKpiCard(
                  title: 'Ineligible / DNC',
                  value: '${appState.ineligibleEnquiriesCount}',
                  subtitle: 'Do Not Contact enforced',
                  icon: Icons.block_outlined,
                  color: AppTheme.error,
                  width: cardWidth,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildEnquirySourceChips(AppStateProvider appState) {
    final sources = [
      'All',
      'Property Portal',
      'Partner Agency',
      'Developer',
      'Direct Website',
      'CRM Import',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sources.map((source) {
          final isSelected = appState.enquirySourceFilter == source;
          final count = source == 'All'
              ? appState.totalEnquiriesCount
              : (appState.enquiriesBySource[source] ?? 0);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('$source ($count)'),
              selected: isSelected,
              selectedColor: AppTheme.primary.withValues(alpha: 0.15),
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 12,
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primary : AppTheme.cardBorder,
              ),
              onSelected: (_) {
                appState.setEnquirySourceFilter(source);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEnquiryFilterBar(AppStateProvider appState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _enquirySearchController,
              decoration: const InputDecoration(
                hintText: 'Search inquiries by inquirer name, contact, location, or source...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: InputBorder.none,
              ),
              onChanged: (val) {
                appState.setEnquirySearchQuery(val);
              },
            ),
          ),
          const SizedBox(width: 16),
          const Text('Channel: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: appState.enquiryChannelFilter,
              isDense: true,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Channels')),
                DropdownMenuItem(value: 'Channel A: Agent-Generated', child: Text('Channel A (Agent)')),
                DropdownMenuItem(value: 'Channel B: Platform-Generated', child: Text('Channel B (Platform)')),
              ],
              onChanged: (val) {
                if (val != null) appState.setEnquiryChannelFilter(val);
              },
            ),
          ),
          if (appState.campaignPerformance.isNotEmpty) ...[
            const SizedBox(width: 16),
            const Text('Campaign: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: appState.enquiryCampaignFilter,
                isDense: true,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                items: [
                  const DropdownMenuItem(value: 'All', child: Text('All Campaigns')),
                  ...appState.campaignPerformance.keys.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (val) {
                  if (val != null) appState.setEnquiryCampaignFilter(val);
                },
              ),
            ),
          ],
          const SizedBox(width: 16),
          const Text('Status: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: appState.enquiryStatusFilter,
              isDense: true,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                DropdownMenuItem(value: 'Qualified', child: Text('Qualified')),
                DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                DropdownMenuItem(value: 'Duplicate', child: Text('Duplicate')),
                DropdownMenuItem(value: 'Ineligible', child: Text('Ineligible')),
                DropdownMenuItem(value: 'Rejected', child: Text('Rejected')),
              ],
              onChanged: (val) {
                if (val != null) appState.setEnquiryStatusFilter(val);
              },
            ),
          ),
          if (appState.enquirySearchQuery.isNotEmpty ||
              appState.enquiryStatusFilter != 'All' ||
              appState.enquirySourceFilter != 'All' ||
              appState.enquiryChannelFilter != 'All' ||
              appState.enquiryCampaignFilter != 'All') ...[
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                _enquirySearchController.clear();
                appState.setEnquirySearchQuery('');
                appState.setEnquiryStatusFilter('All');
                appState.setEnquirySourceFilter('All');
                appState.setEnquiryChannelFilter('All');
                appState.setEnquiryCampaignFilter('All');
              },
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Reset', style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEnquiriesTableCard(BuildContext context, AppStateProvider appState) {
    final enquiries = appState.filteredEnquiries;

    if (enquiries.isEmpty) {
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
            const Icon(Icons.inbox_outlined, size: 48, color: AppTheme.textHint),
            const SizedBox(height: 12),
            const Text(
              'No Incoming Enquiries Found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'No incoming leads match the active filter. Click "Demo Leads" or "Simulate Incoming Lead" to test.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => appState.generateDemoEnquiries(),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('Generate Demo Leads'),
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
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 56,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('Date & Source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Inquirer & Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Target & Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Stage & Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('AI Match Recommendation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            DataColumn(label: Text('Audit Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: enquiries.map((enquiry) {
            Color statusColor;
            switch (enquiry.processingStatus) {
              case 'Qualified':
                statusColor = Colors.green;
                break;
              case 'Pending':
                statusColor = Colors.amber.shade800;
                break;
              case 'Duplicate':
                statusColor = Colors.purple;
                break;
              case 'Ineligible':
                statusColor = AppTheme.error;
                break;
              default:
                statusColor = AppTheme.textSecondary;
            }

            final matchScore = enquiry.matchScore ?? 0.0;
            Color matchColor = matchScore >= 80
                ? Colors.green
                : (matchScore >= 50 ? Colors.amber.shade800 : AppTheme.textSecondary);

            return DataRow(
              cells: [
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(enquiry.receivedAt),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              enquiry.sourceName,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.primary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: enquiry.isChannelA
                                  ? Colors.blue.withValues(alpha: 0.12)
                                  : (enquiry.isUnassigned ? Colors.orange.withValues(alpha: 0.12) : Colors.purple.withValues(alpha: 0.12)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              enquiry.isChannelA
                                  ? 'Channel A'
                                  : (enquiry.isUnassigned ? 'Unassigned' : 'Channel B'),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: enquiry.isChannelA
                                    ? Colors.blue.shade800
                                    : (enquiry.isUnassigned ? Colors.orange.shade900 : Colors.purple.shade800),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (enquiry.campaignId != null && enquiry.campaignId!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Campaign: ${enquiry.campaignId}',
                          style: TextStyle(fontSize: 9, color: Colors.blue.shade700, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        enquiry.fullName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                      ),
                      Text(
                        enquiry.normalizedPhone.isNotEmpty ? enquiry.normalizedPhone : enquiry.phone,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${enquiry.preferredLocation} (${enquiry.propertyType})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'RM${(enquiry.budgetMin / 1000).toInt()}k - RM${(enquiry.budgetMax / 1000).toInt()}k',
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          enquiry.processingStatus,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ),
                      if (enquiry.routingStatus.isNotEmpty && enquiry.routingStatus != 'Direct')
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            enquiry.isUnassigned
                                ? 'Unassigned Queue'
                                : 'Assigned (${enquiry.agentSuitabilityScore?.toInt() ?? 0}pts)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: enquiry.isUnassigned ? Colors.orange.shade900 : Colors.teal.shade800,
                            ),
                          ),
                        ),
                      if (enquiry.isDuplicate)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text('Duplicate Suppressed', style: TextStyle(fontSize: 10, color: Colors.purple)),
                        ),
                    ],
                  ),
                ),
                DataCell(
                  enquiry.matchedProjectName != null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: matchColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${matchScore.toInt()}% Compatibility',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: matchColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              enquiry.matchedProjectName!,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : const Text('Unmatched', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                ),
                DataCell(
                  OutlinedButton.icon(
                    onPressed: () => _showEnquiryProvenanceDialog(context, enquiry, appState),
                    icon: const Icon(Icons.analytics_outlined, size: 14),
                    label: const Text('Inspect Provenance', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEnquiryProvenanceDialog(
    BuildContext context,
    EnquiryModel enquiry,
    AppStateProvider appState,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.fingerprint, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Enquiry Provenance & Pipeline Audit: ${enquiry.fullName}'),
              ),
            ],
          ),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Discretion disclaimer banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, size: 20, color: Colors.blue),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Malaysian PDPA 2010 Notice: Contact eligibility indicates recorded legal consent status. The property agent retains 100% human discretion and control over prospect outreach. Automated robot messaging is not dispatched.',
                            style: TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stage 1
                  _buildAuditStageCard(
                    stageNumber: 1,
                    title: 'Source Validation & Authentication',
                    status: 'Passed',
                    color: Colors.green,
                    details: [
                      'Source Type: ${enquiry.sourceType}',
                      'Source Adapter: ${enquiry.sourceName}',
                      'External Reference ID: ${enquiry.sourceReferenceId ?? 'None'}',
                      'Submitted Timestamp: ${_formatDate(enquiry.enquiryTimestamp)}',
                      'Intake Timestamp: ${_formatDate(enquiry.receivedAt)}',
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stage 2
                  _buildAuditStageCard(
                    stageNumber: 2,
                    title: 'Data Normalisation & PII Sanitization',
                    status: 'Completed',
                    color: Colors.green,
                    details: [
                      'Full Name: ${enquiry.fullName}',
                      'Normalized Phone (E.164): ${enquiry.normalizedPhone.isNotEmpty ? enquiry.normalizedPhone : 'None'}',
                      'Normalized Email: ${enquiry.normalizedEmail.isNotEmpty ? enquiry.normalizedEmail : 'None'}',
                      'Target Area: ${enquiry.preferredLocation}, ${enquiry.preferredState}',
                      'Budget Window: RM${(enquiry.budgetMin / 1000).toInt()}k - RM${(enquiry.budgetMax / 1000).toInt()}k',
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stage 3
                  _buildAuditStageCard(
                    stageNumber: 3,
                    title: 'Duplicate Detection & Idempotency',
                    status: enquiry.isDuplicate ? 'Duplicate Detected' : 'Unique Record',
                    color: enquiry.isDuplicate ? Colors.purple : Colors.green,
                    details: [
                      'Is Duplicate: ${enquiry.isDuplicate ? 'YES' : 'NO'}',
                      if (enquiry.isDuplicate) 'Linked Prospect Target: ${enquiry.duplicateTargetId}',
                      'Status Reason: ${enquiry.statusReason ?? 'Unique lead verified against agent database.'}',
                      'Idempotency Guard: Safe retry prevented duplicate prospect rows.',
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stage 4
                  _buildAuditStageCard(
                    stageNumber: 4,
                    title: 'Consent & Contact Eligibility (PDPA 2010)',
                    status: enquiry.contactEligibility,
                    color: enquiry.contactEligibility == 'Eligible'
                        ? Colors.green
                        : (enquiry.contactEligibility == 'Do Not Contact' ? AppTheme.error : Colors.amber.shade800),
                    details: [
                      'Consent Status: ${enquiry.consentStatus}',
                      'Contact Eligibility: ${enquiry.contactEligibility}',
                      'Consent Evidence: ${enquiry.consentEvidence.isNotEmpty ? enquiry.consentEvidence : 'Pending documentation'}',
                      if (enquiry.isDoNotContact) 'ENFORCEMENT: Client opted out. All promotional outreach strictly suppressed.',
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stage 5
                  _buildAuditStageCard(
                    stageNumber: 5,
                    title: 'Agent Ownership Assignment & Persistence',
                    status: 'Persisted',
                    color: Colors.teal,
                    details: [
                      'Owner UID: ${enquiry.ownerId} (Multi-tenant isolated)',
                      'Created Prospect ID: ${enquiry.prospectId ?? 'N/A (Duplicate)'}',
                      'Storage Partition: Firestore /incoming_enquiries/${enquiry.id}',
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stage 6
                  _buildAuditStageCard(
                    stageNumber: 6,
                    title: 'Deterministic AI Buyer Matching & Advisory',
                    status: enquiry.matchScore != null ? '${enquiry.matchScore!.toInt()}% Match' : 'Unmatched',
                    color: AppTheme.primary,
                    details: [
                      'Matched Development: ${enquiry.matchedProjectName ?? 'None'}',
                      'Deterministic Formula: Budget (25%) + Location (25%) + Type (20%) + Purpose (15%) + Timeline (15%)',
                      'Compatibility Score: ${enquiry.matchScore != null ? '${enquiry.matchScore!.toInt()}/100' : 'N/A'}',
                      if (enquiry.aiMatchExplanation != null) 'Strategic Assessment: ${enquiry.aiMatchExplanation}',
                      if (enquiry.suggestedNextAction != null) 'Agent Advisory Action: ${enquiry.suggestedNextAction}',
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close Audit View'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAuditStageCard({
    required int stageNumber,
    required String title,
    required String status,
    required Color color,
    required List<String> details,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      '$stageNumber',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...details.map((d) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $d',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showSimulateEnquiryDialog(BuildContext context, AppStateProvider appState) {
    String sourceType = 'Property Portal';
    final nameCtrl = TextEditingController(text: 'Siti Nurhaliza binti Tarudin');
    final phoneCtrl = TextEditingController(text: '012-9876543');
    final emailCtrl = TextEditingController(text: 'siti.nurhaliza@malaysia.my');
    final locCtrl = TextEditingController(text: 'Batu Kawan');
    final budgetMinCtrl = TextEditingController(text: '450000');
    final budgetMaxCtrl = TextEditingController(text: '600000');
    bool pdpaConsent = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setInnerState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.bolt, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Simulate Incoming Lead Webhook'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trigger an immediate multi-source lead ingestion run to verify normalization, duplicate detection, and deterministic matching.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: sourceType,
                        decoration: const InputDecoration(labelText: 'Acquisition Source Channel', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'Property Portal', child: Text('Property Portal (iProperty / PropertyGuru)')),
                          DropdownMenuItem(value: 'Partner Agency', child: Text('Partner Agency (MIEA Co-Broke)')),
                          DropdownMenuItem(value: 'Developer', child: Text('Developer (Showroom Registration Slip)')),
                          DropdownMenuItem(value: 'Direct Website', child: Text('Direct Website (Personal Landing Page)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setInnerState(() => sourceType = val);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Full Name', isDense: true),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: phoneCtrl,
                              decoration: const InputDecoration(labelText: 'Malaysian Phone', hintText: '01X-XXXXXXX', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: emailCtrl,
                              decoration: const InputDecoration(labelText: 'Email Address', isDense: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: locCtrl,
                              decoration: const InputDecoration(labelText: 'Preferred Location', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: budgetMinCtrl,
                              decoration: const InputDecoration(labelText: 'Budget Min (RM)', isDense: true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: budgetMaxCtrl,
                              decoration: const InputDecoration(labelText: 'Budget Max (RM)', isDense: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: pdpaConsent,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('PDPA 2010 Consent Checkbox Checked', style: TextStyle(fontSize: 12)),
                        onChanged: (val) => setInnerState(() => pdpaConsent = val ?? false),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final payload = {
                      'name': nameCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'email': emailCtrl.text.trim(),
                      'location': locCtrl.text.trim(),
                      'budgetMin': double.tryParse(budgetMinCtrl.text.trim()) ?? 450000.0,
                      'budgetMax': double.tryParse(budgetMaxCtrl.text.trim()) ?? 600000.0,
                      'pdpa_consent': pdpaConsent,
                      'consentEvidence': pdpaConsent ? 'Simulated Webhook Intake ($sourceType)' : '',
                      'contactEligibility': pdpaConsent ? 'Eligible' : 'Pending Consent',
                    };

                    final result = await appState.ingestLeadEnquiry(
                      sourceType: sourceType,
                      rawPayload: payload,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ingestion complete! Status: ${result.enquiry.processingStatus}. Match: ${result.matchScore?.toInt() ?? 0}%.',
                          ),
                          backgroundColor: result.isDuplicate ? Colors.purple : AppTheme.secondary,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_outlined, size: 16),
                  label: const Text('Execute Pipeline Ingestion'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // TAB 3: AGENT LANDING PAGE & CAMPAIGNS (CHANNEL A)
  // ============================================================================
  Widget _buildAgentLandingPageTab(BuildContext context, AppStateProvider appState) {
    final user = appState.currentUserProfile ??
        UserModel(
          ownerId: appState.currentOwnerId,
          fullName: 'Alex Tan',
          email: 'alex.tan@propmatch.ai',
          agencyName: 'PropMatch Realty Sdn Bhd',
          renNumber: 'REN 12345',
          isRenVerified: true,
          landingPageSlug: 'alex-tan-penang',
          bio: 'Senior Real Estate Negotiator specializing in Penang & Northern corridor developments.',
        );

    final slug = user.landingPageSlug.isNotEmpty ? user.landingPageSlug : 'agent-${user.ownerId}';
    final baseUrl = 'https://propmatch.ai/agent/$slug';
    final currentCampaignId = _campaignIdController.text.trim();
    final trackedUrl = currentCampaignId.isNotEmpty
        ? '$baseUrl?utm_source=$_selectedUtmSource&utm_medium=$_selectedUtmMedium&campaign_id=$currentCampaignId'
        : baseUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Agent-Generated Buyer Acquisition (Channel A)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'Channel A: Active',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Attract buyers through your personal branded landing page, social ad campaigns, QR code flyers, and direct referrals. All leads route directly into your private database.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AgentLandingPageScreen(agent: user),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Preview Landing Page'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Cards Row / Grid
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final colWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  // Card 1: Agent REN Profile & Licensing Credentials
                  SizedBox(
                    width: colWidth,
                    child: Container(
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
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                                child: Text(
                                  user.fullName.isNotEmpty ? user.fullName[0] : 'A',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryDark),
                                    ),
                                    Text(
                                      user.agencyName.isNotEmpty ? user.agencyName : 'Licensed Real Estate Agency',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: user.isRenVerified
                                      ? Colors.green.withValues(alpha: 0.12)
                                      : Colors.amber.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: user.isRenVerified
                                        ? Colors.green.withValues(alpha: 0.3)
                                        : Colors.amber.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      user.isRenVerified ? Icons.verified : Icons.warning_amber_rounded,
                                      size: 14,
                                      color: user.isRenVerified ? Colors.green.shade800 : Colors.amber.shade900,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.isRenVerified ? 'Verified REN' : 'Unverified REN',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: user.isRenVerified ? Colors.green.shade800 : Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('REN License Number:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                    Text(
                                      user.renNumber.isNotEmpty ? user.renNumber : 'Not Provided',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                                    ),
                                  ],
                                ),
                                const Divider(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Regulatory Validation:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                    Text(
                                      user.isRenVerified ? 'LPPEH / BOVAEP Validated' : 'Pending Verification',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: user.isRenVerified ? Colors.green.shade800 : Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            user.isRenVerified
                                ? 'Your REN credentials are valid and display a trusted "Verified REN" badge to consumers visiting your landing page.'
                                : 'Notice: Unverified credentials will display an "(Unverified)" indicator to prospective buyers in compliance with Board advertising guidelines.',
                            style: TextStyle(fontSize: 11, color: user.isRenVerified ? Colors.teal : Colors.amber.shade900, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card 2: Personal Public Landing Page Link
                  SizedBox(
                    width: colWidth,
                    child: Container(
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Personal Public URL',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Direct 1:1 Routing', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Share your public link in WhatsApp bios, business cards, social media profiles, and property brochures:',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.link, size: 18, color: AppTheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SelectableText(
                                    baseUrl,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 16, color: AppTheme.textSecondary),
                                  tooltip: 'Copy Link',
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: baseUrl));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Landing page URL copied to clipboard!'),
                                        backgroundColor: AppTheme.primary,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AgentLandingPageScreen(agent: user),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.open_in_new, size: 14),
                                label: const Text('Open Page', style: TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: baseUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Landing page URL copied!'),
                                      backgroundColor: AppTheme.primary,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.share, size: 14),
                                label: const Text('Copy Link', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card 3: Campaign Link Builder & UTM Generator
                  SizedBox(
                    width: colWidth,
                    child: Container(
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Campaign Link Builder (UTM)',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Attribution Engine', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Generate tracked URLs with UTM parameters to measure lead sources from ads, social media, and flyers:',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedUtmSource,
                                  decoration: const InputDecoration(
                                    labelText: 'UTM Source',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                  items: const [
                                    DropdownMenuItem(value: 'facebook', child: Text('Facebook Ads')),
                                    DropdownMenuItem(value: 'instagram', child: Text('Instagram Ads')),
                                    DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp Blast')),
                                    DropdownMenuItem(value: 'google', child: Text('Google Search / Display')),
                                    DropdownMenuItem(value: 'tiktok', child: Text('TikTok Ads')),
                                    DropdownMenuItem(value: 'qr_flyer', child: Text('Printed QR Flyer')),
                                    DropdownMenuItem(value: 'referral', child: Text('Client Referral')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedUtmSource = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedUtmMedium,
                                  decoration: const InputDecoration(
                                    labelText: 'UTM Medium',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                                  items: const [
                                    DropdownMenuItem(value: 'cpc', child: Text('cpc (Paid Click)')),
                                    DropdownMenuItem(value: 'social', child: Text('social (Organic)')),
                                    DropdownMenuItem(value: 'chat', child: Text('chat (Direct)')),
                                    DropdownMenuItem(value: 'print_flyer', child: Text('print_flyer (Offline)')),
                                    DropdownMenuItem(value: 'email', child: Text('email (Newsletter)')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedUtmMedium = val);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _campaignIdController,
                            decoration: const InputDecoration(
                              labelText: 'Campaign ID / Tag',
                              hintText: 'e.g. penang-roadshow-2026',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(fontSize: 12),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Tracked URL Output:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                SelectableText(
                                  trackedUrl,
                                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppTheme.primaryDark),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: trackedUrl));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Tracked Campaign URL copied!'),
                                  backgroundColor: AppTheme.primary,
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copy Tracked URL'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card 4: Channel A Campaign Performance
                  SizedBox(
                    width: colWidth,
                    child: Container(
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Campaign Attribution & Stats',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${appState.campaignPerformance.length} Active Tags',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (appState.campaignPerformance.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              alignment: Alignment.center,
                              child: const Column(
                                children: [
                                  Icon(Icons.query_stats, size: 36, color: AppTheme.textHint),
                                  SizedBox(height: 8),
                                  Text(
                                    'No Campaign Enquiries Yet',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Create a campaign link above and share it with prospective buyers to start tracking results.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                                  ),
                                ],
                              ),
                            )
                          else
                            Table(
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(1),
                                2: FlexColumnWidth(1),
                              },
                              children: [
                                const TableRow(
                                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.cardBorder))),
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: 6),
                                      child: Text('Campaign ID', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: 6),
                                      child: Text('Enquiries', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: 6),
                                      child: Text('Channel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                ...appState.campaignPerformance.entries.map(
                                  (e) => TableRow(
                                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.cardBorder))),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 6),
                                        child: Text('${e.value}', style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 6),
                                        child: Text('Channel A', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.gavel_outlined, size: 16, color: Colors.blue),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Malaysian PDPA Notice: Landing page enforces separate checkboxes for enquiry response vs optional future marketing opt-ins.',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 4: PLATFORM LEAD PREFERENCES (CHANNEL B)
  // ============================================================================
  Widget _buildPlatformLeadPreferencesTab(BuildContext context, AppStateProvider appState) {
    final prefs = appState.agentPreferences;
    final subscription = appState.agentSubscription;
    final usedQuota = prefs.leadsReceivedThisMonth;
    final maxQuota = prefs.monthlyLeadQuota;
    final quotaFraction = (usedQuota / (maxQuota > 0 ? maxQuota : 1)).clamp(0.0, 1.0);

    final allLocations = [
      'Batu Kawan',
      'George Town',
      'Bayan Lepas',
      'Tanjung Tokong',
      'Mont Kiara',
      'KLCC',
      'Subang Jaya',
      'Petaling Jaya',
      'Penang',
    ];

    final allPropertyTypes = [
      'Condominium',
      'Serviced Residence',
      'Terrace House',
      'Semi-D',
      'Bungalow',
      'Commercial',
    ];

    final allSpecializations = [
      'First-time Homebuyer',
      'High-Rise Residential',
      'Own Stay',
      'Property Investor',
      'Expat / MM2H',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Platform-Generated Buyer Acquisition (Channel B)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: prefs.isAvailableForPlatformLeads
                                ? Colors.purple.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: prefs.isAvailableForPlatformLeads
                                  ? Colors.purple.withValues(alpha: 0.3)
                                  : Colors.grey.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            prefs.isAvailableForPlatformLeads ? 'Channel B: Opted In' : 'Channel B: Paused',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: prefs.isAvailableForPlatformLeads ? Colors.purple.shade800 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Receive high-intent buyer enquiries sourced from authorized property portals, partner developers, and co-broke networks. Distributed via deterministic transparent routing.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Cards Row / Grid
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final colWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  // Card 1: Opt-in Toggle & Quota Tracker
                  SizedBox(
                    width: colWidth,
                    child: Container(
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Lead Distribution Opt-In',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                              ),
                              Switch(
                                value: prefs.isAvailableForPlatformLeads,
                                activeThumbColor: AppTheme.primary,
                                onChanged: (val) async {
                                  await appState.updateAgentPreferences(
                                    prefs.copyWith(isAvailableForPlatformLeads: val),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          val
                                              ? 'Opted in to platform lead distribution.'
                                              : 'Paused platform lead distribution.',
                                        ),
                                        backgroundColor: val ? AppTheme.secondary : AppTheme.textSecondary,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                          Text(
                            prefs.isAvailableForPlatformLeads
                                ? 'Active: The intelligent routing engine considers your profile when incoming portal and partner leads arrive.'
                                : 'Paused: You will not receive platform-distributed leads until re-enabled.',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),

                          // Subscription Tier & Quota
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Active Plan Tier', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  Text(
                                    subscription.tier,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  subscription.status.toUpperCase(),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Monthly Quota Usage:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              Text(
                                '$usedQuota / $maxQuota Leads',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: quotaFraction,
                              minHeight: 8,
                              backgroundColor: AppTheme.background,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                quotaFraction >= 0.9 ? AppTheme.error : AppTheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Data Ownership Guarantee Callout
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.shield_outlined, size: 18, color: Colors.teal),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Complete Data Ownership Guarantee: Platform leads distributed to you become your permanent property in your isolated database. Changing plans or canceling never revokes access to acquired prospects.',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card 2: Transparent Routing Engine Rules
                  SizedBox(
                    width: colWidth,
                    child: Container(
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
                              const Icon(Icons.psychology_outlined, size: 18, color: AppTheme.primary),
                              const SizedBox(width: 8),
                              const Text(
                                'Deterministic Routing Algorithm',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'PropMatch AI scores agent suitability deterministically out of 100 points based on four transparent criteria:',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          _buildRoutingFactorRow(
                            score: '40 pts',
                            title: 'Geographic Location Match',
                            desc: 'Matches enquiry target location against your registered active focus areas.',
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          _buildRoutingFactorRow(
                            score: '30 pts',
                            title: 'Property Type Specialization',
                            desc: 'Overlaps enquiry property classification with your selected expertise.',
                            color: Colors.teal,
                          ),
                          const SizedBox(height: 8),
                          _buildRoutingFactorRow(
                            score: '20 pts',
                            title: 'Budget Window Overlap',
                            desc: 'Buyer budget ceiling intersects within your configured price range.',
                            color: Colors.purple,
                          ),
                          const SizedBox(height: 8),
                          _buildRoutingFactorRow(
                            score: '10 pts',
                            title: 'Fair Capacity Rotation',
                            desc: 'Rotating tie-breaker prioritizing active agents with fewer leads this period.',
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.lock_outline, size: 14, color: AppTheme.textSecondary),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Zero Shared Pool: Distributed leads belong to exactly ONE agent. Leads without matching agents enter the secure Unassigned Queue without PII exposure.',
                                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Card 3: Preferred Locations & Property Types Configuration
                  SizedBox(
                    width: constraints.maxWidth,
                    child: Container(
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Agent Routing Preferences & Specializations',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                              ),
                              FilledButton.icon(
                                onPressed: () async {
                                  await appState.updateAgentPreferences(prefs);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Preferences saved successfully!'),
                                        backgroundColor: AppTheme.secondary,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.save_outlined, size: 16),
                                label: const Text('Save Preferences'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Preferred Locations
                          const Text('Focus Geographic Areas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allLocations.map((loc) {
                              final isSelected = prefs.preferredLocations.contains(loc);
                              return FilterChip(
                                label: Text(loc),
                                selected: isSelected,
                                selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                                ),
                                onSelected: (selected) {
                                  final newLocs = List<String>.from(prefs.preferredLocations);
                                  if (selected) {
                                    newLocs.add(loc);
                                  } else {
                                    newLocs.remove(loc);
                                  }
                                  appState.updateAgentPreferences(prefs.copyWith(preferredLocations: newLocs));
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Preferred Property Types
                          const Text('Target Property Classes:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allPropertyTypes.map((type) {
                              final isSelected = prefs.preferredPropertyTypes.contains(type);
                              return FilterChip(
                                label: Text(type),
                                selected: isSelected,
                                selectedColor: Colors.teal.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.teal.shade800 : AppTheme.textPrimary,
                                ),
                                onSelected: (selected) {
                                  final newTypes = List<String>.from(prefs.preferredPropertyTypes);
                                  if (selected) {
                                    newTypes.add(type);
                                  } else {
                                    newTypes.remove(type);
                                  }
                                  appState.updateAgentPreferences(prefs.copyWith(preferredPropertyTypes: newTypes));
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // Target Price Range
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Target Price Range:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(
                                'RM${(prefs.priceRangeMin / 1000).toInt()}k - RM${(prefs.priceRangeMax / 1000).toInt()}k',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primary),
                              ),
                            ],
                          ),
                          RangeSlider(
                            values: RangeValues(prefs.priceRangeMin, prefs.priceRangeMax),
                            min: 200000.0,
                            max: 3000000.0,
                            divisions: 28,
                            labels: RangeLabels(
                              'RM${(prefs.priceRangeMin / 1000).toInt()}k',
                              'RM${(prefs.priceRangeMax / 1000).toInt()}k',
                            ),
                            onChanged: (values) {
                              appState.updateAgentPreferences(
                                prefs.copyWith(priceRangeMin: values.start, priceRangeMax: values.end),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Specializations
                          const Text('Agent Specializations:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allSpecializations.map((spec) {
                              final isSelected = prefs.specializations.contains(spec);
                              return FilterChip(
                                label: Text(spec),
                                selected: isSelected,
                                selectedColor: Colors.purple.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.purple.shade800 : AppTheme.textPrimary,
                                ),
                                onSelected: (selected) {
                                  final newSpecs = List<String>.from(prefs.specializations);
                                  if (selected) {
                                    newSpecs.add(spec);
                                  } else {
                                    newSpecs.remove(spec);
                                  }
                                  appState.updateAgentPreferences(prefs.copyWith(specializations: newSpecs));
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRoutingFactorRow({
    required String score,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            score,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
              Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // TAB 5: SOURCES & INTEGRATIONS
  // ============================================================================
  Widget _buildSourcesAndIntegrationsTab(BuildContext context, AppStateProvider appState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Supported Lead Ingestion Integrations',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryDark,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '5 Active Protocols',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'PropMatch AI connects Malaysian property agents to authorized acquisition channels without scraping or terms-of-service violations.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Cards grid
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final itemWidth = isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildIntegrationCard(
                    title: 'Property Portals (iProperty & PropertyGuru)',
                    category: 'Portal Integration',
                    status: 'Active / Authorized Listener',
                    protocol: 'Inbound Webhook & Nightly Export CSV Parser',
                    description: 'Processes structured buyer enquiries submitted on agent portal listings. Zero scraping is performed; operates via authorized webhook listeners or agent-exported files.',
                    complianceRule: 'Preserves portal listing ID, timestamps, and portal-supplied consent notices.',
                    icon: Icons.apartment_outlined,
                    color: AppTheme.primary,
                    width: itemWidth,
                  ),
                  _buildIntegrationCard(
                    title: 'Partner Agencies (MIEA Co-Broke Network)',
                    category: 'Co-Broke Referrals',
                    status: 'Active',
                    protocol: 'Standardized Co-Broke Schema Exchange',
                    description: 'Allows reciprocal lead sharing between Malaysian licensed real estate negotiators (RENs) with automatic 50/50 fee split record keeping.',
                    complianceRule: 'Requires referring REN registration number and client representation agreement reference.',
                    icon: Icons.handshake_outlined,
                    color: Colors.teal,
                    width: itemWidth,
                  ),
                  _buildIntegrationCard(
                    title: 'Property Developers (Showroom & Sales Desk)',
                    category: 'Direct Developer Desk',
                    status: 'Active',
                    protocol: 'QR Digital Registration Slip & Sales Desk Sync',
                    description: 'Digitizes walk-in visitors and sales gallery registrations at EXSIM, EcoWorld, E&O, and other developer launches.',
                    complianceRule: 'Uploads timestamped physical or tablet signature records directly into the PDPA audit vault.',
                    icon: Icons.domain_outlined,
                    color: Colors.indigo,
                    width: itemWidth,
                  ),
                  _buildIntegrationCard(
                    title: 'Direct Website & Personal Landing Page',
                    category: 'Agent Owned Webform',
                    status: 'Active',
                    protocol: 'Embeddable Webform with Honeypot Trap',
                    description: 'Captures direct voluntary inquiries from agent landing pages and social media ads with built-in anti-spam bot protection.',
                    complianceRule: 'Mandatory un-ticked PDPA consent checkbox and timestamped client IP address capture.',
                    icon: Icons.language_outlined,
                    color: Colors.blue.shade700,
                    width: itemWidth,
                  ),
                  _buildIntegrationCard(
                    title: 'CRM Import Engine (CSV & Excel)',
                    category: 'Batch Migration',
                    status: 'Active / 5MB Verified',
                    protocol: 'High-speed streaming parser with column mapper',
                    description: 'Empowers agents to bring existing client databases from spreadsheets, past agency CRMs, and contact archives.',
                    complianceRule: 'Pre-flight MIME validation, fuzzy header detection, and automated duplicate prevention.',
                    icon: Icons.upload_file_outlined,
                    color: AppTheme.secondary,
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrationCard({
    required String title,
    required String category,
    required String status,
    required String protocol,
    required String description,
    required String complianceRule,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Text(
                  status,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.settings_input_component, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Protocol: $protocol',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_outlined, size: 14, color: Colors.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'PDPA Guard: $complianceRule',
                        style: const TextStyle(fontSize: 11, color: Colors.teal, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
