import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/user_model.dart';
import '../../models/project_model.dart';
import '../../models/enquiry_model.dart';
import '../../providers/app_state_provider.dart';
import '../../services/lead_ingestion/lead_ingestion_pipeline.dart';

/// Phase 4.4 Channel A: Personal Agent Landing Page.
/// Publicly accessible landing page showcasing the individual agent's profile,
/// verified REN credentials, selected portfolio listings, and buyer enquiry form
/// with campaign attribution (UTMs) and granular PDPA consent checkboxes.
class AgentLandingPageScreen extends StatefulWidget {
  final UserModel agent;
  final List<ProjectModel>? featuredProjects;
  final String? campaignId;
  final String? utmSource;
  final String? utmMedium;
  final String? utmCampaign;
  final String? referralSource;
  final VoidCallback? onBackToApp;

  const AgentLandingPageScreen({
    super.key,
    required this.agent,
    this.featuredProjects,
    this.campaignId,
    this.utmSource,
    this.utmMedium,
    this.utmCampaign,
    this.referralSource,
    this.onBackToApp,
  });

  @override
  State<AgentLandingPageScreen> createState() => _AgentLandingPageScreenState();
}

class _AgentLandingPageScreenState extends State<AgentLandingPageScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();

  String _preferredLocation = 'Batu Kawan';
  String _preferredState = 'Penang';
  String _propertyType = 'Condominium';
  double _budgetMin = 400000;
  double _budgetMax = 650000;
  String _purchasePurpose = 'Own Stay';
  String _buyingTimeline = '1-3 months';
  final String _bedrooms = '3 Bedrooms';

  // Distinct Consent Options (PDPA Compliance)
  bool _enquiryConsentAgreed = true; // Specific consent to answer enquiry
  bool _marketingConsentAgreed = false; // Optional distinct future marketing opt-in

  bool _isSubmitting = false;
  String? _submissionError;
  EnquiryModel? _submittedEnquiry;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitEnquiry() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_enquiryConsentAgreed) {
      setState(() {
        _submissionError = 'You must consent to being contacted regarding this enquiry.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final appState = context.read<AppStateProvider>();

      final rawPayload = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'location': _preferredLocation,
        'state': _preferredState,
        'propertyType': _propertyType,
        'budgetMin': _budgetMin,
        'budgetMax': _budgetMax,
        'purpose': _purchasePurpose,
        'timeline': _buyingTimeline,
        'bedrooms': _bedrooms,
        'notes': _notesController.text.trim(),
        'campaignId': widget.campaignId,
        'landingPageId': widget.agent.ownerId,
        'referralSource': widget.referralSource ?? 'Agent Personal Page',
        'utmSource': widget.utmSource ?? 'direct_share',
        'utmMedium': widget.utmMedium,
        'utmCampaign': widget.utmCampaign,
        'consentEvidence': 'Personal Agent Landing Page Form (Response Consent: Granted, Future Marketing: ${_marketingConsentAgreed ? 'Opted-In' : 'No'})',
        'enquiryConsentGranted': _enquiryConsentAgreed,
        'marketingConsentGranted': _marketingConsentAgreed,
      };

      // Ingest via LeadIngestionPipeline
      final result = await LeadIngestionPipeline.processEnquiry(
        ownerId: widget.agent.ownerId,
        sourceType: 'Direct Website',
        rawPayload: rawPayload,
        existingProspects: appState.allProspects,
        existingBuyers: appState.buyers,
        availableProjects: appState.projects,
      );

      // Save enquiry and prospect into state/repository
      await appState.saveIncomingEnquiry(result.enquiry);

      if (result.createdProspect != null) {
        await appState.prospectRepository.createProspect(result.createdProspect!);
      }

      setState(() {
        _isSubmitting = false;
        _submittedEnquiry = result.enquiry;
      });
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _submissionError = 'Submission error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.onBackToApp != null
          ? AppBar(
              backgroundColor: AppTheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                onPressed: widget.onBackToApp,
              ),
              title: Text(
                'Previewing Agent Landing Page (${widget.agent.fullName})',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
            )
          : null,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero / Agent Profile Section
            _buildAgentHero(isMobile),

            // Main Content: Portfolio & Form
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 16.0 : 48.0,
                vertical: 32.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: isMobile
                    ? Column(
                        children: [
                          _buildPortfolioSection(),
                          const SizedBox(height: 32),
                          _buildEnquiryFormCard(),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _buildPortfolioSection()),
                          const SizedBox(width: 32),
                          Expanded(flex: 5, child: _buildEnquiryFormCard()),
                        ],
                      ),
              ),
            ),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentHero(bool isMobile) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20.0 : 64.0,
        vertical: isMobile ? 32.0 : 48.0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Circle
              CircleAvatar(
                radius: isMobile ? 36 : 48,
                backgroundColor: AppTheme.primary,
                child: Text(
                  widget.agent.fullName.isNotEmpty
                      ? widget.agent.fullName.substring(0, 1).toUpperCase()
                      : 'A',
                  style: TextStyle(
                    fontSize: isMobile ? 28 : 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 24),

              // Agent Credentials & Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.agent.fullName,
                            style: TextStyle(
                              fontSize: isMobile ? 22 : 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // REN Badge (Strictly display verified only if isRenVerified == true)
                        if (widget.agent.isRenVerified && widget.agent.renNumber.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified ${widget.agent.renNumber}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (widget.agent.renNumber.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'REN: ${widget.agent.renNumber} (Unverified)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.agent.agencyName.isNotEmpty ? widget.agent.agencyName : 'Independent Real Estate Specialist'} • ${widget.agent.region}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.agent.bio,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFE2E8F0),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioSection() {
    final appState = context.watch<AppStateProvider>();
    final projects = widget.featuredProjects ?? appState.projects;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Featured Developments & Properties',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Curated high-growth residential opportunities across Northern Malaysia.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 20),

        if (projects.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Center(
              child: Text(
                'No featured listings currently selected. You can still submit your property requirements below.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: projects.length.clamp(0, 3),
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final proj = projects[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            proj.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            proj.propertyType,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${proj.location}, ${proj.state}',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      proj.description,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Indicative Price',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            Text(
                              'From RM${proj.startingPrice.toInt()}k',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _preferredLocation = proj.location;
                              _preferredState = proj.state;
                              _propertyType = proj.propertyType;
                              _budgetMin = proj.startingPrice;
                              _budgetMax = proj.maximumPrice > proj.startingPrice
                                  ? proj.maximumPrice
                                  : proj.startingPrice * 1.25;
                            });
                          },
                          icon: const Icon(Icons.touch_app, size: 14),
                          label: const Text('Enquire for this'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEnquiryFormCard() {
    if (_submittedEnquiry != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Color(0xFFD1FAE5),
              child: Icon(Icons.check, size: 32, color: Color(0xFF059669)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enquiry Submitted Successfully!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Thank you, ${_submittedEnquiry!.fullName}. ${widget.agent.fullName} has received your preferences and will prepare a tailored recommendation shortly.',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Reference ID: ${_submittedEnquiry!.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _submittedEnquiry = null;
                  _nameController.clear();
                  _phoneController.clear();
                  _emailController.clear();
                  _notesController.clear();
                });
              },
              child: const Text('Submit Another Inquiry'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.send_outlined, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Buyer Enquiry Form',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Share your requirements to receive matched properties directly.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const Divider(height: 24),

            if (_submissionError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _submissionError!,
                        style: const TextStyle(fontSize: 12, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            // Name (Required)
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                hintText: 'e.g. Ahmad Farhan bin Osman',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Full name is required' : null,
            ),
            const SizedBox(height: 14),

            // Phone (Required, Malaysian Format)
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number (WhatsApp) *',
                hintText: 'e.g. 012-3456789',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone number is required';
                if (!v.contains(RegExp(r'\d{7,}'))) return 'Please enter a valid phone number';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Email (Optional)
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address (Optional)',
                hintText: 'e.g. buyer@example.com',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            // Preferred Location & Property Type
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _preferredLocation,
                    decoration: const InputDecoration(
                      labelText: 'Location',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Batu Kawan', child: Text('Batu Kawan')),
                      DropdownMenuItem(value: 'George Town', child: Text('George Town')),
                      DropdownMenuItem(value: 'Bayan Lepas', child: Text('Bayan Lepas')),
                      DropdownMenuItem(value: 'Kulim', child: Text('Kulim')),
                      DropdownMenuItem(value: 'Butterworth', child: Text('Butterworth')),
                    ],
                    onChanged: (v) => setState(() => _preferredLocation = v ?? 'Batu Kawan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _propertyType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Condominium', child: Text('Condominium')),
                      DropdownMenuItem(value: 'Serviced Residence', child: Text('Serviced Residence')),
                      DropdownMenuItem(value: 'Terrace House', child: Text('Terrace House')),
                      DropdownMenuItem(value: 'Semi-Detached', child: Text('Semi-D')),
                    ],
                    onChanged: (v) => setState(() => _propertyType = v ?? 'Condominium'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Budget Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Budget Ceiling:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(
                  'RM${(_budgetMax / 1000).toInt()}k',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ],
            ),
            Slider(
              value: _budgetMax,
              min: 300000,
              max: 2000000,
              divisions: 34,
              label: 'RM${(_budgetMax / 1000).toInt()}k',
              onChanged: (v) => setState(() => _budgetMax = v),
            ),

            // Purpose & Timeline
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _purchasePurpose,
                    decoration: const InputDecoration(
                      labelText: 'Purpose',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Own Stay', child: Text('Own Stay')),
                      DropdownMenuItem(value: 'Investment', child: Text('Investment')),
                      DropdownMenuItem(value: 'Both', child: Text('Both')),
                    ],
                    onChanged: (v) => setState(() => _purchasePurpose = v ?? 'Own Stay'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _buyingTimeline,
                    decoration: const InputDecoration(
                      labelText: 'Timeline',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Immediately', child: Text('Immediately')),
                      DropdownMenuItem(value: '1-3 months', child: Text('1-3 months')),
                      DropdownMenuItem(value: '3-6 months', child: Text('3-6 months')),
                      DropdownMenuItem(value: 'Exploring', child: Text('Exploring')),
                    ],
                    onChanged: (v) => setState(() => _buyingTimeline = v ?? '1-3 months'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Additional Notes (Optional)
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Special Requirements (Optional)',
                hintText: 'e.g. Near IKEA, high floor, 2 car parks',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),

            // Granular PDPA Consent Checkbox 1: Response Consent (Required for form submission)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _enquiryConsentAgreed,
                  onChanged: (v) => setState(() => _enquiryConsentAgreed = v ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'I consent to ${widget.agent.fullName} contacting me specifically regarding this property inquiry via WhatsApp, Phone or Email under Malaysian PDPA 2010. *',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF334155), height: 1.3),
                    ),
                  ),
                ),
              ],
            ),

            // Granular PDPA Consent Checkbox 2: Optional Marketing Opt-In (Not compulsory)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _marketingConsentAgreed,
                  onChanged: (v) => setState(() => _marketingConsentAgreed = v ?? false),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: const Text(
                      'Optional: I wish to receive future new project launches, market reports and personalized property recommendations.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _handleSubmitEnquiry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Submit Property Enquiry',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      child: Center(
        child: Column(
          children: [
            Text(
              'Powered by PropMatch AI — Intelligent Property Lead Discovery & Matching for Malaysian Real Estate Agents',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Compliant with Malaysian Personal Data Protection Act (PDPA) 2010. Your details are shared solely with ${widget.agent.fullName}.',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
