import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../models/buyer_model.dart';
import '../models/lead_model.dart';
import '../models/audience_segment_model.dart';
import '../models/match_model.dart';
import '../models/campaign_model.dart';
import '../services/demo_data_service.dart';
import '../services/ai_service.dart';
import '../services/matching_service.dart';
import '../services/marketing_service.dart';

class AppStateProvider extends ChangeNotifier {
  final String _currentOwnerId = 'demo-agent-001';
  String get currentOwnerId => _currentOwnerId;

  // Projects
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  final bool _isLoadingProjects = false;

  // Buyers
  final List<BuyerModel> _buyers = [];
  bool _hasGeneratedDemoBuyers = false;
  String _buyerSearchQuery = '';
  String _buyerStatusFilter = 'All';

  // AI Audience Discovery
  List<AudienceSegmentModel> _audienceSegments = [];
  bool _isDiscoveringAudience = false;
  Map<String, List<GeographicTarget>> _geoStrategies = {}; // segmentId -> targets
  Map<String, SegmentMarketingContent> _segmentMarketingContent = {}; // segmentId -> content
  bool _isGeneratingSegmentContent = false;
  String? _generatingContentForSegmentId;

  // AI Buyer Matching
  List<MatchModel> _matches = [];
  bool _isMatching = false;
  MatchModel? _selectedMatch;

  // Leads
  List<LeadModel> _leads = [];

  // Campaigns
  final List<CampaignModel> _campaigns = [];

  // Marketing Assistant
  MarketingContentResult? _generatedMarketingContent;
  AudienceSegmentModel? _selectedAudienceForMarketing;
  bool _isGeneratingMarketing = false;

  // Getters
  List<ProjectModel> get projects => _projects;
  ProjectModel? get selectedProject => _selectedProject;
  bool get isLoadingProjects => _isLoadingProjects;

