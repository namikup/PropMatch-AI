import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/app_state_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();

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
            'Evaluate regional buyer intent, budget distributions, and simulated market acquisition signals.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // High-level KPIs
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 950 ? 4 : 2;

              return GridView.count(
                crossAxisCount: count,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: AppTheme.spacingMd,
                mainAxisSpacing: AppTheme.spacingMd,
                childAspectRatio: 1.8,
                children: [
                  _kpiCard('Total Demand Index', '87.4', 'High Buyer Interest', Icons.trending_up, AppTheme.success),
                  _kpiCard('Avg. Target Budget', 'RM 540,000', 'Penang / Kedah Median', Icons.account_balance_wallet_outlined, AppTheme.primary),
                  _kpiCard('Lead Conversion Rate', '14.2%', 'Inquiry to Qualified', Icons.pie_chart_outline, AppTheme.accent),
                  _kpiCard('Top Demand Area', 'Batu Kawan', 'BKIP Tech Corridor', Icons.location_city_outlined, AppTheme.info),
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
                    Expanded(child: _buildLocationDemandCard(context)),
                    const SizedBox(width: AppTheme.spacingLg),
                    Expanded(child: _buildBudgetDistributionCard(context, appState)),
                  ],
                );
              }
              return Column(
                children: [
                  _buildLocationDemandCard(context),
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
        padding: const EdgeInsets.all(AppTheme.spacingLg),
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
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: color, size: 20),
              ],
            ),
            const SizedBox(height: 6),
            Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDemandCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Regional Buyer Location Preference', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Relative share of inquiries across monitored Malaysian regions', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: AppTheme.spacingLg),
            _locationBar('Batu Kawan (Penang)', 0.38, '38% of inquiries', AppTheme.primary),
            _locationBar('Bayan Lepas / FIZ (Penang)', 0.26, '26% of inquiries', AppTheme.secondary),
            _locationBar('Kulim Hi-Tech (Kedah)', 0.18, '18% of inquiries', AppTheme.accent),
            _locationBar('George Town / Gurney (Penang)', 0.12, '12% of inquiries', AppTheme.info),
            _locationBar('Central / Klang Valley Relocators', 0.06, '6% of inquiries', Colors.purple),
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
              value: pct,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Buyer Budget Spectrum', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Purchasing power brackets of registered buyer database', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: AppTheme.spacingLg),
            _locationBar('Under RM 450,000 (Entry / Starter)', 0.30, '30% of buyers', AppTheme.secondary),
            _locationBar('RM 450,000 - RM 650,000 (Middle Tier)', 0.42, '42% of buyers', AppTheme.primary),
            _locationBar('RM 650,000 - RM 900,000 (Upgraders)', 0.18, '18% of buyers', AppTheme.accent),
            _locationBar('Above RM 900,000 (Luxury / Investors)', 0.10, '10% of buyers', AppTheme.info),
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
                    'Lead Acquisition Signals (Simulated Market Demand)',
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
                  child: const Text('PROTOTYPE SIMULATION', style: TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Simulated public intent signals respecting Malaysian PDPA requirements. Anonymous search & social trend aggregations without private scraping.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            _signalRow('Google Search Surge: "Batu Kawan condo near IKEA with 3 rooms"', 'High Velocity', '+42% search volume', AppTheme.success),
            const Divider(height: 16),
            _signalRow('Meta Ad Interest Spike: First-time homebuyer stamp duty exemptions in Penang', 'Moderate Velocity', '+18% CTR improvement', AppTheme.primary),
            const Divider(height: 16),
            _signalRow('Kulim Industrial Corridor: Demand for freehold landed residences under RM450k', 'High Velocity', '+35% inquiry velocity', AppTheme.accent),
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
