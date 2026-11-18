import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:propmatch_ai/firebase_options.dart';
import 'package:propmatch_ai/providers/app_state_provider.dart';
import 'package:propmatch_ai/repositories/auth_repository.dart';
import 'package:propmatch_ai/repositories/buyer_repository.dart';
import 'package:propmatch_ai/repositories/campaign_repository.dart';
import 'package:propmatch_ai/repositories/consent_repository.dart';
import 'package:propmatch_ai/repositories/followup_repository.dart';
import 'package:propmatch_ai/repositories/lead_repository.dart';
import 'package:propmatch_ai/repositories/project_repository.dart';
import 'package:propmatch_ai/repositories/firestore_project_repository.dart';
import 'package:propmatch_ai/repositories/firestore_buyer_repository.dart';
import 'package:propmatch_ai/repositories/firestore_lead_repository.dart';
import 'package:propmatch_ai/repositories/firestore_followup_repository.dart';
import 'package:propmatch_ai/repositories/firestore_campaign_repository.dart';
import 'package:propmatch_ai/repositories/firestore_consent_repository.dart';
import 'package:propmatch_ai/repositories/firebase_auth_repository.dart';

void main() {
  group('Phase 2.0: Firebase Web Foundation Verification Suite', () {
    test('1. DefaultFirebaseOptions is configured specifically for Flutter Web and project property-71665', () {
      final webOptions = DefaultFirebaseOptions.web;

      expect(webOptions.projectId, equals('property-71665'));
      expect(webOptions.appId, equals('1:890199159513:web:1b24166e345e0e5eeb44c8'));
      expect(webOptions.authDomain, equals('property-71665.firebaseapp.com'));
      expect(webOptions.storageBucket, equals('property-71665.firebasestorage.app'));
      expect(webOptions.apiKey.isNotEmpty, isTrue);
      expect(webOptions.messagingSenderId, equals('890199159513'));
    });

    test('2. DefaultFirebaseOptions respects Web-First policy across runtimes', () {
      if (kIsWeb) {
        expect(DefaultFirebaseOptions.currentPlatform.projectId, equals('property-71665'));
      } else {
        expect(
          () => DefaultFirebaseOptions.currentPlatform,
          throwsA(isA<UnsupportedError>()),
        );
      }
    });

    test('3. Firestore Repository classes correctly satisfy all repository interfaces', () {
      expect(FirestoreProjectRepository(), isA<ProjectRepository>());
      expect(FirestoreBuyerRepository(), isA<BuyerRepository>());
      expect(FirestoreLeadRepository(), isA<LeadRepository>());
      expect(FirestoreFollowupRepository(), isA<FollowupRepository>());
      expect(FirestoreCampaignRepository(), isA<CampaignRepository>());
      expect(FirestoreConsentRepository(), isA<ConsentRepository>());
    });

    test('4. FirebaseAuthRepository implements AuthRepository with demo fallback', () async {
      final authRepo = FirebaseAuthRepository();
      expect(authRepo, isA<AuthRepository>());

      // Test Demo login separation
      final demoUser = await authRepo.signInWithEmail('agent@propmatch.ai', 'demo1234');
      expect(demoUser, isNotNull);
      expect(demoUser!.uid, equals('demo-agent-001'));
      expect(demoUser.email, equals('agent@propmatch.ai'));
      expect(demoUser.displayName, contains('Malaysian Agent'));
      expect(authRepo.currentUser?.uid, equals('demo-agent-001'));

      // Test User Profile fetch for demo account
      final profile = await authRepo.getUserProfile('demo-agent-001');
      expect(profile, isNotNull);
      expect(profile!.renNumber, equals('REN 12345'));
      expect(profile.agencyName, equals('PropMatch Realty Malaysia'));
      expect(profile.region, equals('Penang & Northern Region'));

      // Test Sign Out
      await authRepo.signOut();
      expect(authRepo.currentUser, isNull);

      authRepo.dispose();
    });

    test('5. AppStateProvider.firebase factory initializes without error and retains dependency injection', () {
      final firebaseProvider = AppStateProvider.firebase();

      expect(firebaseProvider.projectRepository, isA<FirestoreProjectRepository>());
      expect(firebaseProvider.buyerRepository, isA<FirestoreBuyerRepository>());
      expect(firebaseProvider.leadRepository, isA<FirestoreLeadRepository>());
      expect(firebaseProvider.followupRepository, isA<FirestoreFollowupRepository>());
      expect(firebaseProvider.campaignRepository, isA<FirestoreCampaignRepository>());
      expect(firebaseProvider.consentRepository, isA<FirestoreConsentRepository>());
      expect(firebaseProvider.authRepository, isA<FirebaseAuthRepository>());

      firebaseProvider.dispose();
    });
  });
}
