# PropMatch AI — AI-Powered Property Lead Discovery & Buyer Matching

> **PropMatch AI** is an intelligent property lead discovery, demographic audience segmentation, and buyer-matching platform designed for Malaysian property real estate negotiators (REN) and agencies, with an initial geographical focus on the Northern Corridor (Penang & Kedah).

---

## 🌟 Key Application Modules

1. **Dashboard**: High-level overview of active development projects, registered buyers, qualified pipeline leads, and average match rate, paired with a dedicated Lead Acquisition Overview and contextual AI recommendations.
2. **Property Projects**: Full portfolio management supporting price tiers, built-up sqft, bedroom/bathroom configurations, and Northern Corridor development tracking (e.g. Batu Kawan, Bayan Lepas, Kulim Hi-Tech).
3. **AI Audience Discovery**: Flagship demographic intelligence engine generating ranked buyer personas (First-time Homebuyers, Tech Professionals, Out-of-State Investors) with compatibility rationales and marketing angles.
4. **Buyer Management**: Searchable directory of registered buyers with status tracking and integrated 100 synthetic Malaysian buyer profile generator.
5. **Lead Management**: 6-stage pipeline (`New`, `Contacted`, `Qualified`, `Negotiating`, `Won`, `Lost`) with voluntary enquiry capture.
6. **AI Buyer Matching**: 5-factor weighted matching algorithm:
   * **Budget Compatibility**: 25%
   * **Location Compatibility**: 25%
   * **Property Type**: 20%
   * **Purchase Purpose**: 15%
   * **Buying Timeline**: 15%
7. **Marketing AI Assistant**: Multi-channel marketing generator producing Facebook Ad copy, Instagram captions, TikTok 30s video scripts, WhatsApp direct outreach messages, and launch strategies.
8. **Campaigns**: Multi-platform performance tracking across Facebook, Instagram, TikTok, and WhatsApp broadcasts.
9. **Follow-ups & Viewings**: Appointment checklists for showroom viewings, layout sharing, and loan pre-screening checkpoints.
10. **Analytics**: Regional inquiry distribution, buyer budget spectrum, and simulated acquisition demand signals.
11. **Settings**: REN agent configuration, synthetic profile purge controls, and multi-tenant Firestore security rules preview.

---

## 🔒 Security & Data Integrity

* **Multi-Tenant Scoping**: All documents enforce `ownerId` access controls in `firestore.rules`.
* **Synthetic Profile Isolation**: All 100 test buyer profiles are strictly tagged with `isDemo: true` and labeled with visual `DEMO` badges to ensure synthetic records are never mixed with genuine customer enquiries.
* **Responsible AI**: Audience recommendations are clearly designated as algorithmic marketing hypotheses rather than verified census data.

---

## 🛠 Technology Stack

* **Framework**: Flutter Web (Desktop/Laptop SaaS design)
* **Language**: Dart (3.9+)
* **State Management**: Provider
* **Cloud & Hosting**: Firebase Hosting & Cloud Firestore (`firestore.rules`)
* **Typography & Design**: Google Fonts (Inter) with custom SaaS design system

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (3.35+)
* Google Chrome

### Run the Web Dashboard
```bash
# Get dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run unit and functional tests
flutter test

# Run Flutter Web in Chrome
flutter run -d chrome

# Build for Web Release
flutter build web --release
```