  List<BuyerModel> get buyers {
    return _buyers.where((b) {
      final matchesSearch = _buyerSearchQuery.isEmpty ||
          b.name.toLowerCase().contains(_buyerSearchQuery.toLowerCase()) ||
          b.preferredLocation.toLowerCase().contains(_buyerSearchQuery.toLowerCase()) ||
          b.propertyType.toLowerCase().contains(_buyerSearchQuery.toLowerCase());
      final matchesStatus = _buyerStatusFilter == 'All' || b.status == _buyerStatusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  int get totalBuyerCount => _buyers.length;
  int get demoBuyerCount => _buyers.where((b) => b.isDemo).length;
  bool get hasGeneratedDemoBuyers => _hasGeneratedDemoBuyers;
  String get buyerSearchQuery => _buyerSearchQuery;
  String get buyerStatusFilter => _buyerStatusFilter;

  List<AudienceSegmentModel> get audienceSegments => _audienceSegments;
  bool get isDiscoveringAudience => _isDiscoveringAudience;
  Map<String, List<GeographicTarget>> get geoStrategies => _geoStrategies;
  Map<String, SegmentMarketingContent> get segmentMarketingContent => _segmentMarketingContent;
  bool get isGeneratingSegmentContent => _isGeneratingSegmentContent;
  String? get generatingContentForSegmentId => _generatingContentForSegmentId;

  List<MatchModel> get matches => _matches;
  bool get isMatching => _isMatching;
  MatchModel? get selectedMatch => _selectedMatch;

  List<LeadModel> get leads => _leads;
  List<CampaignModel> get campaigns => _campaigns;

  MarketingContentResult? get generatedMarketingContent => _generatedMarketingContent;
  AudienceSegmentModel? get selectedAudienceForMarketing => _selectedAudienceForMarketing;
  bool get isGeneratingMarketing => _isGeneratingMarketing;

  // Dashboard Stats & Acquisition Metrics
  int get activeProjectCount => _projects.length;
  int get qualifiedLeadCount => _leads.where((l) => l.status == 'Qualified' || l.status == 'Won').length;
  int get newEnquiryCount => _leads.where((l) => l.status == 'New').length;
  int get awaitingFollowupCount => _leads.where((l) => l.status == 'Contacted' || l.status == 'Negotiating').length;
  int get genuineLeadCount => _leads.where((l) => !l.isDemo).length;
  int get demoLeadCount => _leads.where((l) => l.isDemo).length;

  double get pipelineConversionRate {
    if (_leads.isEmpty) return 0.0;
    return (qualifiedLeadCount / _leads.length) * 100;
  }

  Map<String, int> get leadsBySource {
    final Map<String, int> map = {
      'WhatsApp Enquiry': 0,
      'Facebook Ads': 0,
      'Google Search': 0,
      'Referral': 0,
    };
    for (final l in _leads) {
      if (map.containsKey(l.source)) {
        map[l.source] = map[l.source]! + 1;
      } else {
        map[l.source] = 1;
      }
    }
    return map;
  }

  double get averageMatchRate {
    if (_matches.isEmpty) return 0.0;
    final total = _matches.fold(0.0, (sum, m) => sum + m.overallMatchPercentage);
    return total / _matches.length;
  }

  AppStateProvider() {
    _initData();
  }

  void _initData() {
    _projects = DemoDataService.getInitialProjects();
    if (_projects.isNotEmpty) {
      _selectedProject = _projects.first;
    }
    _leads = DemoDataService.getInitialLeads();
  }

  // --- PROJECT ACTIONS ---
  void selectProject(ProjectModel project) {
    _selectedProject = project;
    // Clear project-specific AI results
    _audienceSegments = [];
    _matches = [];
    _generatedMarketingContent = null;
    _geoStrategies = {};
    _segmentMarketingContent = {};
    notifyListeners();
  }

  void addProject(ProjectModel project) {
    _projects.insert(0, project);
    _selectedProject = project;
    notifyListeners();
  }

  void updateProject(ProjectModel project) {
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index != -1) {
      _projects[index] = project;
      if (_selectedProject?.id == project.id) {
        _selectedProject = project;
      }
      notifyListeners();
    }
  }

  void deleteProject(String projectId) {
    _projects.removeWhere((p) => p.id == projectId);
    if (_selectedProject?.id == projectId) {
      _selectedProject = _projects.isNotEmpty ? _projects.first : null;
      _audienceSegments = [];
      _matches = [];
    }
    notifyListeners();
  }

  // --- BUYER ACTIONS ---
  void generate100DemoBuyers() {
    final demoBuyers = DemoDataService.generate100DemoBuyers();
    // Remove previous demo buyers to avoid duplicates
    _buyers.removeWhere((b) => b.isDemo);
    _buyers.addAll(demoBuyers);
    _hasGeneratedDemoBuyers = true;
    notifyListeners();
  }

  void addBuyer(BuyerModel buyer) {
    _buyers.insert(0, buyer);
    notifyListeners();
  }

  void setBuyerSearchQuery(String query) {
    _buyerSearchQuery = query;
    notifyListeners();
  }

  void setBuyerStatusFilter(String status) {
    _buyerStatusFilter = status;
    notifyListeners();
  }

  // --- AI AUDIENCE DISCOVERY ---
  Future<void> runAudienceDiscovery([ProjectModel? project]) async {
    final targetProject = project ?? _selectedProject;
    if (targetProject == null) return;

    _isDiscoveringAudience = true;
    _geoStrategies = {};
    _segmentMarketingContent = {};
    notifyListeners();

    // Fast asynchronous simulation for sleek UI responsiveness
    await Future.delayed(const Duration(milliseconds: 600));

    _audienceSegments = AIService.discoverAudienceSegments(targetProject);

    // Auto-generate geographic strategies for all segments
    for (final seg in _audienceSegments) {
      _geoStrategies[seg.id] = AIService.generateGeographicStrategy(targetProject, seg);
    }

    if (_audienceSegments.isNotEmpty) {
      _selectedAudienceForMarketing = _audienceSegments.first;
    }
    _isDiscoveringAudience = false;
    notifyListeners();
  }

  /// Generates platform-specific marketing content for a single audience segment.
  Future<void> generateSegmentMarketing(AudienceSegmentModel segment) async {
    if (_selectedProject == null) return;

    _isGeneratingSegmentContent = true;
    _generatingContentForSegmentId = segment.id;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));

    _segmentMarketingContent[segment.id] =
        AIService.generateSegmentMarketingContent(_selectedProject!, segment);

    _isGeneratingSegmentContent = false;
    _generatingContentForSegmentId = null;
    notifyListeners();
  }

