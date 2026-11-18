# PropMatch AI — Firebase Architecture & Production Integration Blueprint

**Version:** 1.0.0 (Phase 1 Preparation)  
**Status:** Architectural Blueprint (No Live Firebase Connection in Phase 1)  
**Target Environment:** Flutter Web (Google Chrome / Desktop & Laptop SaaS)  
**Author:** PropMatch AI Engineering  

---

## 1. Overview & Architectural Philosophy

PropMatch AI is designed as a secure, multi-tenant SaaS application empowering Malaysian property agents and negotiators (REN). To graduate from the current in-memory client-side prototype to a commercial cloud product, the system will integrate Google Cloud & Firebase backend infrastructure.

The core design principle is **Strict Multi-Tenant Isolation**:
- Every primary business entity (`projects`, `buyers`, `leads`, `followups`, `campaigns`) must contain a mandatory `ownerId` string field corresponding to the authenticated Firebase Auth User UID (`request.auth.uid`).
- Data access is governed declaratively via Firestore Security Rules; no cross-agent visibility or data leakage is permitted.
- Clean repository boundaries decouple the Flutter UI layer from database-specific SDK implementations.

---

## 2. Proposed Firestore Collections & Schema Specifications

```
firestore/
├── users/
│   └── {userId}                        # Agent profile, agency, REN licence, region
├── projects/
│   └── {projectId}                    # Property development specifications & brochures
├── buyers/
│   └── {buyerId}                      # Registered buyer profiles, budgets, preferred areas
├── leads/
│   └── {leadId}                       # Voluntary enquiry pipeline stages and deal values
├── followups/
│   └── {followupId}                  # Scheduled viewings, calls, and agent checkpoints
├── audienceSegments/
│   └── {segmentId}                   # Persisted AI marketing archetypes per project
├── matches/
│   └── {matchId}                      # Buyer-to-project compatibility evaluations
├── campaigns/
│   └── {campaignId}                  # Multi-channel marketing copy & performance metrics
├── activities/
│   └── {activityId}                  # Audit log of stage updates and buyer interactions
└── consentRecords/
    └── {consentId}                   # Malaysian PDPA compliance records & opt-ins
```

### Detailed Document Schemas

#### 1. `users` (Agent Profiles)
```json
{
  "uid": "usr_948194819",
  "email": "agent@propmatch.ai",
  "displayName": "Tan Zhi Wei",
  "renNumber": "REN 38291",
  "agency": "PropNex Malaysia (Penang)",
  "phoneNumber": "+6012-4567890",
  "primaryRegions": ["Penang", "Kedah"],
  "subscriptionTier": "pro",
  "createdAt": "2026-11-18T10:00:00Z",
  "updatedAt": "2026-11-18T10:00:00Z"
}
```

#### 2. `projects` (Property Developments)
```json
{
  "id": "proj_batu_kawan_001",
  "ownerId": "usr_948194819",
  "name": "Vertu Residences",
  "developer": "Aspen Group",
  "location": "Batu Kawan",
  "state": "Penang",
  "propertyType": "Condominium",
  "startingPrice": 450000.0,
  "maximumPrice": 620000.0,
  "bedrooms": 3,
  "bathrooms": 2,
  "builtUpArea": 950.0,
  "purpose": "Own Stay & Investment",
  "status": "New Launch",
  "description": "Transit-oriented development near BKIP and IKEA Batu Kawan.",
  "facilities": ["Infinity Pool", "Sky Gym", "EV Charging", "Co-working Hub"],
  "nearbyAmenities": ["IKEA Batu Kawan (800m)", "Design Village (500m)"],
  "imageUrls": ["https://storage.googleapis.com/.../hero.jpg"],
  "brochures": ["https://storage.googleapis.com/.../floorplan.pdf"],
  "createdAt": "2026-11-18T10:00:00Z",
  "updatedAt": "2026-11-18T10:00:00Z"
}
```

#### 3. `buyers` (Buyer Directory)
```json
{
  "id": "buyer_9281928",
  "ownerId": "usr_948194819",
  "name": "Kavitha Ramasamy",
  "email": "kavitha.r@gmail.com",
  "phone": "+6016-7890123",
  "budgetMin": 450000.0,
  "budgetMax": 650000.0,
  "preferredLocation": "Batu Kawan",
  "preferredState": "Penang",
  "propertyType": "Condominium",
  "purchasePurpose": "Own Stay",
  "buyingTimeline": "Within 3 months",
  "leadSource": "WhatsApp Enquiry",
  "status": "Interested",
  "isDemo": false,
  "notes": "Looking for 3-bedroom unit near industrial park for daily commute.",
  "createdAt": "2026-11-18T10:00:00Z"
}
```

