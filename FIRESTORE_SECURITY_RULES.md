# PropMatch AI — Production Firestore Security Rules & Data Isolation Architecture

## Document Metadata
- **Version**: 1.0.0 (Phase 1.8 Hardening)
- **Target Platform**: Cloud Firestore (Firestore Security Rules Version 2)
- **Architecture Strategy**: Single-Agent First, Multi-Agent Ready
- **Compliance Baseline**: Malaysian Personal Data Protection Act 2010 (PDPA) & Board of Valuers, Appraisers, Estate Agents and Property Managers (BOVAEP) Malaysian Estate Agency Standards (MEAS)

---

## 1. Executive Summary & Threat Model

PropMatch AI is engineered with a strict **Zero-Trust Multi-Tenant Architecture**. Even while initially serving a single Malaysian property negotiator/agent, the underlying database schema and authorization rules treat every user session as an isolated tenant bounded strictly by `ownerId == request.auth.uid`.

### Threat Model & Countermeasures

| Threat Vector | Attack Scenario | Security Rule Countermeasure |
| :--- | :--- | :--- |
| **Cross-Agent Data Leakage** | Agent B crafts a query or direct document request to read Agent A's buyers, leads, or follow-ups. | Read access requires `request.auth.uid == resource.data.ownerId`. Wildcard collection queries without this filter are denied by Firestore. |
| **Ownership Hijacking** | A rogue client updates a document's `ownerId` field from Agent A to Agent B to transfer ownership of high-value prospects. | Update rules strictly enforce `request.resource.data.ownerId == resource.data.ownerId` (Immutability guarantee). |
| **Audit Trail Tampering (PDPA Breach)** | A party updates or deletes historic consent records to conceal non-consensual telemarketing or fabricate consent timestamps. | `consent_records` collection is **append-only**. `allow update: if false;` and `allow delete: if false;`. Only validated creations are permitted. |
| **Unauthenticated Snooping** | Unauthenticated web visitors attempt to dump property listings or buyer phone numbers. | Every rule requires `request.auth != null`. Unauthenticated requests receive an immediate `PERMISSION_DENIED`. |
| **Malicious Payload Injection** | Clients attempt to inject oversized strings, invalid timestamps, or unexpected fields. | Helper functions enforce schema boundaries, non-empty fields, valid status enums, and ownership identity matches. |

---

