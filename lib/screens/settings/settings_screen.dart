import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/app_state_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings & System Configuration',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage agent profile, regional coverage, data retention policies, and Firestore security rules.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Agent Profile Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.primary,
                        child: Text('MA', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: AppTheme.spacingLg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Licensed Real Estate Agent (REN)', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('Agent ID: ${appState.currentOwnerId} • Region: Penang & Kedah Priority', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('ACTIVE AGENT', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Demo Data Isolation Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 24),
                      const SizedBox(width: AppTheme.spacingMd),
                      Expanded(
                        child: Text(
                          'Demo Data Management & Isolation',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'PropMatch AI strictly isolates test profiles from real production records. Fictional buyer profiles are tagged with isDemo: true and never committed to production client lists.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: AppTheme.spacingLg),

                  Wrap(
                    spacing: AppTheme.spacingMd,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
                        onPressed: () {
                          appState.generate100DemoBuyers();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Generated 100 Fictional Demo Profiles!')),
                          );
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Regenerate 100 Demo Buyers'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                        onPressed: () {
                          // Clear demo profiles via provider method
                          appState.removeDemoBuyers();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cleared all synthetic demo profiles.')),
                          );
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Clear Demo Profiles'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Security Rules & Architecture Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.lock_outline, color: AppTheme.primary, size: 24),
                      const SizedBox(width: AppTheme.spacingMd),
                      Expanded(
                        child: Text(
                          'Firestore Security & Multi-Agent Architecture',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Multi-tenant security enforces that every document contains an ownerId. Agents can only access, query, or edit their own records.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: const SelectableText(
                      'rules_version = \'2\';\n'
                      'service cloud.firestore {\n'
                      '  match /databases/{database}/documents {\n'
                      '    match /{collection}/{docId} {\n'
                      '      allow read, update, delete: if request.auth != null && resource.data.ownerId == request.auth.uid;\n'
                      '      allow create: if request.auth != null && request.resource.data.ownerId == request.auth.uid;\n'
                      '    }\n'
                      '  }\n'
                      '}',
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // App Metadata
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Application Build Metadata', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _infoRow('Product Name', AppConstants.appName),
                  _infoRow('Version', AppConstants.appVersion),
                  _infoRow('Target Platform', 'Flutter Web (Chrome Desktop/Laptop)'),
                  _infoRow('Target Market', 'Malaysia (Penang, Kedah & Northern Corridor)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