#### 4. `leads` (Enquiry & Deal Pipeline)
```json
{
  "id": "lead_3819281",
  "ownerId": "usr_948194819",
  "buyerId": "buyer_9281928",
  "projectId": "proj_batu_kawan_001",
  "buyerName": "Kavitha Ramasamy",
  "projectName": "Vertu Residences",
  "status": "Qualified",
  "source": "WhatsApp Enquiry",
  "dealValue": 520000.0,
  "notes": "Loan pre-screened with Maybank. Scheduled viewing this Saturday.",
  "isDemo": false,
  "createdAt": "2026-11-18T10:00:00Z",
  "updatedAt": "2026-11-18T10:00:00Z"
}
```

#### 5. `followups` (Schedules & Viewings)
```json
{
  "id": "f_18291829",
  "ownerId": "usr_948194819",
  "buyerName": "Kavitha Ramasamy",
  "buyerId": "buyer_9281928",
  "projectName": "Vertu Residences",
  "projectId": "proj_batu_kawan_001",
  "task": "Confirm Saturday 2:00 PM showroom viewing with sales gallery",
  "dueDate": "Saturday, 2:00 PM",
  "type": "Showroom Viewing",
  "isCompleted": false,
  "createdAt": "2026-11-18T10:00:00Z",
  "updatedAt": "2026-11-18T10:00:00Z"
}
```

#### 6. `audienceSegments` (Generated AI Personas)
```json
{
  "id": "aud_first_timer_batu_kawan",
  "ownerId": "usr_948194819",
  "projectId": "proj_batu_kawan_001",
  "name": "First-Time Homebuyers (Young Professionals)",
  "suitabilityScore": 88.5,
  "description": "Tech & semiconductor engineers working in BKIP looking to exit rental market.",
  "positiveFactors": ["Starting price RM450k fits median household income", "Low downpayment packages"],
  "objections": ["Worried about early project completion timing"],
  "missingInformation": ["Exact maintenance fee per sqft"],
  "recommendedChannels": ["Facebook Ads", "Instagram Carousel", "TikTok Video Hooks"],
  "createdAt": "2026-11-18T10:00:00Z"
}
```

#### 7. `matches` (Buyer-Project Match Records)
```json
{
  "id": "match_918291",
  "ownerId": "usr_948194819",
  "buyerId": "buyer_9281928",
  "projectId": "proj_batu_kawan_001",
  "buyerName": "Kavitha Ramasamy",
  "projectName": "Vertu Residences",
  "overallMatchPercentage": 89.2,
  "budgetScore": 23.5,
  "locationScore": 25.0,
  "propertyTypeScore": 20.0,
  "purposeScore": 15.0,
  "timelineScore": 10.7,
  "isDemoBuyer": false,
  "createdAt": "2026-11-18T10:00:00Z"
}
```

#### 8. `campaigns` (Multi-Channel Copy & Ad Tracking)
```json
{
  "id": "camp_819281",
  "ownerId": "usr_948194819",
  "projectId": "proj_batu_kawan_001",
  "projectName": "Vertu Residences",
  "platform": "Facebook",
  "name": "Vertu Residences - BKIP Engineer Blast",
  "contentHeadline": "Stop Renting in Batu Kawan: 3BR Modern Condo from RM450k",
  "contentBody": "Introducing Vertu Residences by Aspen Group...",
  "status": "Active",
  "reach": 1240,
  "clicks": 86,
  "enquiries": 14,
  "createdAt": "2026-11-18T10:00:00Z"
}
```

#### 9. `activities` (Audit & Timeline Logs)
```json
{
  "id": "act_8192819",
  "ownerId": "usr_948194819",
  "leadId": "lead_3819281",
  "action": "STAGE_UPDATED",
  "previousValue": "Contacted",
  "newValue": "Qualified",
  "remarks": "Buyer submitted 3 months payslips & CCRIS report.",
  "timestamp": "2026-11-18T10:00:00Z"
}
```

#### 10. `consentRecords` (Malaysian PDPA Compliance)
```json
{
  "id": "consent_182918",
  "ownerId": "usr_948194819",
  "buyerId": "buyer_9281928",
  "consentChannel": "WhatsApp Double Opt-in",
  "noticeVersion": "PDPA-MY-2026-V1",
  "acceptedMarketing": true,
  "timestamp": "2026-11-18T10:00:00Z",
  "ipAddress": "175.143.28.10"
}
```

