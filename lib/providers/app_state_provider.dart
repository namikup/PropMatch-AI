import 'dart:async';
import 'package:flutter/material.dart';
import '../models/project_model.dart';
import '../models/buyer_model.dart';
import '../models/lead_model.dart';
import '../models/followup_model.dart';
import '../models/audience_segment_model.dart';
import '../models/match_model.dart';
import '../models/campaign_model.dart';
import '../models/consent_record_model.dart';
import '../models/user_model.dart';
import '../repositories/project_repository.dart';
import '../repositories/buyer_repository.dart';
import '../repositories/lead_repository.dart';
import '../repositories/followup_repository.dart';
import '../repositories/campaign_repository.dart';
import '../repositories/consent_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/firestore_project_repository.dart';
import '../repositories/firestore_buyer_repository.dart';
import '../repositories/firestore_lead_repository.dart';
import '../repositories/firestore_followup_repository.dart';
import '../repositories/firestore_campaign_repository.dart';
import '../repositories/firestore_consent_repository.dart';
import '../repositories/firebase_auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/demo_data_service.dart';
import '../services/ai_service.dart';
import '../services/matching_service.dart';
import '../services/marketing_service.dart';

class AppStateProvider extends ChangeNotifier {
  final ProjectRepository _projectRepository;
  final BuyerRepository _buyerRepository;
  final LeadRepository _leadRepository;
  final FollowupRepository _followupRepository;
  final CampaignRepository _campaignRepository;
  final ConsentRepository _consentRepository;
  final AuthRepository _authRepository;

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
  Map<String, List<GeographicTarget>> get geoStrategies => _geoStrategies;
  Map<String, SegmentMarketingContent> get segmentMarketingContent => _segmentMarketingContent;
  bool get isGeneratingSegmentContent => _isGeneratingSegmentContent;
  String? get generatingContentForSegmentId => _generatingContentForSegmentId;

  List<MatchModel> get matches => _matches;
  bool get isMatching => _isMatching;
  MatchModel? get selectedMatch => _selectedMatch;

  List<LeadModel> get leads => List.unmodifiable(_leads);
  List<FollowupModel> get followups => List.unmodifiable(_followups);
  List<CampaignModel> get campaigns => List.unmodifiable(_campaigns);
  List<ConsentRecordModel> get consentRecords => List.unmodifiable(_consentRecords);

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
        _authRepository = authRepository ?? InMemoryAuthRepository() {
    _activeAuthUid = _authRepository.currentUser?.uid;
    _initData();
    _authSubscription = _authRepository.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Production factory configuring [AppStateProvider] with live Cloud Firestore
  /// and Firebase Authentication repositories for Flutter Web.
  factory AppStateProvider.firebase({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) {
    return AppStateProvider(
      projectRepository: FirestoreProjectRepository(firestore: firestore),
      buyerRepository: FirestoreBuyerRepository(firestore: firestore),
      leadRepository: FirestoreLeadRepository(firestore: firestore),
      followupRepository: FirestoreFollowupRepository(firestore: firestore),
      campaignRepository: FirestoreCampaignRepository(firestore: firestore),
      consentRepository: FirestoreConsentRepository(firestore: firestore),
      authRepository: FirebaseAuthRepository(
        firebaseAuth: firebaseAuth,
        firestore: firestore,
      ),
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
    _generatedMarketingContent = null;
    _geoStrategies = {};
    _segmentMarketingContent = {};
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
    // Clear project-specific AI results
    _audienceSegments = [];
    _matches = [];
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
    if (wasSelected) {
      _selectedProject = _projects.isNotEmpty ? _projects.first : null;
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

    // If buyers list is empty, generate demo buyers automatically ONLY in demo mode
    if (_buyers.isEmpty && isDemoMode) {
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