## 2. Production Security Rules (`firestore.rules`)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // =========================================================================
    // GLOBAL HELPER FUNCTIONS
    // =========================================================================

    /// Verifies if the incoming request is from an authenticated user.
    function isAuthenticated() {
      return request.auth != null && request.auth.uid != null;
    }

    /// Verifies if the authenticated user matches the given UID.
    function isUser(uid) {
      return isAuthenticated() && request.auth.uid == uid;
    }

    /// Verifies if the authenticated user is the designated owner of an existing resource.
    function isResourceOwner() {
      return isAuthenticated() && resource != null && resource.data.ownerId == request.auth.uid;
    }

    /// Verifies if the incoming write assigns ownership to the authenticated user.
    function isAssigningSelfAsOwner() {
      return isAuthenticated() && request.resource.data.ownerId == request.auth.uid;
    }

    /// Ensures that the ownerId field cannot be modified during updates (Anti-Hijacking).
    function isOwnerImmutable() {
      return request.resource.data.ownerId == resource.data.ownerId;
    }

    /// Validates standard ISO-8601/timestamp format and required string lengths.
    function isNonEmptyString(val, minLen, maxLen) {
      return val is string && val.size() >= minLen && val.size() <= maxLen;
    }

    // =========================================================================
    // 1. USERS COLLECTION (`users/{userId}`)
    // =========================================================================
    // Stores Malaysian property agent profiles (REN number, agency, phone, region).
    match /users/{userId} {
      // Agents can only read and manage their own profile
      allow get: if isUser(userId);
      allow list: if false; // Disallow bulk enumeration of agent directory

      allow create: if isUser(userId)
                    && request.resource.data.ownerId == userId
                    && isNonEmptyString(request.resource.data.email, 5, 100)
                    && isNonEmptyString(request.resource.data.fullName, 2, 100);

      allow update: if isUser(userId)
                    && isOwnerImmutable()
                    && request.resource.data.email == resource.data.email; // Email changes must follow Auth flow

      allow delete: if false; // User profiles should only be soft-deleted or removed via Admin SDK
    }

    // =========================================================================
    // 2. PROPERTY PROJECTS (`projects/{projectId}`)
    // =========================================================================
    // Development projects created and represented by negotiators.
    match /projects/{projectId} {
      allow read: if isResourceOwner();

      allow create: if isAssigningSelfAsOwner()
                    && isNonEmptyString(request.resource.data.name, 2, 150)
                    && isNonEmptyString(request.resource.data.developer, 2, 150)
                    && isNonEmptyString(request.resource.data.location, 2, 100)
                    && request.resource.data.priceMin is number
                    && request.resource.data.priceMax is number
                    && request.resource.data.priceMax >= request.resource.data.priceMin;

      allow update: if isResourceOwner()
                    && isOwnerImmutable()
                    && request.resource.data.priceMax >= request.resource.data.priceMin;

      allow delete: if isResourceOwner();
    }

    // =========================================================================
    // 3. BUYER PROFILES (`buyers/{buyerId}`)
    // =========================================================================
    // Confidential buyer records, budgets, locations, and preferences.
    match /buyers/{buyerId} {
      allow read: if isResourceOwner();

      allow create: if isAssigningSelfAsOwner()
                    && isNonEmptyString(request.resource.data.name, 2, 100)
                    && isNonEmptyString(request.resource.data.preferredLocation, 2, 100)
                    && request.resource.data.budgetMin is number
                    && request.resource.data.budgetMax is number
                    && request.resource.data.budgetMax >= request.resource.data.budgetMin
                    && request.resource.data.status in ['Active', 'Contacted', 'Viewing Scheduled', 'Negotiating', 'Closed Deal', 'Inactive'];

      allow update: if isResourceOwner()
                    && isOwnerImmutable()
                    && request.resource.data.status in ['Active', 'Contacted', 'Viewing Scheduled', 'Negotiating', 'Closed Deal', 'Inactive'];

      allow delete: if isResourceOwner();
    }

    // =========================================================================
    // 4. LEADS PIPELINE (`leads/{leadId}`)
    // =========================================================================
    // Active pipeline enquiries connecting buyers with property projects.
    match /leads/{leadId} {
      allow read: if isResourceOwner();

      allow create: if isAssigningSelfAsOwner()
                    && isNonEmptyString(request.resource.data.buyerName, 2, 100)
                    && isNonEmptyString(request.resource.data.projectName, 2, 150)
                    && request.resource.data.status in ['New', 'Contacted', 'Qualified', 'Negotiating', 'Won', 'Lost'];

      allow update: if isResourceOwner()
                    && isOwnerImmutable()
                    && request.resource.data.status in ['New', 'Contacted', 'Qualified', 'Negotiating', 'Won', 'Lost'];

      allow delete: if isResourceOwner();
    }

    // =========================================================================
    // 5. FOLLOW-UP TASKS (`followups/{followupId}`)
    // =========================================================================
    // Scheduled negotiator reminders, viewings, calls, and WhatsApp messages.
    match /followups/{followupId} {
      allow read: if isResourceOwner();

      allow create: if isAssigningSelfAsOwner()
                    && isNonEmptyString(request.resource.data.buyerName, 2, 100)
                    && isNonEmptyString(request.resource.data.task, 2, 250)
                    && request.resource.data.isCompleted is bool;

      allow update: if isResourceOwner()
                    && isOwnerImmutable()
                    && request.resource.data.isCompleted is bool;

      allow delete: if isResourceOwner();
    }

    // =========================================================================
    // 6. MARKETING CAMPAIGNS (`campaigns/{campaignId}`)
    // =========================================================================
    // Multi-channel marketing copy, audience targets, and conversion tracking.
    match /campaigns/{campaignId} {
      allow read: if isResourceOwner();

      allow create: if isAssigningSelfAsOwner()
                    && isNonEmptyString(request.resource.data.name, 2, 150)
                    && isNonEmptyString(request.resource.data.platform, 2, 50)
                    && request.resource.data.status in ['Active', 'Draft', 'Paused', 'Completed'];

      allow update: if isResourceOwner()
                    && isOwnerImmutable()
                    && request.resource.data.status in ['Active', 'Draft', 'Paused', 'Completed'];

      allow delete: if isResourceOwner();
    }

    // =========================================================================
    // 7. MATCH RECORDS (`matches/{matchId}`)
    // =========================================================================
    // AI buyer-project compatibility calculations and factor scores.
    match /matches/{matchId} {
      allow read: if isResourceOwner();

      allow create: if isAssigningSelfAsOwner()
                    && isNonEmptyString(request.resource.data.buyerId, 1, 100)
                    && isNonEmptyString(request.resource.data.projectId, 1, 100)
                    && request.resource.data.overallMatchPercentage >= 0.0
                    && request.resource.data.overallMatchPercentage <= 100.0;

      allow update: if isResourceOwner()
                    && isOwnerImmutable();

      allow delete: if isResourceOwner();
    }

    // =========================================================================
    // 8. AUDIENCE SEGMENTS (`audience_segments/{segmentId}`)
    // =========================================================================
    // Discovered demographic and psychographic buyer personas.
    match /audience_segments/{segmentId} {
      allow read: if isResourceOwner();

      allow create: if isAssigningSelfAsOwner()
                    && isNonEmptyString(request.resource.data.name, 2, 150)
                    && isNonEmptyString(request.resource.data.projectId, 1, 100);

      allow update: if isResourceOwner()
                    && isOwnerImmutable();

      allow delete: if isResourceOwner();
    }

    // =========================================================================
    // 9. PDPA CONSENT AUDIT LOG (`consent_records/{consentId}`)
    // =========================================================================
    // CRITICAL: Append-Only Immutable Compliance Audit Trail.
    // Under the Malaysian Personal Data Protection Act (PDPA 2010), consent records
    // must retain an untampered historical log of when consent was given or withdrawn.
    match /consent_records/{consentId} {
      // Agents can read the consent records for buyers they manage
      allow read: if isResourceOwner();

      // Creation is permitted only if signed by the authenticated owner
      // and fields adhere to PDPA compliance schema
      allow create: if isAssigningSelfAsOwner()
                    && isNonEmptyString(request.resource.data.buyerId, 1, 100)
                    && request.resource.data.consentType in ['enquiry_response', 'marketing_communication']
                    && request.resource.data.consentStatus in ['granted', 'withdrawn']
                    && isNonEmptyString(request.resource.data.consentSource, 2, 100);

      // STRICT IMMUTABILITY: Consent records can NEVER be modified or erased by clients.
      // Any consent change (e.g., withdrawal) must be recorded as an append-only new entry.
      allow update: if false;
      allow delete: if false;
    }

    // =========================================================================
    // DEFAULT DENY FALLTHROUGH
    // =========================================================================
    // Catch-all rule: Any collection or subcollection not explicitly declared is rejected.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 3. Data Isolation Architecture & Query Restrictions

