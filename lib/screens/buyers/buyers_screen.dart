import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/buyer_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/navigation_provider.dart';

class BuyersScreen extends StatelessWidget {
  const BuyersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final nav = context.read<NavigationProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title and Generator Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Buyer Directory & Database',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${appState.buyers.length} Profiles (${appState.demoBuyerCount} DEMO)',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Search, filter, and inspect prospective buyers across Penang, Kedah, and central states.',
                      style: TextStyle(color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),

              // Action buttons
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: () {
                      appState.generate100DemoBuyers();
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
                      onChanged: (val) => appState.setBuyerSearchQuery(val),
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
                        if (val != null) appState.setBuyerStatusFilter(val);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Buyers Table
          if (appState.buyers.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(60),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.person_search_outlined, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'No Buyers Found',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('Click "Generate 100 Demo Buyers" to populate the system with test profiles.'),
                  const SizedBox(height: AppTheme.spacingLg),
                  ElevatedButton.icon(
                    onPressed: () => appState.generate100DemoBuyers(),
                    icon: const Icon(Icons.bolt),
                    label: const Text('Generate 100 Test Profiles'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Card(
              child: SingleChildScrollView(
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
                    rows: appState.buyers.take(50).map((buyer) {
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

  void _showBuyerDetailModal(BuildContext context, BuyerModel buyer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                    const Text('DEMO DATA • Synthetic Profile for Verification', style: TextStyle(color: AppTheme.warning, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
            ],
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
