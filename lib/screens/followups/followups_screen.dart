import 'package:flutter/material.dart';
import '../../config/theme.dart';

class FollowupsScreen extends StatefulWidget {
  const FollowupsScreen({super.key});

  @override
  State<FollowupsScreen> createState() => _FollowupsScreenState();
}

class _FollowupsScreenState extends State<FollowupsScreen> {
  final List<Map<String, dynamic>> _followups = [
    {
      'id': 'f-1',
      'buyerName': 'Ahmad Ismail (Demo)',
      'project': 'EXSIM Demo Residence',
      'task': 'Confirm Saturday 2:00 PM showroom appointment & Maybank pre-approval letter',
      'dueDate': 'Tomorrow, 2:00 PM',
      'type': 'Showroom Viewing',
      'isCompleted': false,
    },
    {
      'id': 'f-2',
      'buyerName': 'Wei Lun Tan (Demo)',
      'project': 'EXSIM Demo Residence',
      'task': 'Send PDF layout of Type B (950 sqft) via WhatsApp with car park allocation breakdown',
      'dueDate': 'Today, 5:00 PM',
      'type': 'WhatsApp Follow-up',
      'isCompleted': false,
    },
    {
      'id': 'f-3',
      'buyerName': 'Kavitha Ramasamy (Demo)',
      'project': 'Gurney Premier Suites',
      'task': 'Follow up on 5-year gross rental yield spreadsheet and tenant management proposal',
      'dueDate': 'In 2 days',
      'type': 'Investor Consultation',
      'isCompleted': false,
    },
    {
      'id': 'f-4',
      'buyerName': 'Chee Meng Wong (Demo)',
      'project': 'Kulim Hi-Tech Green Residences',
      'task': 'Review corner lot availability and early bird rebate calculation',
      'dueDate': 'Completed Yesterday',
      'type': 'Loan Screening',
      'isCompleted': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                    Text(
                      'Follow-up & Viewing Schedules',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage buyer communication, showroom viewings, and loan pre-screening checkpoints.',
                      style: const TextStyle(color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              ElevatedButton.icon(
                onPressed: () => _showAddTaskDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Schedule Follow-up'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Follow-ups List
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingLg),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _followups.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final item = _followups[index];
                  final isDone = item['isCompleted'] as bool;

                  return CheckboxListTile(
                    value: isDone,
                    onChanged: (val) {
                      setState(() {
                        item['isCompleted'] = val ?? false;
                      });
                    },
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Row(
                      children: [
                        Text(
                          item['buyerName'],
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            decoration: isDone ? TextDecoration.lineThrough : null,
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
                            item['type'],
                            style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item['dueDate'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDone ? AppTheme.textHint : AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['task'],
                            style: TextStyle(
                              fontSize: 13,
                              color: isDone ? AppTheme.textHint : AppTheme.textPrimary,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('Target Project: ${item['project']}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final taskCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule New Follow-up', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Buyer Name *', hintText: 'e.g. Jason Lim'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: taskCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Follow-up Action *', hintText: 'e.g. Confirm weekend showroom viewing time'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && taskCtrl.text.isNotEmpty) {
                setState(() {
                  _followups.insert(0, {
                    'id': 'f-${DateTime.now().millisecondsSinceEpoch}',
                    'buyerName': nameCtrl.text.trim(),
                    'project': 'Active Focus Project',
                    'task': taskCtrl.text.trim(),
                    'dueDate': 'Tomorrow, 10:00 AM',
                    'type': 'Custom Follow-up',
                    'isCompleted': false,
                  });
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Save Schedule'),
          ),
        ],
      ),
    );
  }
}
