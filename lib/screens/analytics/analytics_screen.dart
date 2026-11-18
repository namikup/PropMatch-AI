import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/app_state_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();

    final totalBuyers = appState.totalBuyerCount;
    final conversionRate = appState.pipelineConversionRate;
    final avgBudget = appState.averageBuyerBudget;
    final topLocation = appState.topBuyerLocation;
    final demandIndex = totalBuyers > 0
        ? (50.0 + (conversionRate * 0.3) + (appState.activeProjectCount * 4.0)).clamp(20.0, 94.5).toStringAsFixed(1)
        : 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Market Analytics & Lead Intelligence',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Evaluate regional buyer intent, budget distributions, and pipeline conversion signals across active records.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // High-level KPIs (Computed from real in-memory state)
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 950 ? 4 : 2;
              final ratio = constraints.maxWidth >= 950 ? 2.1 : 1.8;

              return GridView.count(
                crossAxisCount: count,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppTheme.spacingMd,
                mainAxisSpacing: AppTheme.spacingMd,
                childAspectRatio: ratio,
                children: [
                  _kpiCard(
                    'Demand Health Index',
                    demandIndex,
                    totalBuyers > 0 ? 'Active Portfolio Index' : 'No Data Available',
                    Icons.trending_up,
                    AppTheme.success,
                  ),
                  _kpiCard(
                    'Avg. Target Budget',
                    avgBudget > 0 ? 'RM ${(avgBudget / 1000).toStringAsFixed(0)},000' : 'No Profiles',
                    totalBuyers > 0 ? 'Mean of $totalBuyers registered buyers' : 'Generate demo buyers',
                    Icons.account_balance_wallet_outlined,
                    AppTheme.primary,
                  ),
                  _kpiCard(
                    'Lead Conversion Rate',
                    '${conversionRate.toStringAsFixed(1)}%',
                    '${appState.qualifiedLeadCount} of ${appState.leads.length} leads qualified',
                    Icons.pie_chart_outline,
                    AppTheme.accent,
                  ),
                  _kpiCard(
                    'Top Demand Area',
                    topLocation,
                    totalBuyers > 0 ? 'Highest buyer preference' : 'No location data',
                    Icons.location_city_outlined,
                    AppTheme.info,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // 2-Column Desktop Grid for Visual Analytics
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildLocationDemandCard(context, appState)),
                    const SizedBox(width: AppTheme.spacingLg),
                    Expanded(child: _buildBudgetDistributionCard(context, appState)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildLocationDemandCard(context, appState),
                  const SizedBox(height: AppTheme.spacingLg),
                  _buildBudgetDistributionCard(context, appState),
                ],
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Lead Acquisition Signals (Simulated Market Demand)
          _buildSimulatedSignalsCard(context),
        ],
      ),
    );
  }

  Widget _kpiCard(String title, String val, String subtitle, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDemandCard(BuildContext context, AppStateProvider appState) {
    final locationCounts = appState.buyersByLocation;
    final totalBuyers = appState.totalBuyerCount;

    // Sort locations by popularity
    final sortedEntries = locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEntries = sortedEntries.take(5).toList();

    final colors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.accent,
      AppTheme.info,
      Colors.purple,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Regional Buyer Location Preference',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              totalBuyers > 0
                  ? 'Relative share of preferences across $totalBuyers registered buyer profiles'
                  : 'No buyer records registered. Generate demo buyers to view distributions.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            if (totalBuyers == 0) ...[
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Text('No location data recorded yet.', style: TextStyle(color: AppTheme.textHint)),
              ),
            ] else ...[
              ...topEntries.asMap().entries.map((entry) {
                final index = entry.key;
                final loc = entry.value.key;
                final count = entry.value.value;
                final pct = count / totalBuyers;
                final color = colors[index % colors.length];

                return _locationBar(
                  loc,
                  pct,
                  '$count buyers (${(pct * 100).toStringAsFixed(0)}%)',
                  color,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _locationBar(String label, double pct, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(desc, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppTheme.background,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetDistributionCard(BuildContext context, AppStateProvider appState) {
    final tiers = appState.buyersByBudgetTier;
    final totalBuyers = appState.totalBuyerCount;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Buyer Budget Spectrum',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              totalBuyers > 0
                  ? 'Purchasing power brackets computed from $totalBuyers registered buyers'
                  : 'No buyer records registered. Generate demo buyers to view distributions.',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            if (totalBuyers == 0) ...[
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: const Text('No budget data recorded yet.', style: TextStyle(color: AppTheme.textHint)),
              ),
            ] else ...[
              _locationBar(
                'Under RM 450,000 (Entry / Starter)',
                (tiers['Under RM 450,000'] ?? 0) / totalBuyers,
                '${tiers['Under RM 450,000'] ?? 0} buyers (${(((tiers['Under RM 450,000'] ?? 0) / totalBuyers) * 100).toStringAsFixed(0)}%)',
                AppTheme.secondary,
              ),
              _locationBar(
                'RM 450,000 - RM 650,000 (Middle Tier)',
                (tiers['RM 450,000 - RM 650,000'] ?? 0) / totalBuyers,
                '${tiers['RM 450,000 - RM 650,000'] ?? 0} buyers (${(((tiers['RM 450,000 - RM 650,000'] ?? 0) / totalBuyers) * 100).toStringAsFixed(0)}%)',
                AppTheme.primary,
              ),
              _locationBar(
                'RM 650,000 - RM 900,000 (Upgraders)',
                (tiers['RM 650,000 - RM 900,000'] ?? 0) / totalBuyers,
                '${tiers['RM 650,000 - RM 900,000'] ?? 0} buyers (${(((tiers['RM 650,000 - RM 900,000'] ?? 0) / totalBuyers) * 100).toStringAsFixed(0)}%)',
                AppTheme.accent,
              ),
              _locationBar(
                'Above RM 900,000 (Luxury / Investors)',
                (tiers['Above RM 900,000'] ?? 0) / totalBuyers,
                '${tiers['Above RM 900,000'] ?? 0} buyers (${(((tiers['Above RM 900,000'] ?? 0) / totalBuyers) * 100).toStringAsFixed(0)}%)',
                AppTheme.info,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimulatedSignalsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.radar, color: AppTheme.primary, size: 22),
                const SizedBox(width: AppTheme.spacingMd),
                Expanded(
                  child: Text(
                    'Simulated Market Acquisition Signals',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PROTOTYPE SIMULATION',
                    style: TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Simulated public intent signals respecting Malaysian PDPA requirements. '
              'These represent hypothetical marketing demand indicators for testing and demonstration, '
              'not verified real-world search statistics or Census data.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            _signalRow(
              'Simulated Search Surge: "Batu Kawan condo near IKEA with 3 rooms"',
              'High Velocity',
              '+42% simulated volume (Hypothetical)',
              AppTheme.success,
            ),
            const Divider(height: 16),
            _signalRow(
              'Simulated Ad Interest: First-time homebuyer stamp duty exemptions in Penang',
              'Moderate Velocity',
              '+18% simulated CTR (Hypothetical)',
              AppTheme.primary,
            ),
            const Divider(height: 16),
            _signalRow(
              'Simulated Regional Corridor: Freehold landed residences under RM450k in Kulim',
              'High Velocity',
              '+35% simulated velocity (Hypothetical)',
              AppTheme.accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _signalRow(String query, String status, String metric, Color color) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(query, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(metric, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
