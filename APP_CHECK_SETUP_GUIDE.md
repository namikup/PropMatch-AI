# PropMatch AI — Firebase App Check Implementation Guide

## Document Overview
- **Project**: PropMatch AI (Flutter Web)
- **Target Firebase Project**: `property-71665` (Project Number: `890199159513`)
- **Web App ID**: `1:890199159513:web:1b24166e345e0e5eeb44c8`
- **Scope**: Protection of Cloud Firestore and Firebase Authentication against unauthorized clients, API abuse, scraping, and automated bot traffic.

---

## 1. What is Firebase App Check?

Firebase App Check helps protect your backend resources (such as Cloud Firestore and Firebase Storage) by attesting that incoming traffic originates from your genuine web application rather than automated scripts, scrapers, or unauthorized third-party clients.

For Flutter Web, App Check operates using **reCAPTCHA Enterprise** (or **reCAPTCHA v3**) to evaluate user interactions and issue an attestation token that is automatically attached to every Firestore request.

---

## 2. Architecture & Provider Selection

| Provider | Recommended For | Cost / Quota | Setup Complexity |
| :--- | :--- | :--- | :--- |
| **reCAPTCHA Enterprise** *(Recommended)* | Production SaaS | First 1,000,000 calls/month free | Moderate (GCP Console) |
| **reCAPTCHA v3** | Simple / Prototype | First 1,000,000 calls/month free | Simple |
| **Custom / Debug Provider** | Local Development & CI | Free (Internal) | Simple |

---

## 3. Step-by-Step Setup Guide

### Step 3.1: Create reCAPTCHA Enterprise Key
1. Go to the [Google Cloud Console reCAPTCHA Enterprise](https://console.cloud.google.com/security/recaptcha?project=property-71665).
2. Click **Create Key**.
3. Configure:
   - **Display name**: `PropMatch AI Web Client`
   - **Platform type**: `Web site`
   - **Domain List**:
     - `property-71665.web.app`
     - `property-71665.firebaseapp.com`
     - `propmatch.ai` *(custom domain when configured)*
     - `localhost` *(for local testing)*
   - **Integration type**: `Score-based (v3 equivalent)`
4. Click **Create Key** and copy the generated **Site Key** (`6L...`).

### Step 3.2: Register Web App in Firebase Console
1. Navigate to [Firebase Console > App Check](https://console.firebase.google.com/project/property-71665/appcheck).
2. Select the **Apps** tab.
3. Locate **PropMatch AI Web** (`1:890199159513:web:1b24166e345e0e5eeb44c8`).
4. Click **Register** or **Configure**.
5. Select **reCAPTCHA Enterprise** (or reCAPTCHA v3).
6. Paste the **Site Key** from Step 3.1.
7. Set Token TTL to `1 hour` (recommended default).
8. Click **Save**.

> [!IMPORTANT]
> **DO NOT CLICK ENFORCE YET.** Leave enforcement disabled initially. Monitor the verified vs unverified traffic metrics for at least 7 days before enforcing.

---

## 4. Flutter Web Code Integration

### Step 4.1: Add Dependency
When ready to integrate, add `firebase_app_check` to `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^5.1.0
  firebase_auth: ^7.0.1
  cloud_firestore: ^7.1.0
  firebase_app_check: ^0.4.1
```

### Step 4.2: Initialization in `main.dart`
Update `lib/main.dart` to initialize App Check conditionally for Flutter Web:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool isFirebaseConnected = false;

  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Initialize Firebase App Check for Web
      if (kReleaseMode) {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaEnterpriseProvider('YOUR_RECAPTCHA_SITE_KEY'),
        );
      } else {
        // Local development: use debug provider to avoid burning reCAPTCHA quota
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider('YOUR_DEBUG_OR_TEST_SITE_KEY'),
        );
      }
      
      isFirebaseConnected = true;
    }
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
    isFirebaseConnected = false;
  }

  runApp(PropMatchApp(isFirebaseConnected: isFirebaseConnected));
}
```

---

## 5. Local Development with Debug Tokens

When developing locally (`localhost`), reCAPTCHA scoring can produce false positives. Use debug tokens to bypass reCAPTCHA checks during development:

1. When running in debug mode with App Check activated, open Chrome DevTools Console (`F12`).
2. App Check will print a debug token to the console:
   ```text
   Firebase App Check debug token: 12345678-ABCD-EF01-2345-6789ABCDEF01
   ```
3. Copy this token.
4. Go to **Firebase Console > App Check > Apps > Manage debug tokens**.
5. Click **Add debug token**, name it `Local Developer Machine`, and paste the token.
6. The local browser instance will now be recognized as a valid attester without triggering CAPTCHA challenges.

---

## 6. Phased Rollout & Enforcement Schedule

```
Phase 1: Registration & Metrics Collection (Weeks 1 - 2)
├── Register Web App with reCAPTCHA Enterprise
├── Deploy code with App Check activated
└── Enforcement: OFF (Monitor verified vs unverified request ratios)

Phase 2: Metric Verification & Triage (Week 3)
├── Verify legitimate agent requests show >99% verified status
└── Verify debug tokens function for development environments

Phase 3: Production Enforcement (Week 4+)
├── Go to Firebase Console > App Check > Cloud Firestore
├── Click "Enforce"
└── Any request without a valid App Check token is permanently rejected at the edge
```

---

## 7. Operational Safeguards

- **Monitoring Quotas**: reCAPTCHA Enterprise includes 1,000,000 assessments per month for free across all accounts in a Google Cloud project. An early-stage SaaS with 50 agents will typically consume under 30,000 assessments/month.
- **Failover Behavior**: If reCAPTCHA fails to load (e.g., aggressive client ad-blocker), un-enforced mode allows requests through while logging the incident. Enforced mode will block requests until reCAPTCHA succeeds.