---

## 3. Ownership & Access-Control Strategy

1. **Owner Attribution**:
   Every document created by an agent automatically stamps `ownerId = request.auth.uid`.
2. **Immutable Ownership**:
   Rules prevent agents from updating or transferring the `ownerId` of an existing document.
3. **Demo Data Flag**:
   Synthetic demo profiles are flagged with `isDemo: true` and filtered out of commercial exports or real client compliance audits.
4. **Agent Self-Isolation**:
   Querying `/buyers` or `/leads` returns exclusively documents where `ownerId == auth.uid`.

---

## 4. Authentication Flow

```
[Agent Web Browser]
       │
       ▼
1. Login Screen (Email/Password or Google Sign-In)
       │
       ▼
2. FirebaseAuth.instance.signInWithEmailAndPassword(...)
       │
       ▼
3. Firebase Auth returns UserCredential + ID Token (JWT)
       │
       ▼
4. AuthRepository emits AuthUser stream event
       │
       ▼
5. AppStateProvider receives user, sets _currentOwnerId = user.uid
       │
       ▼
6. Firestore query streams bind: 
   projectsRef.where('ownerId', isEqualTo: user.uid).snapshots()
```

---

## 5. Repository Architecture

To maintain decoupling, the Flutter UI and `AppStateProvider` interact with domain interfaces rather than raw Firestore queries:

```
[UI Widgets] (ProjectsScreen, BuyersScreen, LeadsScreen)
       │
       ▼
[AppStateProvider] (State Management & Business Rules)
       │
       ▼
[Repository Interfaces] (lib/repositories/)
├── ProjectRepository
├── BuyerRepository
├── LeadRepository
├── FollowupRepository
└── AuthRepository
       │
       ├──► [InMemoryRepository] (Current Phase 1 Stabilisation)
       └──► [FirestoreRepository] (Future Phase 2 Firebase Connection)
```

---

## 6. Firebase Security Rules (`firestore.rules`)

The existing root `firestore.rules` will be updated to enforce multi-tenant document isolation across all proposed collections:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isOwner(resourceOwnerId) {
      return isAuthenticated() && resourceOwnerId == request.auth.uid;
    }
    
    function createsOwnedDoc() {
      return isAuthenticated() && request.resource.data.ownerId == request.auth.uid;
    }

    // User profile
    match /users/{userId} {
      allow read, write: if isAuthenticated() && request.auth.uid == userId;
    }

    // Agent owned collections
    match /{collectionName}/{docId} {
      allow read, update, delete: if isOwner(resource.data.ownerId);
      allow create: if createsOwnedDoc();
    }
  }
}
```

---

## 7. Data Migration Strategy from Demo Models

When transitioning from the Phase 1 in-memory prototype to Phase 2 Firestore:
1. **Model Serialization**:
   All models already implement `toMap()` and `fromMap()` with ISO 8601 timestamps and UUID keys.
2. **First-Run Seed Tool**:
   On new agent registration, an optional button ("Seed Starter Demo Portfolio") will write the 2 Penang developments and 4 sample leads into Firestore under the agent's new `uid`.
3. **Demo Purge**:
   A single batch delete query `where('ownerId', '==', uid).where('isDemo', '==', true)` permanently purges fictional demo records without touching genuine leads.

---

## 8. Required Flutter Dependencies (For Phase 2)

```yaml
dependencies:
  # Firebase Core & Platform
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  firebase_storage: ^12.3.2

  # Future Ad & Analytics Webhooks
  http: ^1.2.2
```

*(Note: These packages are NOT installed in Phase 1, complying with strict non-connection constraints).*

---

## 9. Firebase Project Configuration Steps (For Phase 2)

1. **Firebase Console Setup**:
   - Project: `property-71665` (configured in `.firebaserc`).
   - Enable Authentication -> Email/Password & Google Sign-In.
   - Enable Cloud Firestore in Asia-Southeast1 (Singapore) region.
   - Enable Firebase Storage with default buckets.
2. **Flutter Web Registration**:
   - Run `flutterfire configure --project=property-71665`.
   - Generates `lib/firebase_options.dart`.
3. **Deploy Security Rules**:
   - Run `firebase deploy --only firestore:rules`.
4. **App Initialization**:
   - Call `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);` in `lib/main.dart`.
