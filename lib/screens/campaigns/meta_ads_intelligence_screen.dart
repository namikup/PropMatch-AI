import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/meta_ads/meta_connection_model.dart';
import '../../models/meta_ads/meta_campaign_model.dart';
import '../../models/meta_ads/meta_ai_insight_model.dart';
import '../../services/meta_ads_service.dart';

class MetaAdsIntelligenceScreen extends StatefulWidget {
  final String ownerId;

  const MetaAdsIntelligenceScreen({
    super.key,
    required this.ownerId,
  });

  @override
  State<MetaAdsIntelligenceScreen> createState() => _MetaAdsIntelligenceScreenState();
}

class _MetaAdsIntelligenceScreenState extends State<MetaAdsIntelligenceScreen> {
  late final MetaAdsService _adsService;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isAnalyzingAI = false;

  MetaConnectionModel? _connection;
  List<MetaCampaignModel> _campaigns = [];
  MetaAIInsightModel? _aiInsight;

  final currencyFormatter = NumberFormat.currency(locale: 'en_MY', symbol: 'RM ', decimalDigits: 2);
  final integerFormatter = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    _adsService = MetaAdsService();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final conn = await _adsService.getConnectionStatus(widget.ownerId);
      final camps = await _adsService.getCampaigns(widget.ownerId);
      final ai = await _adsService.generateAIIntelligence(widget.ownerId);

