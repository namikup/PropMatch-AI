import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/followup_model.dart';
import '../../providers/app_state_provider.dart';

class FollowupsScreen extends StatefulWidget {
  const FollowupsScreen({super.key});

  @override
  State<FollowupsScreen> createState() => _FollowupsScreenState();
}

class _FollowupsScreenState extends State<FollowupsScreen> {
  String _filterType = 'All';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final allFollowups = appState.followups;

    final filteredFollowups = _filterType == 'All'
        ? allFollowups
        : _filterType == 'Pending'
            ? allFollowups.where((f) => !f.isCompleted).toList()
            : _filterType == 'Completed'
                ? allFollowups.where((f) => f.isCompleted).toList()
                : allFollowups.where((f) => f.type == _filterType).toList();

    final pendingCount = allFollowups.where((f) => !f.isCompleted).length;
    final completedCount = allFollowups.where((f) => f.isCompleted).length;

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
                            'Follow-up & Viewing Schedules',
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
                            '$pendingCount Pending • $completedCount Done',
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
                      'Manage buyer communication, showroom viewings, and loan pre-screening checkpoints across sessions.',
                      style: TextStyle(color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              ElevatedButton.icon(
                onPressed: () => _showAddTaskDialog(context, appState),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule Follow-up'),
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
                  const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ...['All', 'Pending', 'Completed', 'Showroom Viewing', 'WhatsApp Follow-up', 'Investor Consultation'].map((f) {
                    final isSelected = _filterType == f;
                    return ChoiceChip(
                      label: Text(f),
                      selected: isSelected,
                      onSelected: (val) => setState(() => _filterType = f),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Follow-ups List
          if (filteredFollowups.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(60),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.event_available_outlined, size: 64, color: AppTheme.textHint),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text(
                    'No Follow-ups in this View',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text('All scheduled buyer appointments and checkpoints are completed or none match the filter.'),
                ],
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredFollowups.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final item = filteredFollowups[index];
                    final isDone = item.isCompleted;

                    return CheckboxListTile(
                      value: isDone,
                      onChanged: (_) {
                        appState.toggleFollowupCompletion(item.id);
                      },
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.buyerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.type,
                              style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            item.dueDate,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDone ? AppTheme.textHint : AppTheme.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryLight),
                            tooltip: 'Edit Follow-up',
                            onPressed: () => _showEditTaskDialog(context, appState, item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.textHint),
                            tooltip: 'Delete Follow-up',
                            onPressed: () {
                              appState.deleteFollowup(item.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Removed follow-up for ${item.buyerName}')),
                              );
                            },
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.task,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDone ? AppTheme.textHint : AppTheme.textPrimary,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Target Project: ${item.projectName}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, AppStateProvider appState) {
    final nameCtrl = TextEditingController();
    final taskCtrl = TextEditingController();
    final dueDateCtrl = TextEditingController(text: 'Tomorrow, 10:00 AM');
    String typeVal = 'Showroom Viewing';
    String projectVal = appState.selectedProject?.name ??
        (appState.projects.isNotEmpty ? appState.projects.first.name : 'General Project');
    String? selectedProjectId = appState.selectedProject?.id ??
        (appState.projects.isNotEmpty ? appState.projects.first.id : null);
    String? selectedBuyerId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Schedule New Follow-up', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (appState.allBuyers.isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: selectedBuyerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Select Registered Buyer (Optional)',
                        hintText: 'Choose from system buyers or enter below',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('-- Custom / Enter Name Below --'),
                        ),
                        ...appState.allBuyers.map(
                          (b) => DropdownMenuItem<String?>(
                            value: b.id,
                            child: Text(
                              '${b.name} (${b.preferredLocation} • RM${b.budgetMin.toStringAsFixed(0)})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          selectedBuyerId = v;
                          if (v != null) {
                            final matched = appState.allBuyers.where((b) => b.id == v);
                            if (matched.isNotEmpty) {
                              nameCtrl.text = matched.first.name;
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buyer Name *',
                      hintText: 'e.g. Jason Lim',
                    ),
                    onChanged: (v) {
                      // If name manually changed, verify buyerId match
                      if (selectedBuyerId != null) {
                        final matched = appState.allBuyers.where((b) => b.id == selectedBuyerId);
                        if (matched.isEmpty || matched.first.name != v) {
                          setDialogState(() => selectedBuyerId = null);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  if (appState.projects.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedProjectId ?? appState.projects.first.id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Associated Property Project *'),
                      items: appState.projects
                          .map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} (${p.location})', overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            selectedProjectId = v;
                            final matched = appState.projects.where((p) => p.id == v);
                            if (matched.isNotEmpty) {
                              projectVal = matched.first.name;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: typeVal,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Follow-up Type *'),
                    items: [
                      'Showroom Viewing',
                      'WhatsApp Follow-up',
                      'Investor Consultation',
                      'Loan Screening',
                      'Custom Follow-up',
                    ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setDialogState(() => typeVal = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dueDateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Due Schedule / Timing *',
                      hintText: 'e.g. Tomorrow, 2:00 PM or Saturday 11:00 AM',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: taskCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Follow-up Action *',
                      hintText: 'e.g. Confirm weekend showroom viewing time and send brochure',
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
                final task = taskCtrl.text.trim();
                final due = dueDateCtrl.text.trim();
                if (name.isNotEmpty && task.isNotEmpty) {
                  final newFollowup = FollowupModel(
                    ownerId: appState.currentOwnerId,
                    buyerName: name,
                    buyerId: selectedBuyerId,
                    projectName: projectVal,
                    projectId: selectedProjectId,
                    task: task,
                    dueDate: due.isEmpty ? 'Pending Schedule' : due,
                    type: typeVal,
                    isCompleted: false,
                  );
                  appState.addFollowup(newFollowup);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Scheduled follow-up for $name!')),
                  );
                }
              },
              child: const Text('Save Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTaskDialog(BuildContext context, AppStateProvider appState, FollowupModel item) {
    final nameCtrl = TextEditingController(text: item.buyerName);
    final taskCtrl = TextEditingController(text: item.task);
    final dueDateCtrl = TextEditingController(text: item.dueDate);
    String typeVal = item.type;
    String projectVal = item.projectName;
    String? selectedProjectId = item.projectId;
    String? selectedBuyerId = item.buyerId;

    // Check if item's projectId exists in current projects
    final hasProject = selectedProjectId != null &&
        appState.projects.any((p) => p.id == selectedProjectId);
    if (!hasProject && appState.projects.isNotEmpty) {
      final nameMatch = appState.projects.where((p) => p.name == item.projectName);
      if (nameMatch.isNotEmpty) {
        selectedProjectId = nameMatch.first.id;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Follow-up Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (appState.allBuyers.isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: selectedBuyerId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Associated Buyer (Optional Link)',
                        hintText: 'Choose from registered buyers',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('-- Manual / Custom Buyer --'),
                        ),
                        ...appState.allBuyers.map(
                          (b) => DropdownMenuItem<String?>(
                            value: b.id,
                            child: Text(
                              '${b.name} (${b.preferredLocation})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        setDialogState(() {
                          selectedBuyerId = v;
                          if (v != null) {
                            final matched = appState.allBuyers.where((b) => b.id == v);
                            if (matched.isNotEmpty) {
                              nameCtrl.text = matched.first.name;
                            }
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Buyer Name *',
                      hintText: 'e.g. Jason Lim',
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (appState.projects.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedProjectId ?? appState.projects.first.id,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Associated Property Project *'),
                      items: appState.projects
                          .map((p) => DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} (${p.location})', overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            selectedProjectId = v;
                            final matched = appState.projects.where((p) => p.id == v);
                            if (matched.isNotEmpty) {
                              projectVal = matched.first.name;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  DropdownButtonFormField<String>(
                    initialValue: typeVal,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Follow-up Type *'),
                    items: [
                      'Showroom Viewing',
                      'WhatsApp Follow-up',
                      'Investor Consultation',
                      'Loan Screening',
                      'Custom Follow-up',
                    ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setDialogState(() => typeVal = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dueDateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Due Schedule / Timing *',
                      hintText: 'e.g. Tomorrow, 2:00 PM',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: taskCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Follow-up Action *',
                      hintText: 'e.g. Confirm viewing details',
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
                final task = taskCtrl.text.trim();
                final due = dueDateCtrl.text.trim();
                if (name.isNotEmpty && task.isNotEmpty) {
                  final updatedFollowup = item.copyWith(
                    buyerName: name,
                    buyerId: selectedBuyerId,
                    projectName: projectVal,
                    projectId: selectedProjectId,
                    task: task,
                    dueDate: due.isEmpty ? item.dueDate : due,
                    type: typeVal,
                    updatedAt: DateTime.now(),
                  );
                  appState.updateFollowup(updatedFollowup);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Updated follow-up for $name!')),
                  );
                }
              },
              child: const Text('Update Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