  // --- AI BUYER MATCHING ---
  Future<void> runBuyerMatching([ProjectModel? project]) async {
    final targetProject = project ?? _selectedProject;
    if (targetProject == null) return;

    // If buyers list is empty, generate demo buyers automatically
    if (_buyers.isEmpty) {
      generate100DemoBuyers();
    }

    _isMatching = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 700));

    _matches = MatchingService.matchBuyersWithProject(
      buyers: _buyers,
      project: targetProject,
    );

    if (_matches.isNotEmpty) {
      _selectedMatch = _matches.first;
    }

    _isMatching = false;
    notifyListeners();
  }

  void selectMatch(MatchModel match) {
    _selectedMatch = match;
    notifyListeners();
  }

  // --- MARKETING ASSISTANT ---
  void selectAudienceForMarketing(AudienceSegmentModel? segment) {
    _selectedAudienceForMarketing = segment;
    notifyListeners();
  }

  Future<void> generateMarketingContent({
    ProjectModel? project,
    AudienceSegmentModel? audience,
  }) async {
    final targetProject = project ?? _selectedProject;
    if (targetProject == null) return;

    _isGeneratingMarketing = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    _generatedMarketingContent = MarketingService.generateContent(
      project: targetProject,
      audience: audience ?? _selectedAudienceForMarketing,
    );

    _isGeneratingMarketing = false;
    notifyListeners();
  }

  // --- LEAD ACTIONS ---
  void addLeadFromMatch(MatchModel match) {
    final newLead = LeadModel(
      ownerId: _currentOwnerId,
      buyerId: match.buyerId,
      projectId: match.projectId,
      buyerName: '${match.buyerName} ${match.isDemoBuyer ? "(Demo)" : ""}',
      projectName: match.projectName,
      status: 'New',
      source: 'AI Buyer Matching (${match.overallMatchPercentage.toStringAsFixed(0)}% Match)',
      notes: 'Generated via AI Match engine. Compatibility: ${match.explanation}',
      isDemo: match.isDemoBuyer,
    );
    _leads.insert(0, newLead);
    notifyListeners();
  }

  void updateLeadStatus(String leadId, String newStatus) {
    final index = _leads.indexWhere((l) => l.id == leadId);
    if (index != -1) {
      _leads[index] = _leads[index].copyWith(status: newStatus);
      notifyListeners();
    }
  }

  // --- CAMPAIGN ACTIONS ---
  void createCampaign({
    required String name,
    required String platform,
    required String headline,
    required String body,
    required String callToAction,
  }) {
    if (_selectedProject == null) return;
    final campaign = CampaignModel(
      ownerId: _currentOwnerId,
      name: name,
      projectId: _selectedProject!.id,
      projectName: _selectedProject!.name,
      audienceSegmentId: _selectedAudienceForMarketing?.id,
      audienceSegmentName: _selectedAudienceForMarketing?.name ?? 'General Audience',
      platform: platform,
      contentHeadline: headline,
      contentBody: body,
      callToAction: callToAction,
      status: 'Active',
      reach: 1240,
      clicks: 86,
      enquiries: 14,
    );
    _campaigns.insert(0, campaign);
    notifyListeners();
  }
}