      if (mounted) {
        setState(() {
          _connection = conn;
          _campaigns = camps;
          _aiInsight = ai;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _triggerSync() async {
    setState(() => _isSyncing = true);
    try {
      final updated = await _adsService.syncCampaigns(widget.ownerId);
      final conn = await _adsService.getConnectionStatus(widget.ownerId);
      if (mounted) {
        setState(() {
          _campaigns = updated;
          _connection = conn;
          _isSyncing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meta advertising metrics synchronized successfully.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _triggerAIAnalysis() async {
    setState(() => _isAnalyzingAI = true);
    try {
      final insight = await _adsService.generateAIIntelligence(widget.ownerId);
      if (mounted) {
        setState(() {
          _aiInsight = insight;
          _isAnalyzingAI = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isAnalyzingAI = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final totalSpend = _campaigns.fold(0.0, (sum, c) => sum + c.spend);
    final totalImpressions = _campaigns.fold(0, (sum, c) => sum + c.impressions);
    final totalReach = _campaigns.fold(0, (sum, c) => sum + c.reach);
    final totalClicks = _campaigns.fold(0, (sum, c) => sum + c.clicks);
    final totalLeads = _campaigns.fold(0, (sum, c) => sum + c.leads);
    final avgCtr = totalImpressions > 0 ? (totalClicks / totalImpressions) * 100 : 0.0;
    final avgCpc = totalClicks > 0 ? totalSpend / totalClicks : 0.0;
    final avgCpm = totalImpressions > 0 ? (totalSpend / totalImpressions) * 1000 : 0.0;
    final avgCpl = totalLeads > 0 ? totalSpend / totalLeads : 0.0;

    final totalContactable = _campaigns.fold(0, (sum, c) => sum + c.qualityMetrics.validContactableLeads);
    final totalQualified = _campaigns.fold(0, (sum, c) => sum + c.qualityMetrics.qualifiedProspects);
    final totalViewings = _campaigns.fold(0, (sum, c) => sum + c.qualityMetrics.viewingAppointments);
    final totalConverted = _campaigns.fold(0, (sum, c) => sum + c.qualityMetrics.convertedBuyers);
    final costPerQualified = totalQualified > 0 ? totalSpend / totalQualified : null;
    final costPerViewing = totalViewings > 0 ? totalSpend / totalViewings : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section 1: Connection Overview Card
        _buildConnectionCard(),
        const SizedBox(height: AppTheme.spacingLg),

        // Section 2: Advertising Performance KPIs
        Text(
          'Advertising Performance Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        _buildKpiGrid(
          totalSpend: totalSpend,
          totalImpressions: totalImpressions,
          totalReach: totalReach,
          totalClicks: totalClicks,
          avgCtr: avgCtr,
          avgCpc: avgCpc,
          avgCpm: avgCpm,
          totalLeads: totalLeads,
          avgCpl: avgCpl,
        ),
        const SizedBox(height: AppTheme.spacingXl),

        // Section 3: Buyer Quality & Conversion Funnel
        _buildBuyerQualitySection(
          totalLeads: totalLeads,
          totalContactable: totalContactable,
          totalQualified: totalQualified,
          totalViewings: totalViewings,
          totalConverted: totalConverted,
          costPerQualified: costPerQualified,
          costPerViewing: costPerViewing,
        ),
        const SizedBox(height: AppTheme.spacingXl),

        // Section 4: Campaign Comparison Table
        _buildCampaignComparisonTable(),
        const SizedBox(height: AppTheme.spacingXl),

        // Section 5: AI Campaign Intelligence (Gemini)
        _buildAIIntelligenceSection(),
        const SizedBox(height: AppTheme.spacingXl),

        // Section 6: Governance & Safety Notice
        _buildGovernanceNotice(),
      ],
    );
  }

  Widget _buildConnectionCard() {
    final conn = _connection ?? MetaConnectionModel.initial(widget.ownerId);

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: conn.isConnected ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.cardBorder,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
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
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1877F2).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.facebook,
                        color: Color(0xFF1877F2),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              const Text(
                                'Meta Advertising Asset Connection',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: conn.isConnected
                                      ? AppTheme.success.withValues(alpha: 0.15)
                                      : AppTheme.textHint.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  conn.isConnected ? 'Connected' : 'Disconnected',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: conn.isConnected ? AppTheme.success : AppTheme.textHint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            conn.isConnected
                                ? 'Page: ${conn.facebookPageName} • Account: ${conn.adAccountId} (${conn.currency})'
                                : 'No Facebook advertising account linked to this agent.',
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isSyncing ? null : _triggerSync,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync, size: 16),
                    label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                  ),
                  if (conn.isConnected)
                    TextButton(
                      onPressed: () => _showDisconnectDialog(),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                      child: const Text('Disconnect'),
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_user_outlined, size: 16, color: AppTheme.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    'Granted Meta Permissions:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              ...conn.grantedPermissions.map((perm) {
                return Chip(
                  label: Text(perm, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                  backgroundColor: AppTheme.background,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }),
              if (conn.lastSyncAt != null)
                Text(
                  'Last Sync: ${DateFormat('yyyy-MM-dd HH:mm').format(conn.lastSyncAt!)}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid({
    required double totalSpend,
    required int totalImpressions,
    required int totalReach,
    required int totalClicks,
    required double avgCtr,
    required double avgCpc,
    required double avgCpm,
    required int totalLeads,
    required double avgCpl,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 1000 ? 4 : (constraints.maxWidth >= 600 ? 2 : 1);

        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppTheme.spacingMd,
          mainAxisSpacing: AppTheme.spacingMd,
          childAspectRatio: 2.2,
          children: [
            _kpiCard('Total Ad Spend', currencyFormatter.format(totalSpend), Icons.payments_outlined, AppTheme.primary),
            _kpiCard('Total Impressions / Reach', '${integerFormatter.format(totalImpressions)} / ${integerFormatter.format(totalReach)}', Icons.visibility_outlined, AppTheme.secondary),
            _kpiCard('Link Clicks & CTR', '${integerFormatter.format(totalClicks)} (${avgCtr.toStringAsFixed(2)}%)', Icons.touch_app_outlined, AppTheme.accent),
            _kpiCard('Avg CPC & CPM', '${currencyFormatter.format(avgCpc)} / ${currencyFormatter.format(avgCpm)}', Icons.calculate_outlined, Colors.purple),
            _kpiCard('Total Instant Leads', '$totalLeads leads', Icons.assignment_ind_outlined, AppTheme.success),
            _kpiCard('Cost Per Lead (CPL)', currencyFormatter.format(avgCpl), Icons.price_check_outlined, Colors.teal),
          ],
        );
      },
    );
  }

  Widget _kpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerQualitySection({
    required int totalLeads,
    required int totalContactable,
    required int totalQualified,
    required int totalViewings,
    required int totalConverted,
    required double? costPerQualified,
    required double? costPerViewing,
  }) {
    return Container(
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta Ad Buyer Quality & Pipeline Conversion',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Correlates advertising expenditure directly with real qualified prospects and site viewings.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Deterministic Correlated Metrics',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accent),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Funnel Steps
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _funnelStep('1. Instant Leads', '$totalLeads', 'Captured via forms', Colors.blue),
              const Icon(Icons.arrow_forward, size: 16, color: AppTheme.textHint),
              _funnelStep('2. Contactable', '$totalContactable', 'PDPA Eligible', Colors.indigo),
              const Icon(Icons.arrow_forward, size: 16, color: AppTheme.textHint),
              _funnelStep('3. Qualified', '$totalQualified', 'Score >= 70%', Colors.orange),
              const Icon(Icons.arrow_forward, size: 16, color: AppTheme.textHint),
              _funnelStep('4. Viewings', '$totalViewings', 'Scheduled Walkthroughs', Colors.teal),
              const Icon(Icons.arrow_forward, size: 16, color: AppTheme.textHint),
              _funnelStep('5. Converted', '$totalConverted', 'Closed Deals', AppTheme.success),
            ],
          ),
          const SizedBox(height: AppTheme.spacingLg),

          // Quality Economics
          Row(
            children: [
              Expanded(
                child: _qualityMetricTile(
                  'Cost per Qualified Buyer',
                  costPerQualified != null ? currencyFormatter.format(costPerQualified) : 'Unavailable',
                  'Total spend divided by verified qualified buyers',
                  Icons.verified_outlined,
                  AppTheme.primary,
                ),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              Expanded(
                child: _qualityMetricTile(
                  'Cost per Viewing Appointment',
                  costPerViewing != null ? currencyFormatter.format(costPerViewing) : 'Unavailable',
                  'Total spend divided by showroom/site viewing bookings',
                  Icons.calendar_today_outlined,
                  AppTheme.secondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _funnelStep(String step, String count, String subtext, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(count, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(subtext, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _qualityMetricTile(String title, String value, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 10, color: AppTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignComparisonTable() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Campaign Performance & Comparison',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Compares individual advertising campaigns on both click efficiency and actual buyer quality.',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacingMd),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              columns: const [
                DataColumn(label: Text('Campaign Name', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Spend', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Clicks / CTR', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Leads / CPL', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Qualified (Rate)', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('Cost / Qual. Buyer', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: _campaigns.map((camp) {
                final qual = camp.qualityMetrics;
                return DataRow(
                  cells: [
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(camp.campaignName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Objective: ${camp.objective}', style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: camp.status == 'ACTIVE' ? AppTheme.success.withValues(alpha: 0.15) : AppTheme.textHint.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          camp.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: camp.status == 'ACTIVE' ? AppTheme.success : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(currencyFormatter.format(camp.spend))),
                    DataCell(Text('${camp.clicks} (${camp.ctr.toStringAsFixed(2)}%)')),
                    DataCell(Text('${camp.leads} (${currencyFormatter.format(camp.costPerLead)})')),
                    DataCell(Text('${qual.qualifiedProspects} (${qual.qualificationRate.toStringAsFixed(1)}%)')),
                    DataCell(Text(qual.costPerQualifiedBuyer != null ? currencyFormatter.format(qual.costPerQualifiedBuyer!) : 'N/A')),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIIntelligenceSection() {
    final ai = _aiInsight;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppTheme.accent, size: 24),
                  const SizedBox(width: AppTheme.spacingSm),
                  Text(
                    'Gemini AI Advertising Intelligence',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _isAnalyzingAI ? null : _triggerAIAnalysis,
                icon: _isAnalyzingAI
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 16),
                label: Text(_isAnalyzingAI ? 'Analyzing...' : 'Re-Analyze with Gemini'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (ai != null) ...[
            Wrap(
              spacing: 12,
              children: [
                Chip(
                  label: Text('Data Period: ${ai.dataPeriod}', style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppTheme.background,
                ),
                Chip(
                  label: Text('Sample Size: ${ai.sampleSizeLeads} leads', style: const TextStyle(fontSize: 11)),
                  backgroundColor: AppTheme.background,
                ),
                Chip(
                  label: Text('Statistical Confidence: ${ai.statisticalConfidence}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  backgroundColor: ai.statisticalConfidence == 'High'
                      ? AppTheme.success.withValues(alpha: 0.15)
                      : (ai.statisticalConfidence == 'Moderate'
                          ? Colors.orange.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15)),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ai.executiveSummary,
                style: const TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Top Performing Angles', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
                      const SizedBox(height: 6),
                      ...ai.topPerformingCampaigns.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.check_circle_outline, size: 14, color: AppTheme.success),
                                const SizedBox(width: 6),
                                Expanded(child: Text(e, style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Inefficient Campaigns / Budget Leaks', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 6),
                      ...ai.inefficientCampaigns.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_amber_outlined, size: 14, color: Colors.orange),
                                const SizedBox(width: 6),
                                Expanded(child: Text(e, style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            const Text('Creative & Audience Recommendations:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...ai.creativeAndAudienceRecommendations.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.accent),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                )),

            const SizedBox(height: AppTheme.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingSm),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Budget Advisory (Informational Only): ${ai.budgetAdvisory}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text('Click "Re-Analyze with Gemini" to generate strategic AI intelligence on your Meta campaigns.'),
          ],
        ],
      ),
    );
  }

  Widget _buildGovernanceNotice() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 20, color: AppTheme.textSecondary),
          SizedBox(width: AppTheme.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Read-Only Advertising Governance & PDPA Compliance',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                SizedBox(height: 2),
                Text(
                  'PropMatch AI operates in strict read-only mode for advertising management. AI recommendations never automatically alter ad budgets or campaign parameters. All Instant Form enquiries are captured with consent evidence under the Malaysian Personal Data Protection Act (PDPA 2010).',
                  style: TextStyle(fontSize: 11, color: AppTheme.textHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Meta Advertising Account?'),
        content: const Text(
          'Disconnecting will clear server-side access tokens and stop incremental campaign synchronizations. Your historical prospect data will remain intact.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await _adsService.disconnectAccount(widget.ownerId);
              await _loadInitialData();
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
