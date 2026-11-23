import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/project_model.dart';
import '../models/buyer_model.dart';
import '../models/lead_model.dart';
import '../models/followup_model.dart';
import '../models/audience_segment_model.dart';
import '../models/match_model.dart';
import '../models/campaign_model.dart';
import '../models/consent_record_model.dart';
import '../models/user_model.dart';
import '../models/prospect_model.dart';
import '../models/prospect_source_model.dart';
import '../models/prospect_consent_event_model.dart';
import '../models/prospect_activity_model.dart';
import '../models/prospect_import_job_model.dart';
import '../models/enquiry_model.dart';
import '../models/agent_preferences_model.dart';
import '../models/subscription_model.dart';
import '../services/lead_distribution/lead_distribution_engine.dart';
import '../services/crm_import/import_validator.dart';
import '../services/crm_import/duplicate_detector.dart';
import '../services/crm_import/batch_importer.dart';
import '../services/lead_ingestion/lead_ingestion_pipeline.dart';
import '../repositories/project_repository.dart';
import '../repositories/buyer_repository.dart';
import '../repositories/lead_repository.dart';
import '../repositories/followup_repository.dart';
import '../repositories/campaign_repository.dart';
import '../repositories/consent_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/prospect_repository.dart';
import '../repositories/firestore_project_repository.dart';
import '../repositories/firestore_buyer_repository.dart';
import '../repositories/firestore_lead_repository.dart';
import '../repositories/firestore_followup_repository.dart';
import '../repositories/firestore_campaign_repository.dart';
import '../repositories/firestore_consent_repository.dart';
import '../repositories/firestore_prospect_repository.dart';
import '../repositories/firebase_auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/demo_data_service.dart';
import '../services/ai_service.dart';
import '../services/marketing_service.dart';
import '../services/ai_backend_service.dart';
import '../services/prospect_sources/source_registry.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AppStateProvider extends ChangeNotifier {
  final ProjectRepository _projectRepository;
  final BuyerRepository _buyerRepository;
  final LeadRepository _leadRepository;
  final FollowupRepository _followupRepository;
  final CampaignRepository _campaignRepository;
  final ConsentRepository _consentRepository;
  final AuthRepository _authRepository;
  final ProspectRepository _prospectRepository;
  AIBackendService _aiService;

  PropertyAnalysisResult? _currentPropertyAnalysis;
  PropertyAnalysisResult? get currentPropertyAnalysis => _currentPropertyAnalysis;
  bool _isAnalyzingProperty = false;
  bool get isAnalyzingProperty => _isAnalyzingProperty;
  String? _propertyAnalysisError;
  String? get propertyAnalysisError => _propertyAnalysisError;
  final Map<String, PropertyAnalysisResult> _cachedPropertyAnalyses = {};
  Map<String, PropertyAnalysisResult> get cachedPropertyAnalyses =>
      Map.unmodifiable(_cachedPropertyAnalyses);
  AIBackendService get aiService => _aiService;
  bool get isUsingAIFallback => _aiService.isFallbackActive;
  String? get lastAIError => _aiService.lastError;
  String get currentAIModel => 'gemini-3.5-flash-lite';

  void setAIService(AIBackendService service) {
    _aiService = service;
    _cachedPropertyAnalyses.clear();
    _cachedAudienceSegments.clear();
    _audienceDiscoveryError = null;
    notifyListeners();
  }

  StreamSubscription<AuthUser?>? _authSubscription;
  int _authSessionId = 0;
  String? _activeAuthUid;

  final String _defaultOwnerId = 'demo-agent-001';
  String get currentOwnerId => _authRepository.currentUser?.uid ?? _defaultOwnerId;

  // Repository Getters
  ProjectRepository get projectRepository => _projectRepository;
  BuyerRepository get buyerRepository => _buyerRepository;
  LeadRepository get leadRepository => _leadRepository;
  FollowupRepository get followupRepository => _followupRepository;
  CampaignRepository get campaignRepository => _campaignRepository;
  ConsentRepository get consentRepository => _consentRepository;
  AuthRepository get authRepository => _authRepository;
  ProspectRepository get prospectRepository => _prospectRepository;

  // Prospect Intelligence (Phase 4.1)
  List<ProspectModel> _prospects = [];
  List<ProspectSourceModel> _prospectSources = [];
  ProspectModel? _selectedProspect;
  List<ProspectConsentEventModel> _selectedProspectConsents = [];
  List<ProspectActivityModel> _selectedProspectActivities = [];
  bool _isLoadingProspects = false;
  String? _prospectError;
  String _prospectSearchQuery = '';
  String _prospectStatusFilter = 'All';
  String _prospectEligibilityFilter = 'All';
  String _prospectSourceFilter = 'All';
  String _prospectVerificationFilter = 'All';
  bool _hasGeneratedDemoProspects = false;
  List<ProspectImportJobModel> _importJobs = [];

  // Incoming Enquiries Pipeline (Phase 4.3 & 4.4 Dual-Channel)
  List<EnquiryModel> _incomingEnquiries = [];
  String _enquiryStatusFilter = 'All';
  String _enquirySourceFilter = 'All';
  String _enquiryChannelFilter = 'All'; // 'All', 'Channel A: Agent-Generated', 'Channel B: Platform-Generated'
  String _enquiryCampaignFilter = 'All';
  String _enquirySearchQuery = '';
  bool _isLoadingEnquiries = false;
  String? _enquiryError;
  AgentPreferencesModel _agentPreferences = AgentPreferencesModel(agentId: 'demo-agent-001');
  final AgentSubscriptionModel _agentSubscription = AgentSubscriptionModel.defaultForAgent('demo-agent-001');

  // Consent Records
  List<ConsentRecordModel> _consentRecords = [];

  // Projects
  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  final bool _isLoadingProjects = false;

  // Buyers
  List<BuyerModel> _buyers = [];
  bool _hasGeneratedDemoBuyers = false;
  String _buyerSearchQuery = '';
  String _buyerStatusFilter = 'All';

  // AI Audience Discovery
  List<AudienceSegmentModel> _audienceSegments = [];
  bool _isDiscoveringAudience = false;
  String? _audienceDiscoveryError;
  String? _lastAgentObservations;
  final Map<String, List<AudienceSegmentModel>> _cachedAudienceSegments = {};
  Map<String, List<GeographicTarget>> _geoStrategies = {}; // segmentId -> targets
  Map<String, SegmentMarketingContent> _segmentMarketingContent = {}; // segmentId -> content
  bool _isGeneratingSegmentContent = false;
  String? _generatingContentForSegmentId;

  // AI Buyer Matching (Phase 3.3B)
  List<MatchModel> _matches = [];
  bool _isMatching = false;
  MatchModel? _selectedMatch;
  String? _matchingError;
  String _selectedMatchFilter = 'All';
  String _matchSortOrder = 'score';
  final Map<String, List<MatchModel>> _cachedProjectMatches = {};

  // Leads
  List<LeadModel> _leads = [];

  // Follow-ups
  List<FollowupModel> _followups = [];

  // Campaigns
  List<CampaignModel> _campaigns = [];

  // Marketing Assistant
  MarketingContentResult? _generatedMarketingContent;
  AudienceSegmentModel? _selectedAudienceForMarketing;
  bool _isGeneratingMarketing = false;

  // Agent Profile & Cloud Sync State
  UserModel? _currentUserProfile;
  bool _isLoadingData = false;
  String? _cloudSyncError;

  // Getters
  UserModel? get currentUserProfile => _currentUserProfile;
  bool get isLoadingData => _isLoadingData;
  String? get cloudSyncError => _cloudSyncError;
  bool get isDemoMode => currentOwnerId == _defaultOwnerId;

  List<ProjectModel> get projects => List.unmodifiable(_projects);
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

  List<BuyerModel> get allBuyers => List.unmodifiable(_buyers);
  int get totalBuyerCount => _buyers.length;
  int get demoBuyerCount => _buyers.where((b) => b.isDemo).length;
  bool get hasGeneratedDemoBuyers => _hasGeneratedDemoBuyers;
  String get buyerSearchQuery => _buyerSearchQuery;
  String get buyerStatusFilter => _buyerStatusFilter;

  List<AudienceSegmentModel> get audienceSegments => _audienceSegments;
  bool get isDiscoveringAudience => _isDiscoveringAudience;
  String? get audienceDiscoveryError => _audienceDiscoveryError;
  String? get lastAgentObservations => _lastAgentObservations;
  Map<String, List<AudienceSegmentModel>> get cachedAudienceSegments =>
      Map.unmodifiable(_cachedAudienceSegments);
  Map<String, List<GeographicTarget>> get geoStrategies => _geoStrategies;
  Map<String, SegmentMarketingContent> get segmentMarketingContent => _segmentMarketingContent;
  bool get isGeneratingSegmentContent => _isGeneratingSegmentContent;
  String? get generatingContentForSegmentId => _generatingContentForSegmentId;

  List<MatchModel> get matches => List.unmodifiable(_matches);
  bool get isMatching => _isMatching;
  MatchModel? get selectedMatch => _selectedMatch;
  String? get matchingError => _matchingError;
  String get selectedMatchFilter => _selectedMatchFilter;
  String get matchSortOrder => _matchSortOrder;

  List<MatchModel> get filteredMatches {
    var list = _matches.where((m) {
      if (_selectedMatchFilter == 'All') return true;
      if (_selectedMatchFilter == 'Excellent Match' || _selectedMatchFilter.contains('85')) return m.isExcellentMatch;
      if (_selectedMatchFilter == 'Good Match' || _selectedMatchFilter.contains('70')) return m.isGoodMatch;
      if (_selectedMatchFilter == 'Moderate Match' || _selectedMatchFilter.contains('50')) return m.isModerateMatch;
      if (_selectedMatchFilter == 'Low Match' || _selectedMatchFilter.contains('<50')) return m.isLowMatch;
      return true;
    }).toList();

    if (_matchSortOrder == 'score') {
      list.sort((a, b) => b.overallMatchPercentage.compareTo(a.overallMatchPercentage));
    } else if (_matchSortOrder == 'budget') {
      list.sort((a, b) => b.budgetScore.compareTo(a.budgetScore));
    } else if (_matchSortOrder == 'timeline') {
      list.sort((a, b) => b.timelineScore.compareTo(a.timelineScore));
    }
    return list;
  }

  int get totalEvaluatedMatches => _matches.length;
  int get excellentMatchesCount => _matches.where((m) => m.isExcellentMatch).length;
  int get goodMatchesCount => _matches.where((m) => m.isGoodMatch).length;
  int get moderateMatchesCount => _matches.where((m) => m.isModerateMatch).length;
  int get lowMatchesCount => _matches.where((m) => m.isLowMatch).length;

  List<LeadModel> get leads => List.unmodifiable(_leads);
  List<FollowupModel> get followups => List.unmodifiable(_followups);
  List<CampaignModel> get campaigns => List.unmodifiable(_campaigns);
  List<ConsentRecordModel> get consentRecords => List.unmodifiable(_consentRecords);

  // Prospect Intelligence Getters (Phase 4.1)
  List<ProspectModel> get allProspects => List.unmodifiable(_prospects);
  List<ProspectSourceModel> get prospectSources => List.unmodifiable(_prospectSources);
  ProspectModel? get selectedProspect => _selectedProspect;
  List<ProspectConsentEventModel> get selectedProspectConsents => List.unmodifiable(_selectedProspectConsents);
  List<ProspectActivityModel> get selectedProspectActivities => List.unmodifiable(_selectedProspectActivities);
  bool get isLoadingProspects => _isLoadingProspects;
  String? get prospectError => _prospectError;
  String get prospectSearchQuery => _prospectSearchQuery;
  String get prospectStatusFilter => _prospectStatusFilter;
  String get prospectEligibilityFilter => _prospectEligibilityFilter;
  String get prospectSourceFilter => _prospectSourceFilter;
  String get prospectVerificationFilter => _prospectVerificationFilter;
  bool get hasGeneratedDemoProspects => _hasGeneratedDemoProspects;
  List<ProspectImportJobModel> get importJobs => List.unmodifiable(_importJobs);

  List<ProspectModel> get filteredProspects {
    return _prospects.where((p) {
      final matchesSearch = _prospectSearchQuery.isEmpty ||
          p.fullName.toLowerCase().contains(_prospectSearchQuery.toLowerCase()) ||
          p.phone.contains(_prospectSearchQuery) ||
          p.email.toLowerCase().contains(_prospectSearchQuery.toLowerCase()) ||
          p.preferredLocations.any((l) => l.toLowerCase().contains(_prospectSearchQuery.toLowerCase())) ||
          p.preferredState.toLowerCase().contains(_prospectSearchQuery.toLowerCase());

      final matchesStatus = _prospectStatusFilter == 'All' || p.status == _prospectStatusFilter;
      final matchesEligibility = _prospectEligibilityFilter == 'All' || p.contactEligibility == _prospectEligibilityFilter;
      final matchesSource = _prospectSourceFilter == 'All' || p.primarySource == _prospectSourceFilter;
      final matchesVerification = _prospectVerificationFilter == 'All' || p.verificationStatus == _prospectVerificationFilter;

      return matchesSearch && matchesStatus && matchesEligibility && matchesSource && matchesVerification;
    }).toList();
  }

  int get totalProspectsCount => _prospects.length;
  int get discoveredProspectsCount => _prospects.where((p) => p.status == 'Discovered').length;
  int get importedProspectsCount => _prospects.where((p) => p.status == 'Imported').length;
  int get verifiedProspectsCount => _prospects.where((p) => p.isVerified).length;
  int get contactEligibleProspectsCount => _prospects.where((p) => p.isEligibleForContact).length;
  int get qualifiedProspectsCount => _prospects.where((p) => p.status == 'Qualified').length;
  int get demoProspectsCount => _prospects.where((p) => p.isDemo).length;

  // Incoming Enquiries Pipeline Getters (Phase 4.3)
  List<EnquiryModel> get allIncomingEnquiries => List.unmodifiable(_incomingEnquiries);
  bool get isLoadingEnquiries => _isLoadingEnquiries;
  String? get enquiryError => _enquiryError;
  String get enquiryStatusFilter => _enquiryStatusFilter;
  String get enquirySourceFilter => _enquirySourceFilter;
  String get enquiryChannelFilter => _enquiryChannelFilter;
  String get enquiryCampaignFilter => _enquiryCampaignFilter;
  String get enquirySearchQuery => _enquirySearchQuery;
  AgentPreferencesModel get agentPreferences => _agentPreferences;
  AgentSubscriptionModel get agentSubscription => _agentSubscription;

  List<EnquiryModel> get filteredEnquiries {
    return _incomingEnquiries.where((e) {
      final matchesSearch = _enquirySearchQuery.isEmpty ||
          e.fullName.toLowerCase().contains(_enquirySearchQuery.toLowerCase()) ||
          e.phone.contains(_enquirySearchQuery) ||
          e.email.toLowerCase().contains(_enquirySearchQuery.toLowerCase()) ||
          e.preferredLocation.toLowerCase().contains(_enquirySearchQuery.toLowerCase()) ||
          e.sourceName.toLowerCase().contains(_enquirySearchQuery.toLowerCase()) ||
          (e.campaignId != null && e.campaignId!.toLowerCase().contains(_enquirySearchQuery.toLowerCase()));

      final matchesStatus = _enquiryStatusFilter == 'All' || e.processingStatus == _enquiryStatusFilter;
      final matchesSource = _enquirySourceFilter == 'All' || e.sourceType == _enquirySourceFilter;
      final matchesChannel = _enquiryChannelFilter == 'All' ||
          (_enquiryChannelFilter.contains('Channel A') && e.isChannelA) ||
          (_enquiryChannelFilter.contains('Channel B') && e.isChannelB);
      final matchesCampaign = _enquiryCampaignFilter == 'All' || e.campaignId == _enquiryCampaignFilter;

      return matchesSearch && matchesStatus && matchesSource && matchesChannel && matchesCampaign;
    }).toList();
  }

  int get totalEnquiriesCount => _incomingEnquiries.length;
  int get qualifiedEnquiriesCount => _incomingEnquiries.where((e) => e.processingStatus == 'Qualified').length;
  int get pendingEnquiriesCount => _incomingEnquiries.where((e) => e.processingStatus == 'Pending' || e.processingStatus == 'Received').length;
  int get duplicateEnquiriesCount => _incomingEnquiries.where((e) => e.isDuplicate || e.processingStatus == 'Duplicate').length;
  int get ineligibleEnquiriesCount => _incomingEnquiries.where((e) => e.processingStatus == 'Ineligible' || e.contactEligibility == 'Do Not Contact').length;
  int get channelAEnquiriesCount => _incomingEnquiries.where((e) => e.isChannelA).length;
  int get channelBEnquiriesCount => _incomingEnquiries.where((e) => e.isChannelB).length;
  int get unassignedEnquiriesCount => _incomingEnquiries.where((e) => e.isUnassigned).length;

  Map<String, int> get campaignPerformance {
    final Map<String, int> map = {};
    for (final e in _incomingEnquiries) {
      if (e.campaignId != null && e.campaignId!.isNotEmpty) {
        map[e.campaignId!] = (map[e.campaignId!] ?? 0) + 1;
      }
    }
    return map;
  }

  Map<String, int> get enquiriesBySource {
    final Map<String, int> map = {
      'Property Portal': 0,
      'Partner Agency': 0,
      'Developer': 0,
      'Direct Website': 0,
      'CRM Import': 0,
    };
    for (final e in _incomingEnquiries) {
      if (map.containsKey(e.sourceType)) {
        map[e.sourceType] = map[e.sourceType]! + 1;
      } else {
        map[e.sourceType] = 1;
      }
    }
    return map;
  }

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
    final total = _matches.fold(0.0, (acc, m) => acc + m.overallMatchPercentage);
    return total / _matches.length;
  }

  double get averageMatchScore => averageMatchRate;

  // Dynamic Analytics Computations
  double get averageBuyerBudget {
    if (_buyers.isEmpty) return 0.0;
    final total = _buyers.fold(0.0, (acc, b) => acc + ((b.budgetMin + b.budgetMax) / 2));
    return total / _buyers.length;
  }

  String get topBuyerLocation {
    if (_buyers.isEmpty) return 'Batu Kawan';
    final Map<String, int> counts = {};
    for (final b in _buyers) {
      counts[b.preferredLocation] = (counts[b.preferredLocation] ?? 0) + 1;
    }
    String topLoc = 'Batu Kawan';
    int maxCount = -1;
    counts.forEach((loc, cnt) {
      if (cnt > maxCount) {
        maxCount = cnt;
        topLoc = loc;
      }
    });
    return topLoc;
  }

  Map<String, int> get buyersByLocation {
    final Map<String, int> map = {};
    for (final b in _buyers) {
      map[b.preferredLocation] = (map[b.preferredLocation] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get buyersByBudgetTier {
    final Map<String, int> map = {
      'Under RM 450,000': 0,
      'RM 450,000 - RM 650,000': 0,
      'RM 650,000 - RM 900,000': 0,
      'Above RM 900,000': 0,
    };
    for (final b in _buyers) {
      final mid = (b.budgetMin + b.budgetMax) / 2;
      if (mid < 450000) {
        map['Under RM 450,000'] = map['Under RM 450,000']! + 1;
      } else if (mid <= 650000) {
        map['RM 450,000 - RM 650,000'] = map['RM 450,000 - RM 650,000']! + 1;
      } else if (mid <= 900000) {
        map['RM 650,000 - RM 900,000'] = map['RM 650,000 - RM 900,000']! + 1;
      } else {
        map['Above RM 900,000'] = map['Above RM 900,000']! + 1;
      }
    }
    return map;
  }

  AppStateProvider({
    ProjectRepository? projectRepository,
    BuyerRepository? buyerRepository,
    LeadRepository? leadRepository,
    FollowupRepository? followupRepository,
    CampaignRepository? campaignRepository,
    ConsentRepository? consentRepository,
    AuthRepository? authRepository,
    ProspectRepository? prospectRepository,
    AIBackendService? aiService,
  })  : _projectRepository = projectRepository ??
            InMemoryProjectRepository(DemoDataService.getInitialProjects()),
        _buyerRepository = buyerRepository ?? InMemoryBuyerRepository(),
        _leadRepository = leadRepository ??
            InMemoryLeadRepository(DemoDataService.getInitialLeads()),
        _followupRepository = followupRepository ??
            InMemoryFollowupRepository(DemoDataService.getInitialFollowups()),
        _campaignRepository =
            campaignRepository ?? InMemoryCampaignRepository(),
        _consentRepository =
            consentRepository ?? InMemoryConsentRepository(),
        _authRepository = authRepository ?? InMemoryAuthRepository(),
        _prospectRepository = prospectRepository ??
            InMemoryProspectRepository(
              DemoDataService.getInitialDemoProspects(),
              ProspectSourceRegistry.getInitialSourcesForAgent('demo-agent-001'),
            ),
        _aiService = aiService ?? const LocalRuleBasedAIService() {
    _activeAuthUid = _authRepository.currentUser?.uid;
    _initData();
    _authSubscription = _authRepository.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Production factory configuring [AppStateProvider] with live Cloud Firestore
  /// and Firebase Authentication repositories for Flutter Web.
  factory AppStateProvider.firebase({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    AIBackendService? aiService,
  }) {
    return AppStateProvider(
      projectRepository: FirestoreProjectRepository(firestore: firestore),
      buyerRepository: FirestoreBuyerRepository(firestore: firestore),
      leadRepository: FirestoreLeadRepository(firestore: firestore),
      followupRepository: FirestoreFollowupRepository(firestore: firestore),
      campaignRepository: FirestoreCampaignRepository(firestore: firestore),
      consentRepository: FirestoreConsentRepository(firestore: firestore),
      prospectRepository: FirestoreProspectRepository(firestore: firestore),
      authRepository: FirebaseAuthRepository(
        firebaseAuth: firebaseAuth,
        firestore: firestore,
      ),
      aiService: aiService ?? CloudFunctionsAIService(functions: functions),
    );
  }

  void _initData() {
    final user = _authRepository.currentUser;
    if (user != null && user.uid == _defaultOwnerId) {
      _currentUserProfile = UserModel(
        id: 'usr-001',
        ownerId: 'demo-agent-001',
        fullName: 'Malaysian Agent (REN)',
        email: 'agent@propmatch.ai',
        phone: '+6012-3456789',
        agencyName: 'PropMatch Realty Malaysia',
        renNumber: 'REN 12345',
        region: 'Penang & Northern Region',
      );
      _projects = DemoDataService.getInitialProjects();
      if (_projects.isNotEmpty) {
        _selectedProject = _projects.first;
      }
      _leads = DemoDataService.getInitialLeads();
      _followups = DemoDataService.getInitialFollowups();
      _prospects = DemoDataService.getInitialDemoProspects(_defaultOwnerId);
      _prospectSources = ProspectSourceRegistry.getInitialSourcesForAgent(_defaultOwnerId);
      _incomingEnquiries = DemoDataService.getInitialDemoEnquiries(_defaultOwnerId);
      _hasGeneratedDemoProspects = true;
    }
  }

  void _onAuthStateChanged(AuthUser? user) {
    // Only react when the authentication identity genuinely transitions
    if (user?.uid == _activeAuthUid) {
      return;
    }

    _activeAuthUid = user?.uid;
    _authSessionId++;
    final currentSession = _authSessionId;

    // Purge previous user's in-memory data completely to ensure total isolation
    _currentUserProfile = null;
    _projects = [];
    _selectedProject = null;
    _buyers = [];
    _leads = [];
    _followups = [];
    _campaigns = [];
    _consentRecords = [];
    _audienceSegments = [];
    _matches = [];
    _prospects = [];
    _prospectSources = [];
    _selectedProspect = null;
    _selectedProspectConsents = [];
    _selectedProspectActivities = [];
    _isLoadingProspects = false;
    _prospectError = null;
    _hasGeneratedDemoProspects = false;
    _importJobs = [];
    _generatedMarketingContent = null;
    _geoStrategies = {};
    _segmentMarketingContent = {};
    _currentPropertyAnalysis = null;
    _cachedPropertyAnalyses.clear();
    _cachedAudienceSegments.clear();
    _audienceDiscoveryError = null;
    _lastAgentObservations = null;
    _isAnalyzingProperty = false;
    _propertyAnalysisError = null;
    _hasGeneratedDemoBuyers = false;
    _isLoadingData = false;
    _cloudSyncError = null;

    if (user == null) {
      // Unauthenticated state
      notifyListeners();
      return;
    }

    if (user.uid == _defaultOwnerId) {
      // Intended demo account
      _currentUserProfile = UserModel(
        id: 'usr-001',
        ownerId: 'demo-agent-001',
        fullName: 'Malaysian Agent (REN)',
        email: 'agent@propmatch.ai',
        phone: '+6012-3456789',
        agencyName: 'PropMatch Realty Malaysia',
        renNumber: 'REN 12345',
        region: 'Penang & Northern Region',
      );
      _projects = DemoDataService.getInitialProjects();
      if (_projects.isNotEmpty) {
        _selectedProject = _projects.first;
      }
      _leads = DemoDataService.getInitialLeads();
      _followups = DemoDataService.getInitialFollowups();
      _prospects = DemoDataService.getInitialDemoProspects(_defaultOwnerId);
      _prospectSources = ProspectSourceRegistry.getInitialSourcesForAgent(_defaultOwnerId);
      _incomingEnquiries = DemoDataService.getInitialDemoEnquiries(_defaultOwnerId);
      _hasGeneratedDemoProspects = true;
      notifyListeners();
    } else {
      _loadFromRepositories(sessionId: currentSession, ownerId: user.uid);
    }
  }

  Future<void> _loadFromRepositories({
    required int sessionId,
    required String ownerId,
  }) async {
    _isLoadingData = true;
    _cloudSyncError = null;
    notifyListeners();

    try {
      final profile = await _authRepository.getUserProfile(ownerId);
      final repoProjects = await _projectRepository.getProjects(ownerId: ownerId);
      final repoBuyers = await _buyerRepository.getBuyers(ownerId: ownerId);
      final repoLeads = await _leadRepository.getLeads(ownerId: ownerId);
      final repoFollowups = await _followupRepository.getFollowups(ownerId: ownerId);
      final repoCampaigns = await _campaignRepository.getCampaigns(ownerId: ownerId);
      final repoConsents = await _consentRepository.getConsentRecords(ownerId: ownerId);
      final repoProspects = await _prospectRepository.getProspects(ownerId: ownerId);
      final repoSources = await _prospectRepository.getDataSources(ownerId: ownerId);
      final repoJobs = await _prospectRepository.getImportJobs(ownerId: ownerId);
      final repoEnquiries = await _prospectRepository.getIncomingEnquiries(ownerId: ownerId);

      // Prevent race conditions: ignore response if session has changed
      if (sessionId != _authSessionId) {
        return;
      }

      _currentUserProfile = profile ??
          UserModel(
            id: ownerId,
            ownerId: ownerId,
            fullName: _authRepository.currentUser?.displayName.isNotEmpty == true
                ? _authRepository.currentUser!.displayName
                : 'Malaysian Agent',
            email: _authRepository.currentUser?.email ?? '',
            agencyName: 'PropMatch Agency',
            renNumber: 'REN (Pending)',
            region: 'Penang & Northern Region',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

      if (ownerId != _defaultOwnerId) {
        // Authenticated real agent: direct assignment, even if empty (no demo data leak!)
        _projects = repoProjects;
        _selectedProject = _projects.isNotEmpty ? _projects.first : null;
        _buyers = repoBuyers;
        _leads = repoLeads;
        _followups = repoFollowups;
        _campaigns = repoCampaigns;
        _consentRecords = repoConsents;
        _prospects = repoProspects;
        _prospectSources = repoSources;
        _importJobs = repoJobs;
        _incomingEnquiries = repoEnquiries;
      } else {
        // Demo account: if repository has records, synchronize; otherwise retain demo fallbacks
        if (repoProjects.isNotEmpty) {
          _projects = repoProjects;
          _selectedProject ??= _projects.first;
        }
        if (repoBuyers.isNotEmpty) {
          _buyers = repoBuyers;
        }
        if (repoLeads.isNotEmpty) {
          _leads = repoLeads;
        }
        if (repoFollowups.isNotEmpty) {
          _followups = repoFollowups;
        }
        if (repoCampaigns.isNotEmpty) {
          _campaigns = repoCampaigns;
        }
        if (repoConsents.isNotEmpty) {
          _consentRecords = repoConsents;
        }
        if (repoProspects.isNotEmpty) {
          _prospects = repoProspects;
        }
        if (repoSources.isNotEmpty) {
          _prospectSources = repoSources;
        }
        if (repoJobs.isNotEmpty) {
          _importJobs = repoJobs;
        }
        if (repoEnquiries.isNotEmpty) {
          _incomingEnquiries = repoEnquiries;
        }
      }
    } catch (e) {
      if (sessionId == _authSessionId) {
        _cloudSyncError = e.toString();
      }
    } finally {
      if (sessionId == _authSessionId) {
        _isLoadingData = false;
        notifyListeners();
      }
    }
  }

  Future<void> reloadCurrentAgentData() async {
    final uid = _activeAuthUid;
    if (uid != null) {
      await _loadFromRepositories(sessionId: _authSessionId, ownerId: uid);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // --- PROJECT ACTIONS ---
  void selectProject(ProjectModel project) {
    _selectedProject = project;
    _currentPropertyAnalysis = _cachedPropertyAnalyses[project.id];
    _propertyAnalysisError = null;
    // Restore cached audience segments or initialize empty
    _audienceSegments = _cachedAudienceSegments[project.id] ?? [];
    _audienceDiscoveryError = null;
    // Restore cached matches or initialize empty
    _matches = _cachedProjectMatches[project.id] ?? [];
    _selectedMatch = _matches.isNotEmpty ? _matches.first : null;
    _matchingError = null;
    _generatedMarketingContent = null;
    _geoStrategies = {};
    _segmentMarketingContent = {};
    notifyListeners();
  }

  Future<void> addProject(ProjectModel project) async {
    _projects.insert(0, project);
    _selectedProject = project;
    notifyListeners();
    try {
      await _projectRepository.createProject(project);
    } catch (_) {
      _projects.removeWhere((p) => p.id == project.id);
      if (_selectedProject?.id == project.id) {
        _selectedProject = _projects.isNotEmpty ? _projects.first : null;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProject(ProjectModel project) async {
    final index = _projects.indexWhere((p) => p.id == project.id);
    if (index == -1) return;
    final oldProject = _projects[index];
    _projects[index] = project;
    if (_selectedProject?.id == project.id) {
      _selectedProject = project;
    }
    if (oldProject.name != project.name) {
      _cascadeProjectNameUpdate(project.id, project.name);
    }
    notifyListeners();
    try {
      await _projectRepository.updateProject(project);
    } catch (_) {
      _projects[index] = oldProject;
      if (_selectedProject?.id == project.id) {
        _selectedProject = oldProject;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteProject(String projectId) async {
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index == -1) return;
    final oldProject = _projects[index];
    final wasSelected = _selectedProject?.id == projectId;
    _projects.removeAt(index);
    _cachedPropertyAnalyses.remove(projectId);
    _cachedAudienceSegments.remove(projectId);
    _cachedProjectMatches.remove(projectId);
    if (wasSelected) {
      _selectedProject = _projects.isNotEmpty ? _projects.first : null;
      _currentPropertyAnalysis = null;
      _audienceSegments = [];
      _matches = [];
    }
    notifyListeners();
    try {
      await _projectRepository.deleteProject(projectId);
    } catch (_) {
      _projects.insert(index, oldProject);
      if (wasSelected) {
        _selectedProject = oldProject;
      }
      notifyListeners();
      rethrow;
    }
  }

  // --- BUYER ACTIONS ---
  Future<void> generate100DemoBuyers() async {
    final demoBuyers = DemoDataService.generate100DemoBuyers();
    // Remove previous demo buyers to avoid duplicates
    _buyers.removeWhere((b) => b.isDemo);
    _buyers.addAll(demoBuyers);
    _hasGeneratedDemoBuyers = true;
    notifyListeners();
    try {
      await _buyerRepository.deleteDemoBuyers(ownerId: currentOwnerId);
      await _buyerRepository.saveBulkBuyers(demoBuyers);
    } catch (_) {
      // Retain in-memory state resilience
    }
  }

  Future<void> addBuyer(BuyerModel buyer) async {
    _buyers.insert(0, buyer);
    notifyListeners();
    try {
      await _buyerRepository.createBuyer(buyer);
    } catch (_) {
      _buyers.removeWhere((b) => b.id == buyer.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateBuyer(BuyerModel buyer) async {
    final index = _buyers.indexWhere((b) => b.id == buyer.id);
    if (index == -1) return;
    final oldBuyer = _buyers[index];
    _buyers[index] = buyer;
    if (oldBuyer.name != buyer.name) {
      _cascadeBuyerNameUpdate(buyer.id, buyer.name);
    }
    notifyListeners();
    try {
      await _buyerRepository.updateBuyer(buyer);
    } catch (_) {
      _buyers[index] = oldBuyer;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBuyer(String buyerId) async {
    final index = _buyers.indexWhere((b) => b.id == buyerId);
    if (index == -1) return;
    final oldBuyer = _buyers[index];
    _buyers.removeAt(index);
    notifyListeners();
    try {
      await _buyerRepository.deleteBuyer(buyerId);
    } catch (_) {
      _buyers.insert(index, oldBuyer);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeDemoBuyers() async {
    _buyers.removeWhere((b) => b.isDemo);
    _hasGeneratedDemoBuyers = false;
    notifyListeners();
    try {
      await _buyerRepository.deleteDemoBuyers(ownerId: currentOwnerId);
    } catch (_) {
      // Retain in-memory state resilience
    }
  }

  void setBuyerSearchQuery(String query) {
    _buyerSearchQuery = query;
    notifyListeners();
  }

  void setBuyerStatusFilter(String status) {
    _buyerStatusFilter = status;
    notifyListeners();
  }

  // --- PROSPECT INTELLIGENCE ACTIONS (PHASE 4.1) ---
  void setProspectSearchQuery(String query) {
    _prospectSearchQuery = query;
    notifyListeners();
  }

  void setProspectStatusFilter(String filter) {
    _prospectStatusFilter = filter;
    notifyListeners();
  }

  void setProspectEligibilityFilter(String filter) {
    _prospectEligibilityFilter = filter;
    notifyListeners();
  }

  void setProspectSourceFilter(String filter) {
    _prospectSourceFilter = filter;
    notifyListeners();
  }

  void setProspectVerificationFilter(String filter) {
    _prospectVerificationFilter = filter;
    notifyListeners();
  }

  Future<void> selectProspect(ProspectModel? prospect) async {
    _selectedProspect = prospect;
    _selectedProspectConsents = [];
    _selectedProspectActivities = [];
    notifyListeners();

    if (prospect != null) {
      try {
        final consents = await _prospectRepository.getConsentsForProspect(
          prospect.id,
          ownerId: currentOwnerId,
        );
        final activities = await _prospectRepository.getActivitiesForProspect(
          prospect.id,
          ownerId: currentOwnerId,
        );
        _selectedProspectConsents = consents;
        _selectedProspectActivities = activities;
      } catch (e) {
        // Fallback gracefully on fetch error
      }
      notifyListeners();
    }
  }

  Future<void> loadProspects() async {
    _isLoadingProspects = true;
    _prospectError = null;
    notifyListeners();
    try {
      _prospects = await _prospectRepository.getProspects(ownerId: currentOwnerId);
      _prospectSources = await _prospectRepository.getDataSources(ownerId: currentOwnerId);
    } catch (e) {
      _prospectError = e.toString();
    } finally {
      _isLoadingProspects = false;
      notifyListeners();
    }
  }

  Future<void> createProspect(ProspectModel prospect) async {
    _prospects.insert(0, prospect);
    notifyListeners();
    try {
      await _prospectRepository.createProspect(prospect);
      final activity = ProspectActivityModel(
        id: 'act-${DateTime.now().millisecondsSinceEpoch}',
        ownerId: prospect.ownerId,
        prospectId: prospect.id,
        activityType: 'Discovered',
        title: 'Prospect Discovered & Ingested',
        description: 'Captured via ${prospect.primarySource}.',
        actor: 'Agent User',
      );
      await _prospectRepository.recordActivity(activity);
      if (_selectedProspect?.id == prospect.id) {
        _selectedProspectActivities.insert(0, activity);
      }
      notifyListeners();
    } catch (_) {
      _prospects.removeWhere((p) => p.id == prospect.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProspect(ProspectModel prospect) async {
    final idx = _prospects.indexWhere((p) => p.id == prospect.id);
    if (idx == -1) return;
    final old = _prospects[idx];
    _prospects[idx] = prospect;
    if (_selectedProspect?.id == prospect.id) {
      _selectedProspect = prospect;
    }
    notifyListeners();
    try {
      await _prospectRepository.updateProspect(prospect);
    } catch (_) {
      _prospects[idx] = old;
      if (_selectedProspect?.id == prospect.id) {
        _selectedProspect = old;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProspectStatus(String prospectId, String newStatus) async {
    final idx = _prospects.indexWhere((p) => p.id == prospectId);
    if (idx != -1) {
      final old = _prospects[idx];
      final updated = old.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      await updateProspect(updated);

      final activity = ProspectActivityModel(
        id: 'act-${DateTime.now().millisecondsSinceEpoch}',
        ownerId: updated.ownerId,
        prospectId: updated.id,
        activityType: 'Status Change',
        title: 'Lifecycle status changed from ${old.status} to $newStatus',
        actor: 'Agent User',
      );
      await _prospectRepository.recordActivity(activity);
      if (_selectedProspect?.id == prospectId) {
        _selectedProspectActivities.insert(0, activity);
      }
      notifyListeners();
    }
  }

  Future<void> updateProspectVerification(String prospectId, String newVerification) async {
    final idx = _prospects.indexWhere((p) => p.id == prospectId);
    if (idx != -1) {
      final old = _prospects[idx];
      final updated = old.copyWith(
        verificationStatus: newVerification,
        updatedAt: DateTime.now(),
      );
      await updateProspect(updated);

      final activity = ProspectActivityModel(
        id: 'act-${DateTime.now().millisecondsSinceEpoch}',
        ownerId: updated.ownerId,
        prospectId: updated.id,
        activityType: 'Verification',
        title: 'Verification upgraded to $newVerification',
        actor: 'Agent User',
      );
      await _prospectRepository.recordActivity(activity);
      if (_selectedProspect?.id == prospectId) {
        _selectedProspectActivities.insert(0, activity);
      }
      notifyListeners();
    }
  }

  Future<void> updateContactEligibility(
    String prospectId,
    String eligibility, {
    String? reason,
  }) async {
    final idx = _prospects.indexWhere((p) => p.id == prospectId);
    if (idx != -1) {
      final old = _prospects[idx];
      final updated = old.copyWith(
        contactEligibility: eligibility,
        updatedAt: DateTime.now(),
      );
      await updateProspect(updated);

      final activity = ProspectActivityModel(
        id: 'act-${DateTime.now().millisecondsSinceEpoch}',
        ownerId: updated.ownerId,
        prospectId: updated.id,
        activityType: 'Eligibility Change',
        title: 'Contact Eligibility set to $eligibility',
        description: reason ?? 'Agent updated contact eligibility compliance status.',
        actor: 'Agent User',
      );
      await _prospectRepository.recordActivity(activity);
      if (_selectedProspect?.id == prospectId) {
        _selectedProspectActivities.insert(0, activity);
      }
      notifyListeners();
    }
  }

  Future<void> recordProspectConsent(ProspectConsentEventModel consent) async {
    await _prospectRepository.recordConsentEvent(consent);
    if (_selectedProspect?.id == consent.prospectId) {
      _selectedProspectConsents.insert(0, consent);
    }

    final idx = _prospects.indexWhere((p) => p.id == consent.prospectId);
    if (consent.status == 'Granted') {
      final isCommunicationConsent = consent.purpose == 'Direct Inquiry Response' ||
          consent.purpose == 'Property Recommendations' ||
          consent.purpose == 'Marketing & Promotion';

      if (idx != -1) {
        final existing = _prospects[idx];
        final updatedPurposes = <String>{
          ...existing.consentedPurposes,
          consent.purpose,
        }.toList();
        final updatedChannels = <String>{
          ...existing.consentedChannels,
          ...consent.communicationChannels,
        }.toList();
        await updateProspect(
          existing.copyWith(
            consentedPurposes: updatedPurposes,
            consentedChannels: updatedChannels,
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (isCommunicationConsent) {
        await updateContactEligibility(
          consent.prospectId,
          'Eligible',
          reason: 'Consent recorded: ${consent.purpose} (${consent.source})',
        );
      }
    } else if (consent.status == 'Withdrawn') {
      if (idx != -1) {
        final existing = _prospects[idx];
        final remainingPurposes = existing.consentedPurposes
            .where((p) => p != consent.purpose && p != consent.consentType)
            .toList();
        await updateProspect(
          existing.copyWith(
            consentedPurposes: remainingPurposes,
            consentedChannels: remainingPurposes.isEmpty ? const [] : existing.consentedChannels,
            updatedAt: DateTime.now(),
          ),
        );
      }
      await updateContactEligibility(
        consent.prospectId,
        'Do Not Contact',
        reason: 'Consent withdrawn: ${consent.purpose}',
      );
    }

    final activity = ProspectActivityModel(
      id: 'act-${DateTime.now().millisecondsSinceEpoch}',
      ownerId: consent.ownerId,
      prospectId: consent.prospectId,
      activityType: 'Consent Recorded',
      title: 'Consent (${consent.purpose}) status: ${consent.status}',
      description: 'Source: ${consent.source}. ${consent.evidenceText}',
      actor: 'Agent User',
    );
    await _prospectRepository.recordActivity(activity);
    if (_selectedProspect?.id == consent.prospectId) {
      _selectedProspectActivities.insert(0, activity);
    }
    notifyListeners();
  }

  Future<void> deleteProspect(String prospectId) async {
    final idx = _prospects.indexWhere((p) => p.id == prospectId);
    if (idx == -1) return;
    final old = _prospects[idx];
    _prospects.removeAt(idx);
    if (_selectedProspect?.id == prospectId) {
      _selectedProspect = null;
      _selectedProspectConsents = [];
      _selectedProspectActivities = [];
    }
    notifyListeners();
    try {
      await _prospectRepository.deleteProspect(prospectId, ownerId: currentOwnerId);
    } catch (_) {
      _prospects.insert(idx, old);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> generateDemoProspects() async {
    final demoList = DemoDataService.getInitialDemoProspects(currentOwnerId);
    final demoConsents = DemoDataService.getInitialDemoConsents(currentOwnerId);
    final demoActivities = DemoDataService.getInitialDemoActivities(currentOwnerId);

    // Filter out existing demo items in memory
    _prospects.removeWhere((p) => p.isDemo);
    _prospects.addAll(demoList);
    _hasGeneratedDemoProspects = true;
    notifyListeners();

    try {
      await _prospectRepository.deleteDemoProspects(ownerId: currentOwnerId);
      await _prospectRepository.saveBulkProspects(demoList);
      for (final c in demoConsents) {
        await _prospectRepository.recordConsentEvent(c);
      }
      for (final a in demoActivities) {
        await _prospectRepository.recordActivity(a);
      }
    } catch (_) {
      // In-memory resilience
    }
  }

  Future<void> purgeDemoProspects() async {
    _prospects.removeWhere((p) => p.isDemo);
    if (_selectedProspect?.isDemo == true) {
      _selectedProspect = null;
      _selectedProspectConsents = [];
      _selectedProspectActivities = [];
    }
    _hasGeneratedDemoProspects = false;
    notifyListeners();
    try {
      await _prospectRepository.deleteDemoProspects(ownerId: currentOwnerId);
    } catch (_) {
      // In-memory resilience
    }
  }

  Future<BuyerModel> convertProspectToBuyer(ProspectModel prospect) async {
    final buyer = BuyerModel(
      id: 'byr-${DateTime.now().millisecondsSinceEpoch}',
      ownerId: currentOwnerId,
      name: prospect.fullName,
      email: prospect.email,
      phone: prospect.phone,
      budgetMin: prospect.budgetMin,
      budgetMax: prospect.budgetMax,
      preferredLocation: prospect.preferredLocations.isNotEmpty ? prospect.preferredLocations.first : prospect.preferredState,
      preferredState: prospect.preferredState,
      propertyType: prospect.propertyTypes.isNotEmpty ? prospect.propertyTypes.first : 'Condominium',
      purchasePurpose: prospect.purchasePurpose,
      buyingTimeline: prospect.buyingTimeline,
      leadSource: prospect.primarySource,
      status: 'Contacted',
      isDemo: prospect.isDemo,
      notes: 'Converted from Prospect Database (Source: ${prospect.primarySource}). ${prospect.notes}',
      createdAt: DateTime.now(),
    );
    await addBuyer(buyer);
    await updateProspectStatus(prospect.id, 'Qualified');

    final activity = ProspectActivityModel(
      id: 'act-${DateTime.now().millisecondsSinceEpoch}',
      ownerId: prospect.ownerId,
      prospectId: prospect.id,
      activityType: 'Converted to Buyer',
      title: 'Promoted to Active Buyer CRM Database',
      description: 'Created CRM Buyer record: ${buyer.id}',
      actor: 'Agent User',
    );
    await _prospectRepository.recordActivity(activity);
    if (_selectedProspect?.id == prospect.id) {
      _selectedProspectActivities.insert(0, activity);
    }
    notifyListeners();
    return buyer;
  }

  Future<BatchImportResult> executeProspectImportJob({
    required ImportPreviewReport preview,
    required DuplicateResolutionStrategy duplicateStrategy,
    String? jobId,
    void Function(BatchImportProgress)? onProgress,
  }) async {
    final importer = CRMBatchImporter(
      repository: _prospectRepository,
      ownerId: currentOwnerId,
    );

    final result = await importer.executeImport(
      preview: preview,
      duplicateStrategy: duplicateStrategy,
      jobId: jobId,
      onProgress: onProgress,
    );

    await _prospectRepository.saveImportJob(result.job);
    _importJobs = await _prospectRepository.getImportJobs(ownerId: currentOwnerId);

    // Refresh prospects from repository
    _prospects = await _prospectRepository.getProspects(ownerId: currentOwnerId);
    notifyListeners();

    return result;
  }

  // --- INCOMING ENQUIRIES PIPELINE ACTIONS (PHASE 4.3) ---
  void setEnquiryStatusFilter(String filter) {
    _enquiryStatusFilter = filter;
    notifyListeners();
  }

  void setEnquirySourceFilter(String filter) {
    _enquirySourceFilter = filter;
    notifyListeners();
  }

  void setEnquirySearchQuery(String query) {
    _enquirySearchQuery = query;
    notifyListeners();
  }

  Future<void> loadIncomingEnquiries() async {
    _isLoadingEnquiries = true;
    _enquiryError = null;
    notifyListeners();
    try {
      _incomingEnquiries = await _prospectRepository.getIncomingEnquiries(
        ownerId: currentOwnerId,
      );
    } catch (e) {
      _enquiryError = e.toString();
    } finally {
      _isLoadingEnquiries = false;
      notifyListeners();
    }
  }

  Future<IngestionPipelineResult> ingestLeadEnquiry({
    required String sourceType,
    required Map<String, dynamic> rawPayload,
  }) async {
    final result = await LeadIngestionPipeline.processEnquiry(
      ownerId: currentOwnerId,
      sourceType: sourceType,
      rawPayload: rawPayload,
      existingProspects: _prospects,
      existingBuyers: _buyers,
      availableProjects: _projects,
    );

    // Save enquiry
    await _prospectRepository.saveIncomingEnquiry(result.enquiry);
    _incomingEnquiries.insert(0, result.enquiry);

    // If a new prospect was created, save and add to list
    if (result.createdProspect != null) {
      await _prospectRepository.createProspect(result.createdProspect!);
      _prospects.insert(0, result.createdProspect!);

      // Also record activity
      final activity = ProspectActivityModel(
        id: 'act-${DateTime.now().millisecondsSinceEpoch}',
        ownerId: currentOwnerId,
        prospectId: result.createdProspect!.id,
        activityType: 'Discovered',
        title: 'Lead Ingested from ${result.enquiry.sourceName}',
        description: 'Auto-ingested via Phase 4.3 Pipeline. Status: ${result.enquiry.processingStatus}. Match Score: ${result.matchScore?.toInt() ?? 0}%.',
        actor: 'Lead Ingestion Pipeline',
      );
      await _prospectRepository.recordActivity(activity);

      // Record consent event if eligible
      if (result.enquiry.contactEligibility == 'Eligible' && result.enquiry.consentEvidence.isNotEmpty) {
        final consent = ProspectConsentEventModel(
          id: 'consent-${DateTime.now().millisecondsSinceEpoch}',
          ownerId: currentOwnerId,
          prospectId: result.createdProspect!.id,
          consentType: 'Direct Inquiry Response',
          status: 'Granted',
          source: result.enquiry.sourceName,
          evidenceText: result.enquiry.consentEvidence,
          communicationChannels: result.createdProspect!.consentedChannels,
        );
        await _prospectRepository.recordConsentEvent(consent);
      }
    }

    notifyListeners();
    return result;
  }

  Future<void> generateDemoEnquiries() async {
    final demoEnquiries = DemoDataService.getInitialDemoEnquiries(currentOwnerId);
    _incomingEnquiries.removeWhere((e) => e.isDemo);
    _incomingEnquiries.addAll(demoEnquiries);
    notifyListeners();

    try {
      await _prospectRepository.deleteDemoEnquiries(ownerId: currentOwnerId);
      await _prospectRepository.saveBulkEnquiries(demoEnquiries);
    } catch (_) {
      // In-memory resilience
    }
  }

  Future<void> purgeDemoEnquiries() async {
    _incomingEnquiries.removeWhere((e) => e.isDemo);
    notifyListeners();
    try {
      await _prospectRepository.deleteDemoEnquiries(ownerId: currentOwnerId);
    } catch (_) {
      // In-memory resilience
    }
  }

  void setEnquiryChannelFilter(String channel) {
    _enquiryChannelFilter = channel;
    notifyListeners();
  }

  void setEnquiryCampaignFilter(String campaign) {
    _enquiryCampaignFilter = campaign;
    notifyListeners();
  }

  Future<void> updateAgentPreferences(AgentPreferencesModel prefs) async {
    _agentPreferences = prefs;
    notifyListeners();
  }

  Future<void> updateAgentRenNumber(String renNumber, {bool verified = false}) async {
    if (_currentUserProfile != null) {
      _currentUserProfile = _currentUserProfile!.copyWith(
        renNumber: renNumber,
        isRenVerified: verified,
      );
      notifyListeners();
    }
  }

  Future<void> saveIncomingEnquiry(EnquiryModel enquiry) async {
    await _prospectRepository.saveIncomingEnquiry(enquiry);
    _incomingEnquiries.removeWhere((e) => e.id == enquiry.id);
    _incomingEnquiries.insert(0, enquiry);
    notifyListeners();
  }

  Future<DistributionRoutingDecision> distributePlatformEnquiry(Map<String, dynamic> rawPayload) async {
    final decision = LeadDistributionEngine.routeEnquiry(
      rawEnquiry: rawPayload,
      candidatePreferences: [_agentPreferences],
      agentProfiles: {
        _agentPreferences.agentId: _currentUserProfile ?? UserModel(ownerId: currentOwnerId, fullName: 'Agent', email: 'agent@propmatch.ai')
      },
    );

    if (decision.isAssigned && decision.assignedAgentId != null) {
      final ingestionPayload = {
        ...rawPayload,
        'acquisitionChannel': 'Channel B: Platform-Generated',
        'assignedAgentId': decision.assignedAgentId,
        'routingStatus': 'Assigned',
        'routingReason': decision.rationale,
        'agentSuitabilityScore': decision.suitabilityScore,
        'routingTimestamp': decision.routingTimestamp.toIso8601String(),
      };
      await ingestLeadEnquiry(
        sourceType: rawPayload['sourceType']?.toString() ?? 'Property Portal',
        rawPayload: ingestionPayload,
      );
    } else {
      final unassigned = EnquiryModel(
        ownerId: 'unassigned',
        acquisitionChannel: 'Channel B: Platform-Generated',
        sourceType: rawPayload['sourceType']?.toString() ?? 'Property Portal',
        sourceName: rawPayload['sourceName']?.toString() ?? 'Platform Provider',
        fullName: rawPayload['fullName']?.toString() ?? rawPayload['name']?.toString() ?? 'Prospective Lead',
        phone: rawPayload['phone']?.toString() ?? '',
        email: rawPayload['email']?.toString() ?? '',
        preferredLocation: rawPayload['location']?.toString() ?? 'Kuala Lumpur',
        preferredState: rawPayload['state']?.toString() ?? 'Kuala Lumpur',
        propertyType: rawPayload['propertyType']?.toString() ?? 'Condominium',
        budgetMin: (rawPayload['budgetMin'] as num?)?.toDouble() ?? 400000.0,
        budgetMax: (rawPayload['budgetMax'] as num?)?.toDouble() ?? 700000.0,
        stage: 'Source Validation',
        processingStatus: 'Pending',
        statusReason: decision.rationale,
        routingStatus: 'Unassigned Queue',
        routingReason: decision.rationale,
        routingTimestamp: decision.routingTimestamp,
        isDemo: rawPayload['isDemo'] as bool? ?? false,
      );
      await saveIncomingEnquiry(unassigned);
    }

    return decision;
  }

  // --- AI AUDIENCE DISCOVERY ---
  Future<List<AudienceSegmentModel>?> runAudienceDiscovery({
    ProjectModel? project,
    PropertyAnalysisResult? existingAnalysis,
    String? agentObservations,
    bool forceRefresh = false,
  }) async {
    final targetProject = project ?? _selectedProject;
    if (targetProject == null) {
      _audienceDiscoveryError = 'No project selected for audience discovery.';
      notifyListeners();
      return null;
    }

    final validationError = validateProjectForAnalysis(targetProject);
    if (validationError != null) {
      _audienceDiscoveryError = validationError;
      notifyListeners();
      return null;
    }

    // 1. Check in-memory session cache first if not forcing refresh
    if (!forceRefresh && _cachedAudienceSegments.containsKey(targetProject.id)) {
      _audienceSegments = _cachedAudienceSegments[targetProject.id]!;
      _lastAgentObservations = agentObservations ?? _lastAgentObservations;
      _audienceDiscoveryError = null;
      if (_audienceSegments.isNotEmpty) {
        _selectedAudienceForMarketing = _audienceSegments.first;
      }
      notifyListeners();
      return _audienceSegments;
    }

    // 2. If not forcing refresh, attempt Firestore remote cache lookup
    if (!forceRefresh) {
      try {
        final cached = await _aiService.getCachedAudienceSegments(targetProject.id);
        if (cached != null && cached.isNotEmpty) {
          _audienceSegments = cached;
          _cachedAudienceSegments[targetProject.id] = cached;
          _lastAgentObservations = agentObservations ?? _lastAgentObservations;
          _audienceDiscoveryError = null;
          if (_audienceSegments.isNotEmpty) {
            _selectedAudienceForMarketing = _audienceSegments.first;
          }
          for (final seg in _audienceSegments) {
            _geoStrategies[seg.id] = AIService.generateGeographicStrategy(targetProject, seg);
          }
          notifyListeners();
          return cached;
        }
      } catch (_) {
        // Fall through to run live / rule engine
      }
    }

    _isDiscoveringAudience = true;
    _audienceDiscoveryError = null;
    _geoStrategies = {};
    _segmentMarketingContent = {};
    _lastAgentObservations = agentObservations;
    notifyListeners();

    try {
      final analysisToUse = existingAnalysis ??
          _currentPropertyAnalysis ??
          _cachedPropertyAnalyses[targetProject.id];

      final results = await _aiService.discoverAudienceSegments(
        targetProject,
        existingAnalysis: analysisToUse,
        agentObservations: agentObservations,
        forceRefresh: forceRefresh,
      );

      _audienceSegments = results;
      _cachedAudienceSegments[targetProject.id] = results;
      _audienceDiscoveryError = null;

      // Auto-generate geographic strategies for all segments
      for (final seg in _audienceSegments) {
        _geoStrategies[seg.id] = AIService.generateGeographicStrategy(targetProject, seg);
      }

      if (_audienceSegments.isNotEmpty) {
        _selectedAudienceForMarketing = _audienceSegments.first;
      }
      return results;
    } catch (e) {
      _audienceDiscoveryError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      return null;
    } finally {
      _isDiscoveringAudience = false;
      notifyListeners();
    }
  }

  /// Clears the discovered audience segments for a project or current project.
  void clearAudienceDiscovery({String? projectId}) {
    if (projectId != null) {
      _cachedAudienceSegments.remove(projectId);
      if (_selectedProject?.id == projectId) {
        _audienceSegments = [];
      }
    } else {
      _audienceSegments = [];
    }
    _audienceDiscoveryError = null;
    notifyListeners();
  }

  /// Explicitly saves the current or given audience segments to Cloud Firestore.
  Future<void> saveAudienceSegmentsToFirestore([List<AudienceSegmentModel>? segmentsToSave]) async {
    final list = segmentsToSave ?? _audienceSegments;
    if (list.isEmpty) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final collection = FirebaseFirestore.instance.collection('audience_segments');
      for (final segment in list) {
        final docRef = collection.doc(segment.id);
        batch.set(docRef, {
          ...segment.toMap(),
          'ownerId': currentOwnerId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppStateProvider] saveAudienceSegmentsToFirestore error: $e');
      }
    }
  }

  /// Validates that a project has sufficient data for high-quality AI analysis.
  String? validateProjectForAnalysis(ProjectModel project) {
    if (project.name.trim().isEmpty) {
      return 'Project name is required for AI property analysis.';
    }
    if (project.location.trim().isEmpty) {
      return 'Project location is required for AI property analysis.';
    }
    if (project.propertyType.trim().isEmpty) {
      return 'Property type is required for AI property analysis.';
    }
    if (project.startingPrice <= 0) {
      return 'A valid starting price (greater than RM 0) is required for AI property analysis.';
    }
    return null;
  }

  /// Deep Property Analysis & Intelligence (Phase 3.2)
  ///
  /// Analyzes selling points, buyer personas, competitive advantages,
  /// buyer objections, and marketing strategy. Supports deterministic caching
  /// and explicit forced regeneration.
  Future<PropertyAnalysisResult?> runPropertyAnalysis({
    ProjectModel? project,
    bool forceRefresh = false,
  }) async {
    final targetProject = project ?? _selectedProject;
    if (targetProject == null) {
      _propertyAnalysisError = 'No project selected for property analysis.';
      notifyListeners();
      return null;
    }

    final validationError = validateProjectForAnalysis(targetProject);
    if (validationError != null) {
      _propertyAnalysisError = validationError;
      notifyListeners();
      return null;
    }

    // 1. Check in-memory session cache first if not forcing refresh
    if (!forceRefresh && _cachedPropertyAnalyses.containsKey(targetProject.id)) {
      _currentPropertyAnalysis = _cachedPropertyAnalyses[targetProject.id];
      _propertyAnalysisError = null;
      notifyListeners();
      return _currentPropertyAnalysis;
    }

    // 2. If not forcing refresh, attempt Firestore remote cache lookup
    if (!forceRefresh) {
      try {
        final cached = await _aiService.getCachedPropertyAnalysis(targetProject.id);
        if (cached != null) {
          _currentPropertyAnalysis = cached;
          _cachedPropertyAnalyses[targetProject.id] = cached;
          _propertyAnalysisError = null;
          notifyListeners();
          return cached;
        }
      } catch (_) {
        // Fall through to run live/rule generation
      }
    }

    _isAnalyzingProperty = true;
    _propertyAnalysisError = null;
    notifyListeners();

    try {
      final result = await _aiService.analyzeProperty(
        targetProject,
        forceRefresh: forceRefresh,
      );
      _currentPropertyAnalysis = result;
      _cachedPropertyAnalyses[targetProject.id] = result;
      _propertyAnalysisError = null;
      return result;
    } catch (e) {
      _propertyAnalysisError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      return null;
    } finally {
      _isAnalyzingProperty = false;
      notifyListeners();
    }
  }

  /// Clears the cached property analysis for a given project or currently active project.
  void clearPropertyAnalysis({String? projectId}) {
    if (projectId != null) {
      _cachedPropertyAnalyses.remove(projectId);
      if (_selectedProject?.id == projectId) {
        _currentPropertyAnalysis = null;
      }
    } else {
      _currentPropertyAnalysis = null;
    }
    _propertyAnalysisError = null;
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
        await _aiService.generateMarketingContent(
      project: _selectedProject!,
      segment: segment,
      channel: 'Facebook Ad',
    );

    _isGeneratingSegmentContent = false;
    _generatingContentForSegmentId = null;
    notifyListeners();
  }

  // --- AI BUYER MATCHING (Phase 3.3B) ---
  void setMatchFilter(String filter) {
    _selectedMatchFilter = filter;
    notifyListeners();
  }

  void setMatchSortOrder(String sort) {
    _matchSortOrder = sort;
    notifyListeners();
  }

  Future<void> runBuyerMatching([
    ProjectModel? project,
    bool forceRefresh = false,
  ]) async {
    final targetProject = project ?? _selectedProject;
    if (targetProject == null) return;

    // If buyers list is empty, generate demo buyers automatically ONLY in demo mode
    if (_buyers.isEmpty && isDemoMode) {
      generate100DemoBuyers();
    }

    // Check memory cache first
    if (!forceRefresh && _cachedProjectMatches.containsKey(targetProject.id)) {
      _matches = _cachedProjectMatches[targetProject.id]!;
      _selectedMatch = _matches.isNotEmpty ? _matches.first : null;
      _matchingError = null;
      notifyListeners();
      return;
    }

    _isMatching = true;
    _matchingError = null;
    notifyListeners();

    try {
      // Check Firestore / backend cache if not force refreshing
      if (!forceRefresh) {
        final cached = await _aiService.getCachedMatches(targetProject.id);
        if (cached != null && cached.isNotEmpty) {
          _cachedProjectMatches[targetProject.id] = cached;
          _matches = cached;
          _selectedMatch = _matches.isNotEmpty ? _matches.first : null;
          _isMatching = false;
          notifyListeners();
          return;
        }
      }

      final results = await _aiService.matchBuyers(
        project: targetProject,
        buyers: _buyers,
        forceRefresh: forceRefresh,
      );

      _cachedProjectMatches[targetProject.id] = results;
      _matches = results;
      if (_matches.isNotEmpty) {
        _selectedMatch = _matches.first;
      }
    } catch (e) {
      _matchingError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (kDebugMode) {
        debugPrint('[AppStateProvider] runBuyerMatching error: $e');
      }
    } finally {
      _isMatching = false;
      notifyListeners();
    }
  }

  void clearMatches({String? projectId}) {
    if (projectId != null) {
      _cachedProjectMatches.remove(projectId);
      if (_selectedProject?.id == projectId) {
        _matches = [];
        _selectedMatch = null;
      }
    } else {
      _matches = [];
      _selectedMatch = null;
    }
    _matchingError = null;
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
  Future<void> addLead(LeadModel lead) async {
    _leads.insert(0, lead);
    notifyListeners();
    try {
      await _leadRepository.createLead(lead);
    } catch (_) {
      _leads.removeWhere((l) => l.id == lead.id);
      notifyListeners();
      rethrow;
    }
  }

  bool hasLeadForBuyerAndProject(String buyerId, String projectId) {
    return _leads.any((l) => l.buyerId == buyerId && l.projectId == projectId);
  }

  bool addLeadFromMatch(MatchModel match) {
    if (hasLeadForBuyerAndProject(match.buyerId, match.projectId)) {
      return false; // Prevent duplicate lead conversion
    }
    final newLead = LeadModel(
      ownerId: currentOwnerId,
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
    _leadRepository.createLead(newLead);
    return true;
  }

  Future<void> updateLeadStatus(String leadId, String newStatus) async {
    final index = _leads.indexWhere((l) => l.id == leadId);
    if (index == -1) return;
    final oldLead = _leads[index];
    _leads[index] = oldLead.copyWith(status: newStatus);
    notifyListeners();
    try {
      await _leadRepository.updateLeadStatus(leadId, newStatus);
    } catch (_) {
      _leads[index] = oldLead;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteLead(String leadId) async {
    final index = _leads.indexWhere((l) => l.id == leadId);
    if (index == -1) return;
    final oldLead = _leads[index];
    _leads.removeAt(index);
    notifyListeners();
    try {
      await _leadRepository.deleteLead(leadId);
    } catch (_) {
      _leads.insert(index, oldLead);
      notifyListeners();
      rethrow;
    }
  }

  // --- FOLLOW-UP ACTIONS ---
  Future<void> addFollowup(FollowupModel followup) async {
    _followups.insert(0, followup);
    notifyListeners();
    try {
      await _followupRepository.createFollowup(followup);
    } catch (_) {
      _followups.removeWhere((f) => f.id == followup.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateFollowup(FollowupModel followup) async {
    final index = _followups.indexWhere((f) => f.id == followup.id);
    if (index == -1) return;
    final oldFollowup = _followups[index];
    _followups[index] = followup;
    notifyListeners();
    try {
      await _followupRepository.updateFollowup(followup);
    } catch (_) {
      _followups[index] = oldFollowup;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleFollowupCompletion(String followupId) async {
    final index = _followups.indexWhere((f) => f.id == followupId);
    if (index == -1) return;
    final current = _followups[index];
    _followups[index] = current.copyWith(isCompleted: !current.isCompleted);
    notifyListeners();
    try {
      await _followupRepository.toggleCompletion(followupId);
    } catch (_) {
      _followups[index] = current;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteFollowup(String followupId) async {
    final index = _followups.indexWhere((f) => f.id == followupId);
    if (index == -1) return;
    final oldFollowup = _followups[index];
    _followups.removeAt(index);
    notifyListeners();
    try {
      await _followupRepository.deleteFollowup(followupId);
    } catch (_) {
      _followups.insert(index, oldFollowup);
      notifyListeners();
      rethrow;
    }
  }

  // --- CAMPAIGN ACTIONS ---
  Future<void> createCampaign({
    required String name,
    required String platform,
    required String headline,
    required String body,
    required String callToAction,
  }) async {
    if (_selectedProject == null) return;
    final campaign = CampaignModel(
      ownerId: currentOwnerId,
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
    try {
      await _campaignRepository.createCampaign(campaign);
    } catch (_) {
      _campaigns.removeWhere((c) => c.id == campaign.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateCampaign(CampaignModel campaign) async {
    final index = _campaigns.indexWhere((c) => c.id == campaign.id);
    if (index == -1) return;
    final oldCampaign = _campaigns[index];
    _campaigns[index] = campaign;
    notifyListeners();
    try {
      await _campaignRepository.updateCampaign(campaign);
    } catch (_) {
      _campaigns[index] = oldCampaign;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteCampaign(String campaignId) async {
    final index = _campaigns.indexWhere((c) => c.id == campaignId);
    if (index == -1) return;
    final oldCampaign = _campaigns[index];
    _campaigns.removeAt(index);
    notifyListeners();
    try {
      await _campaignRepository.deleteCampaign(campaignId);
    } catch (_) {
      _campaigns.insert(index, oldCampaign);
      notifyListeners();
      rethrow;
    }
  }

  // --- CONSENT ACTIONS (PDPA COMPLIANT & APPEND-ONLY AUDIT TRAIL) ---
  Future<void> recordConsent(ConsentRecordModel consent) async {
    _consentRecords.insert(0, consent);
    notifyListeners();
    try {
      await _consentRepository.recordConsent(consent);
    } catch (_) {
      _consentRecords.removeWhere((c) => c.id == consent.id);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> withdrawMarketingConsentForBuyer(
    String buyerId, {
    String source = 'Agent Manual Withdrawal',
  }) async {
    // Append-only audit record: record a new withdrawal event
    final withdrawalEvent = ConsentRecordModel(
      ownerId: currentOwnerId,
      buyerId: buyerId,
      consentType: 'marketing_communication',
      consentStatus: 'withdrawn',
      consentSource: source,
      consentTimestamp: DateTime.now(),
      withdrawalTimestamp: DateTime.now(),
    );
    _consentRecords.insert(0, withdrawalEvent);
    notifyListeners();
    try {
      await _consentRepository.withdrawConsent(
        buyerId: buyerId,
        consentType: 'marketing_communication',
        ownerId: currentOwnerId,
        consentSource: source,
      );
    } catch (_) {
      _consentRecords.removeWhere((c) => c.id == withdrawalEvent.id);
      notifyListeners();
      rethrow;
    }
  }

  List<ConsentRecordModel> getConsentsForBuyer(String buyerId) {
    final list = _consentRecords.where((c) => c.buyerId == buyerId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  bool hasActiveMarketingConsent(String buyerId) {
    final records = _consentRecords.where((c) =>
        c.buyerId == buyerId && c.consentType == 'marketing_communication').toList();
    if (records.isEmpty) return false;
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records.first.consentStatus == 'granted';
  }

  bool hasEnquiryConsent(String buyerId) {
    final records = _consentRecords.where((c) =>
        c.buyerId == buyerId && c.consentType == 'enquiry_response').toList();
    if (records.isEmpty) return false;
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records.first.consentStatus == 'granted';
  }

  // --- RELATIONSHIP SAFETY & INTEGRITY HELPERS ---
  bool hasActiveLeadsForProject(String projectId) {
    return _leads.any((l) => l.projectId == projectId && l.status != 'Won' && l.status != 'Lost');
  }

  bool hasFollowupsForProject(String projectId) {
    return _followups.any((f) => f.projectId == projectId && !f.isCompleted);
  }

  bool hasActiveLeadsOrFollowupsForBuyer(String buyerId) {
    final hasLead = _leads.any((l) => l.buyerId == buyerId && l.status != 'Won' && l.status != 'Lost');
    final hasFollowup = _followups.any((f) => f.buyerId == buyerId && !f.isCompleted);
    return hasLead || hasFollowup;
  }

  void _cascadeProjectNameUpdate(String projectId, String newName) {
    for (int i = 0; i < _leads.length; i++) {
      if (_leads[i].projectId == projectId) {
        final updated = _leads[i].copyWith(projectName: newName);
        _leads[i] = updated;
        _leadRepository.updateLead(updated);
      }
    }
    for (int i = 0; i < _followups.length; i++) {
      if (_followups[i].projectId == projectId) {
        final updated = _followups[i].copyWith(projectName: newName);
        _followups[i] = updated;
        _followupRepository.updateFollowup(updated);
      }
    }
  }

  void _cascadeBuyerNameUpdate(String buyerId, String newName) {
    for (int i = 0; i < _leads.length; i++) {
      if (_leads[i].buyerId == buyerId) {
        final updated = _leads[i].copyWith(buyerName: newName);
        _leads[i] = updated;
        _leadRepository.updateLead(updated);
      }
    }
    for (int i = 0; i < _followups.length; i++) {
      if (_followups[i].buyerId == buyerId) {
        final updated = _followups[i].copyWith(buyerName: newName);
        _followups[i] = updated;
        _followupRepository.updateFollowup(updated);
      }
    }
  }
}
