import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/lead_model.dart';
import '../../providers/app_state_provider.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();

    final filteredLeads = _statusFilter == 'All'
        ? appState.leads
        : appState.leads.where((l) => l.status == _statusFilter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
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
                            'Lead Management Pipeline',
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
                            '${appState.leads.length} Total Leads',
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
                      'Track voluntary enquiries, buyer matches, and negotiations from initial interest to closing.',
                      style: TextStyle(color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              ElevatedButton.icon(
                onPressed: () => _showAddLeadDialog(context, appState),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Voluntary Enquiry'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Filter bar
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text('Stage Filter: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ...['All', 'New', 'Contacted', 'Qualified', 'Negotiating', 'Won', 'Lost'].map((st) {
                    final isSelected = _statusFilter == st;
                    return ChoiceChip(
                      label: Text(st),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _statusFilter = st),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Leads Table
          if (filteredLeads.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(60),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.leaderboard_outlined, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text('No Leads in this Stage', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text('Convert matches into leads or add voluntary buyer enquiries.'),
                ],
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.5),
                    1: FlexColumnWidth(2.0),
                    2: FlexColumnWidth(1.5),
                    3: FlexColumnWidth(1.5),
                    4: FlexColumnWidth(1.5),
                    5: FlexColumnWidth(1.0),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
                      ),
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Buyer Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Project', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Source', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Est. Value', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Pipeline Stage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                        Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Action', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                      ],
                    ),
                    ...filteredLeads.map((lead) {
                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    lead.buyerName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (lead.isDemo) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.warning.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: const Text('DEMO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.warning)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(lead.projectName, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(lead.source, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary), overflow: TextOverflow.ellipsis),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(lead.dealValue > 0 ? 'RM${lead.dealValue.toStringAsFixed(0)}' : 'TBD', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: _buildStatusBadge(lead.status),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PopupMenuButton<String>(
                                  tooltip: 'Change Pipeline Stage',
                                  icon: const Icon(Icons.swap_horiz, size: 20, color: AppTheme.primary),
                                  onSelected: (newStatus) {
                                    appState.updateLeadStatus(lead.id, newStatus);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Updated ${lead.buyerName} stage to "$newStatus"')),
                                    );
                                  },
                                  itemBuilder: (ctx) => [
                                    'New',
                                    'Contacted',
                                    'Qualified',
                                    'Negotiating',
                                    'Won',
                                    'Lost',
                                  ].map((stage) {
                                    final isCurrent = stage == lead.status;
                                    return PopupMenuItem<String>(
                                      value: stage,
                                      child: Row(
                                        children: [
                                          Icon(
                                            isCurrent ? Icons.check_circle : Icons.circle_outlined,
                                            size: 16,
                                            color: isCurrent ? AppTheme.primary : AppTheme.textHint,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            stage,
                                            style: TextStyle(
                                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                              color: isCurrent ? AppTheme.primary : null,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.textHint, size: 18),
                                  tooltip: 'Delete Lead',
                                  onPressed: () {
                                    appState.deleteLead(lead.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Removed ${lead.buyerName} from pipeline')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = AppTheme.primary;
    if (status == 'Qualified' || status == 'Won') color = AppTheme.success;
    if (status == 'Contacted') color = AppTheme.info;
    if (status == 'Negotiating') color = AppTheme.accent;
    if (status == 'Lost') color = AppTheme.error;

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

  void _showAddLeadDialog(BuildContext context, AppStateProvider appState) {
    if (appState.projects.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('No Property Projects Available', style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text(
            'You must create at least one property project in the Property Projects module before capturing buyer enquiries.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final valueCtrl = TextEditingController(text: '450000');
    String projectVal = appState.projects.first.id;
    String sourceVal = 'WhatsApp Enquiry';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Capture Voluntary Buyer Enquiry', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Buyer Name *', hintText: 'e.g. Tan Zhi Wei'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: projectVal,
                  decoration: const InputDecoration(labelText: 'Interested Project *'),
                  items: appState.projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                  onChanged: (v) => setDialogState(() => projectVal = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: sourceVal,
                  decoration: const InputDecoration(labelText: 'Acquisition Channel *'),
                  items: ['WhatsApp Enquiry', 'Facebook Lead Ad', 'Walk-in', 'Property Portal', 'Referral'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setDialogState(() => sourceVal = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Estimated Deal Value (RM)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Buyer Notes / Requirements'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final matchedProjects = appState.projects.where((p) => p.id == projectVal);
                if (matchedProjects.isEmpty) return;
                final project = matchedProjects.first;

                final newLead = LeadModel(
                  ownerId: appState.currentOwnerId,
                  buyerId: 'manual-${DateTime.now().millisecondsSinceEpoch}',
                  projectId: project.id,
                  buyerName: nameCtrl.text.trim(),
                  projectName: project.name,
                  source: sourceVal,
                  dealValue: double.tryParse(valueCtrl.text) ?? 0.0,
                  notes: notesCtrl.text.trim(),
                  status: 'New',
                  isDemo: false, // Genuine voluntary enquiry
                );

                appState.addLead(newLead);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Saved enquiry for ${newLead.buyerName}!')),
                );
              },
              child: const Text('Save Enquiry'),
            ),
          ],
        ),
      ),
    );
  }
}