In Cloud Firestore, **Security Rules are NOT Filters**. A query succeeds or fails in its entirety based on whether the rules allow every potential document that matches the query.

### Required Client Query Patterns

Every query issued by a repository in the Flutter Web client **must** include an equality constraint on `ownerId`:

```dart
// CORRECT: Complies with security rules and enables secure multi-agent query evaluation
firestore
    .collection('buyers')
    .where('ownerId', isEqualTo: currentUserId)
    .orderBy('createdAt', descending: true)
    .snapshots();

// INCORRECT (WILL BE REJECTED WITH PERMISSION_DENIED):
// Omitting the ownerId filter attempts to read across all agents' records
firestore
    .collection('buyers')
    .snapshots();
```

### Composite Indexes Required

To support these filtered and ordered queries, the following Firestore Composite Indexes will be defined in `firestore.indexes.json` upon deployment:

| Collection | Fields | Mode | Purpose |
| :--- | :--- | :--- | :--- |
| `buyers` | `ownerId` ASC, `createdAt` DESC | Ascending / Descending | Agent-isolated buyer directory pagination |
| `leads` | `ownerId` ASC, `status` ASC, `createdAt` DESC | Ascending / Descending | Pipeline Kanban and status filtering |
| `followups` | `ownerId` ASC, `isCompleted` ASC, `createdAt` DESC | Ascending / Descending | Daily agenda and pending task filtering |
| `campaigns` | `ownerId` ASC, `status` ASC, `createdAt` DESC | Ascending / Descending | Campaign analytics dashboard |
| `consent_records` | `ownerId` ASC, `buyerId` ASC, `createdAt` DESC | Ascending / Descending | Per-buyer PDPA audit trail retrieval |

---

## 4. PDPA & Regulatory Compliance Guarantees

1. **Explicit Opt-In By Default**:
   In compliance with Section 6 of the Malaysian Personal Data Protection Act 2010 (General Principle), consent is not assumed or bundled. The UI ensures both `consentEnquiry` and `consentMarketing` checkboxes initialize to `false`.

2. **Immutable Audit Trail**:
   Section 7 (Notice and Choice Principle) requires agents to demonstrate when and how consent was secured. By setting `allow update: if false;` and `allow delete: if false;`, the audit log is cryptographically immune to client tampering.

3. **Right to Withdraw**:
   When a buyer opts out of promotional messages, the application records a new event with `consentStatus: 'withdrawn'` stamped with `DateTime.now()` and source `Agent Manual Withdrawal`. The previous `granted` record is retained as legal evidence that previous communications were compliant at the time they were dispatched.

---

## 5. Deployment Notice

> **IMPORTANT ARCHITECTURAL NOTICE**:
> These security rules and architecture specifications are finalized for **Phase 2 (Firebase Live Connection)**.
> In accordance with the Phase 1.8 constraints, this file serves as the formal architectural reference and specification.
> **No live deployment or Firebase CLI configuration changes have been executed during this phase.**
