import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/buyer_model.dart';
import '../../models/consent_record_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/navigation_provider.dart';

class BuyersScreen extends StatefulWidget {
  const BuyersScreen({super.key});

  @override
  State<BuyersScreen> createState() => _BuyersScreenState();
}

class _BuyersScreenState extends State<BuyersScreen> {
  int _currentPage = 1;
  int _pageSize = 25;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final nav = context.read<NavigationProvider>();

    final filteredBuyers = appState.buyers;
    final totalFiltered = filteredBuyers.length;
    final totalPages = (totalFiltered / _pageSize).ceil().clamp(1, 9999);

    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }

    final startIndex = (_currentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalFiltered);
    final pageBuyers = totalFiltered > 0
        ? filteredBuyers.sublist(startIndex, endIndex)
        : <BuyerModel>[];

    final isFiltered = appState.buyerSearchQuery.isNotEmpty || appState.buyerStatusFilter != 'All';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title, Count Badges, and Generator Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          'Buyer Directory & Database',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
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
                                ? '$totalFiltered Filtered (${appState.totalBuyerCount} Total Registered)'
                                : '${appState.totalBuyerCount} Profiles (${appState.demoBuyerCount} DEMO)',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (appState.demoBuyerCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${appState.demoBuyerCount} DEMO',
                              style: const TextStyle(
                                color: AppTheme.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isFiltered
                          ? 'Showing $totalFiltered search matches out of ${appState.totalBuyerCount} total registered buyer records.'
                          : 'Search, filter, and inspect prospective buyers across Penang, Kedah, and central states.',
                      style: const TextStyle(color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),

              // Action buttons
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _showAddBuyerDialog(context, appState),
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Register Real Buyer'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: () {
                      appState.generate100DemoBuyers();
                      setState(() => _currentPage = 1);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Successfully loaded 100 Fictional Demo Buyer Profiles!'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                    },
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: Text(
                      appState.hasGeneratedDemoBuyers
                          ? 'Regenerate 100 Demo Buyers'
                          : 'Generate 100 Demo Buyers',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Search and Filters Bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Row(
                children: [
                  // Search Input
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by buyer name, location (e.g. Batu Kawan, Kulim), or property type...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        setState(() => _currentPage = 1);
                        appState.setBuyerSearchQuery(val);
                      },
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMd),

                  // Status Filter Dropdown
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: appState.buyerStatusFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Filter Status',
                        isDense: true,
                      ),
                      items: ['All', 'New', 'Contacted', 'Interested', 'Viewing Scheduled', 'Negotiating']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _currentPage = 1);
                          appState.setBuyerStatusFilter(val);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Buyers Table
          if (filteredBuyers.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_search_outlined, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    isFiltered ? 'No Buyers Matching Filters' : 'No Buyers Registered Yet',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFiltered
                        ? 'Try clearing the search query or status filter.'
                        : 'Register your real prospective property buyers or load sample test profiles.',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showAddBuyerDialog(context, appState),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Register Real Buyer'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          appState.generate100DemoBuyers();
                          setState(() => _currentPage = 1);
                        },
                        icon: const Icon(Icons.bolt, size: 18),
                        label: const Text('Load 100 Sample Test Buyers'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Card(
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(AppTheme.background),
                      horizontalMargin: 20,
                      columnSpacing: 24,
                      columns: const [
                        DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Buyer Name', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Budget Range', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Location & State', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Property Type', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Purpose', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Timeline', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.w700))),
                      ],
                      rows: pageBuyers.map((buyer) {
                        return DataRow(
                          cells: [
                            DataCell(Text(buyer.id.substring(buyer.id.length - 7), style: const TextStyle(fontSize: 11, color: AppTheme.textHint))),
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        buyer.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (buyer.isDemo) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                              ),
                            ),
                            DataCell(Text('RM${buyer.budgetMin.toStringAsFixed(0)} - RM${buyer.budgetMax.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12))),
                            DataCell(Text('${buyer.preferredLocation}, ${buyer.preferredState}', style: const TextStyle(fontSize: 12))),
                            DataCell(Text(buyer.propertyType, style: const TextStyle(fontSize: 12))),
                            DataCell(Text(buyer.purchasePurpose, style: const TextStyle(fontSize: 12))),
                            DataCell(Text(buyer.buyingTimeline, style: const TextStyle(fontSize: 12))),
                            DataCell(_buildStatusChip(buyer.status)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.info_outline, size: 18),
                                    tooltip: 'Inspect Profile',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () => _showBuyerDetailModal(context, buyer),
                                  ),
                                  const SizedBox(width: 10),
                                  IconButton(
                                    icon: const Icon(Icons.compare_arrows, size: 18, color: AppTheme.primary),
                                    tooltip: 'Match with Project',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      nav.navigateTo(NavItem.matching);
                                      appState.runBuyerMatching();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  // Pagination Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppTheme.cardBorder)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          totalFiltered > 0
                              ? 'Showing ${startIndex + 1}–$endIndex of $totalFiltered buyer records'
                              : 'Showing 0 records',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                        Row(
                          children: [
                            const Text('Rows: ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            DropdownButton<int>(
                              value: _pageSize,
                              isDense: true,
                              underline: const SizedBox.shrink(),
                              items: [15, 25, 50, 100].map((s) {
                                return DropdownMenuItem(value: s, child: Text('$s', style: const TextStyle(fontSize: 12)));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _pageSize = val;
                                    _currentPage = 1;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Page $_currentPage of $totalPages',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                              tooltip: 'Previous Page',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chevron_right, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                              tooltip: 'Next Page',
                            ),
                          ],
                        ),
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

  Widget _buildStatusChip(String status) {
    Color color = AppTheme.primary;
    if (status == 'Interested' || status == 'Viewing Scheduled') color = AppTheme.success;
    if (status == 'Contacted') color = AppTheme.info;
    if (status == 'Negotiating') color = AppTheme.accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  void _showAddBuyerDialog(BuildContext context, AppStateProvider appState) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final budgetMinCtrl = TextEditingController(text: '450000');
    final budgetMaxCtrl = TextEditingController(text: '650000');
    final locCtrl = TextEditingController(text: 'Batu Kawan');
    final notesCtrl = TextEditingController();
    String stateVal = 'Penang';
    String propTypeVal = 'Condominium';
    String purposeVal = 'Own Stay';
    String timelineVal = 'Within 3 months';
    bool consentEnquiry = false; // Unchecked by default for explicit affirmative consent
    bool consentMarketing = false; // Unchecked by default (OPTIONAL)
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Real Buyer Record', style: TextStyle(fontWeight: FontWeight.w700)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (errorMsg != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(errorMsg!, style: const TextStyle(color: AppTheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Buyer Name *', hintText: 'e.g. Jason Lim'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email Address', hintText: 'e.g. jason@example.com'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone Number', hintText: 'e.g. +6012-3456789'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: budgetMinCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Budget (RM) *'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: budgetMaxCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max Budget (RM) *'),
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
                          decoration: const InputDecoration(labelText: 'Preferred Location *', hintText: 'e.g. Batu Kawan'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: stateVal,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Preferred State *'),
                          items: AppConstants.malaysianStates.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setDialogState(() => stateVal = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: propTypeVal,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Property Type *'),
                          items: AppConstants.propertyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setDialogState(() => propTypeVal = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: purposeVal,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Purpose *'),
                          items: AppConstants.propertyPurposes.map((p) => DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setDialogState(() => purposeVal = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: timelineVal,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Buying Timeline *'),
                    items: ['Immediate (1 month)', 'Within 3 months', 'Within 6 months', 'Future investor (1 year+)'].map((tl) => DropdownMenuItem(value: tl, child: Text(tl))).toList(),
                    onChanged: (v) => setDialogState(() => timelineVal = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Consultation Notes', hintText: 'Specific requirements, preferred layout, downpayment readiness...'),
                  ),
                  const SizedBox(height: 16),
                  // PDPA Consent Configuration Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 16, color: AppTheme.primary),
                            SizedBox(width: 6),
                            Text(
                              'PDPA Data Protection & Consent Settings',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: consentEnquiry,
                          onChanged: (v) => setDialogState(() => consentEnquiry = v ?? false),
                          title: const Text(
                            'Consent to Respond to Enquiry',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          subtitle: const Text(
                            'Buyer agrees to be contacted regarding this property enquiry via phone, email, or WhatsApp.',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ),
                        const Divider(height: 12),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: consentMarketing,
                          onChanged: (v) => setDialogState(() => consentMarketing = v ?? false),
                          title: const Text(
                            'Marketing Communication Consent (Optional)',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          subtitle: const Text(
                            'Buyer opts in to receive promotional updates, new project launches, and event invitations. (Can be withdrawn anytime)',
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
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final loc = locCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(() => errorMsg = 'Buyer name is required.');
                  return;
                }
                if (loc.isEmpty) {
                  setDialogState(() => errorMsg = 'Preferred location is required.');
                  return;
                }
                final minBudget = double.tryParse(budgetMinCtrl.text);
                final maxBudget = double.tryParse(budgetMaxCtrl.text);
                if (minBudget == null || minBudget <= 0) {
                  setDialogState(() => errorMsg = 'Minimum budget must be a positive number.');
                  return;
                }
                if (maxBudget == null || maxBudget <= 0) {
                  setDialogState(() => errorMsg = 'Maximum budget must be a positive number.');
                  return;
                }
                if (minBudget > maxBudget) {
                  setDialogState(() => errorMsg = 'Minimum budget cannot exceed Maximum budget.');
                  return;
                }

                final newBuyer = BuyerModel(
                  ownerId: appState.currentOwnerId,
                  name: name,
                  email: emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  budgetMin: minBudget,
                  budgetMax: maxBudget,
                  preferredLocation: loc,
                  preferredState: stateVal,
                  propertyType: propTypeVal,
                  purchasePurpose: purposeVal,
                  buyingTimeline: timelineVal,
                  leadSource: 'Agent Direct Registration',
                  notes: notesCtrl.text.trim().isEmpty ? 'Voluntary buyer registration' : notesCtrl.text.trim(),
                  status: 'New',
                  isDemo: false, // Genuine buyer profile
                );

                appState.addBuyer(newBuyer);

                // Store PDPA consent records separately from buyer profile
                if (consentEnquiry) {
                  appState.recordConsent(ConsentRecordModel(
                    ownerId: appState.currentOwnerId,
                    buyerId: newBuyer.id,
                    consentType: 'enquiry_response',
                    consentStatus: 'granted',
                    consentSource: 'Agent Direct Registration',
                    consentTimestamp: DateTime.now(),
                  ));
                }

                if (consentMarketing) {
                  appState.recordConsent(ConsentRecordModel(
                    ownerId: appState.currentOwnerId,
                    buyerId: newBuyer.id,
                    consentType: 'marketing_communication',
                    consentStatus: 'granted',
                    consentSource: 'Agent Direct Registration',
                    consentTimestamp: DateTime.now(),
                  ));
                }

                Navigator.of(ctx).pop();
                setState(() => _currentPage = 1);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Registered buyer: ${newBuyer.name}!')),
                );
              },
              child: const Text('Register Buyer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBuyerDetailModal(BuildContext context, BuyerModel buyer) {
    final appState = context.read<AppStateProvider>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final hasEnquiry = appState.hasEnquiryConsent(buyer.id);
          final hasMarketing = appState.hasActiveMarketingConsent(buyer.id);
          final consentHistory = appState.getConsentsForBuyer(buyer.id);

          return AlertDialog(
            title: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppTheme.primary,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(buyer.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      if (buyer.isDemo)
                        const Text('DEMO DATA • Synthetic Profile for Verification', style: TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.bold))
                      else
                        const Text('GENUINE RECORD • Real Registered Buyer', style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (buyer.email.isNotEmpty) _detailRow('Email Address', buyer.email),
                    if (buyer.phone.isNotEmpty) _detailRow('Phone Number', buyer.phone),
                    _detailRow('Preferred Location', '${buyer.preferredLocation}, ${buyer.preferredState}'),
                    _detailRow('Budget Range', 'RM${buyer.budgetMin.toStringAsFixed(0)} - RM${buyer.budgetMax.toStringAsFixed(0)}'),
                    _detailRow('Property Type', buyer.propertyType),
                    _detailRow('Purchase Purpose', buyer.purchasePurpose),
                    _detailRow('Buying Timeline', buyer.buyingTimeline),
                    _detailRow('Lead Source', buyer.leadSource),
                    _detailRow('Assigned Audience Segment', buyer.audienceSegment ?? 'Not Categorized'),
                    _detailRow('Lead Status', buyer.status),
                    const SizedBox(height: 8),
                    const Text('Agent Consultation Notes:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(buyer.notes, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                    const SizedBox(height: 14),
                    // PDPA Consent Status Overview
                    const Text('PDPA Consent Records', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Enquiry Response Consent:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (hasEnquiry ? AppTheme.success : AppTheme.warning).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  hasEnquiry ? 'Granted' : 'Not Recorded',
                                  style: TextStyle(
                                    color: hasEnquiry ? AppTheme.success : AppTheme.warning,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Marketing Consent:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (hasMarketing ? AppTheme.info : AppTheme.textHint).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      hasMarketing ? 'Active / Granted' : 'Opted-Out / Withdrawn',
                                      style: TextStyle(
                                        color: hasMarketing ? AppTheme.info : AppTheme.textHint,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (hasMarketing) ...[
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.error,
                                        side: const BorderSide(color: AppTheme.error),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      icon: const Icon(Icons.do_not_disturb_on_outlined, size: 14),
                                      label: const Text('Withdraw', style: TextStyle(fontSize: 11)),
                                      onPressed: () {
                                        appState.withdrawMarketingConsentForBuyer(buyer.id);
                                        setModalState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Marketing consent withdrawn for ${buyer.name}')),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          if (consentHistory.isNotEmpty) ...[
                            const Divider(height: 16),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Immutable Audit Trail:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                              ),
                            ),
                            const SizedBox(height: 6),
                            ...consentHistory.take(5).map((c) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      Icon(
                                        c.consentStatus == 'granted' ? Icons.check_circle_outline : Icons.cancel_outlined,
                                        size: 13,
                                        color: c.consentStatus == 'granted' ? AppTheme.success : AppTheme.error,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${c.consentType == "enquiry_response" ? "Enquiry" : "Marketing"} ${c.consentStatus.toUpperCase()} • ${c.consentSource}',
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${c.createdAt.year}-${c.createdAt.month.toString().padLeft(2, '0')}-${c.createdAt.day.toString().padLeft(2, '0')} ${c.createdAt.hour.toString().padLeft(2, '0')}:${c.createdAt.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(fontSize: 9, color: AppTheme.textHint),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                onPressed: () {
                  final hasActive = appState.hasActiveLeadsOrFollowupsForBuyer(buyer.id);
                  showDialog(
                    context: context,
                    builder: (delCtx) => AlertDialog(
                      title: const Text('Delete Buyer Record', style: TextStyle(fontWeight: FontWeight.w700)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Are you sure you want to delete "${buyer.name}"?'),
                          if (hasActive) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Notice: This buyer has active leads or pending follow-ups in the pipeline.',
                                      style: TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(delCtx).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.error,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            appState.deleteBuyer(buyer.id);
                            Navigator.of(delCtx).pop();
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Deleted buyer "${buyer.name}"')),
                            );
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Delete Buyer'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 170, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        ],
      ),
    );
  }
}
