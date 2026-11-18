# PropMatch AI — Comprehensive System Audit & Technical Readiness Report

**Date of Audit:** November 18, 2026  
**Audited Target:** PropMatch AI Flutter Web Application  
**Target Environment:** Flutter Web (Google Chrome / Desktop & Laptop SaaS)  
**Project Path:** `/Users/jiaxianlim/Downloads/PropMatch AI`  
**Git Revision:** `7d5284a` (Up-to-date with `origin/main`)  
**Audit Scope:** Codebase Inspection across Architecture, State Management, UI Layer, Algorithms, and External Integrations (Zero-Code Modification Inspection)

---

## Executive Summary

PropMatch AI is architected as an intelligent marketing and buyer-matching platform tailored for Malaysian real estate negotiators and agents (with an initial geographical focus on the Northern Corridor: Penang, Kedah, and Perak). 

The application currently presents a **high-fidelity, responsive, and visually cohesive SaaS frontend interface** built with Flutter Web. The design system, typography, color scheme, navigation structure, and thematic cues are fully developed. 

However, from an architectural and engineering standpoint, **the application currently operates almost entirely in-memory with client-side deterministic simulation algorithms.** 
- There is **zero persistent storage** connected (no Firestore, SQLite, Hive, or SharedPreferences). A browser refresh (`F5`) completely resets user actions, newly created projects, captured leads, and campaigns back to the initial seed state.
- **No external AI APIs (Google Gemini, OpenAI, Anthropic)** or cloud inference endpoints are currently integrated. The "AI" features run on rule-based heuristic algorithms written in pure Dart with artificial delay timers (`Future.delayed()`) to simulate computation.
- **Zero marketing API integrations** exist (no Meta Graph API, TikTok for Business, or WhatsApp Business Cloud API).
- Several screens contain **hardcoded demo data or direct list mutations that bypass Flutter state notifications**.

Below is the detailed, module-by-module technical audit followed by the architectural readiness assessment, top critical defects, backend requirements, implementation roadmaps, and the functionality matrix.

---

## Detailed Module-by-Module Audit

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AUDIT TAXONOMY                                    │
│  [ACTIVE]   : Fully functional in-memory logic & interactive UI controls.        │
│  [SIMULATED]: Client-side algorithmic simulation (mock AI / heuristic rules).   │
│  [STATIC]   : Visual UI mockup / hardcoded figures without dynamic state.       │
│  [UNLINKED] : Isolated widget state; disconnected from AppStateProvider.        │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### Module 1: Dashboard

*File: `lib/screens/dashboard/dashboard_screen.dart`*

#### 1. What the module currently does
The Dashboard acts as the operational nerve center for the property agent. It features:
- A prominent **Active Focus Project Spotlight Banner** showing the currently selected property (price range, sqft, beds/baths, suitability purpose, and developer).
- A **Data Transparency & Compliance Notice** informing agents of demo isolation rules and algorithmic hypotheses.
- An **Overview Statistics Grid** with 4 KPI cards (Total Projects, Total Buyers Registered, Qualified Leads, and Average Match Rate).
- A **Lead Acquisition Overview** section summarizing enquiry capture channels (WhatsApp, Facebook/IG, Google Search, Referral) and pipeline funnel health.
- A 2-column desktop layout featuring **High-Priority Leads & Enquiries** (recent 4 leads) on the left, and **Contextual AI Recommendations** with actionable shortcuts on the right.

#### 2. Fully functional features
- **Dynamic Metric Aggregation**: KPI cards dynamically reflect in-memory provider getters (`activeProjectCount`, `totalBuyerCount`, `qualifiedLeadCount`, `averageMatchRate`).
- **Contextual Action Shortcuts**:
  - "Discover AI Audiences" navigates to `NavItem.audienceDiscovery` and invokes `appState.runAudienceDiscovery()`.
  - "Run AI Buyer Matching" navigates to `NavItem.matching` and invokes `appState.runBuyerMatching()`.
  - "Generate Marketing Strategy" navigates to `NavItem.marketing` and triggers `appState.generateMarketingContent()`.
  - "View All Leads" and "Acquisition Analytics" correctly route to the Leads and Analytics tabs.
  - "Generate 100 Demo Buyers" action tile calls `appState.generate100DemoBuyers()` and updates the app state reactively.

#### 3. UI demonstrations / Simulated features
- **Lead Acquisition Breakdown**: Channel counts (`leadsBySource`) are computed dynamically, but the underlying data consists solely of the 4 initial mock leads or manually added leads.
- **Funnel Statistics**: Pipeline Conversion Rate is calculated as `(qualifiedLeadCount / totalLeads) * 100`. It is a simple arithmetic ratio over in-memory leads, not an analytical funnel tracking time-to-conversion, drop-offs, or lead velocity.

#### 4. Data sources
- In-memory `AppStateProvider` populated initially by `DemoDataService.getInitialProjects()` and `DemoDataService.getInitialLeads()`.

#### 5. Connected to Firebase or external APIs?
- **No.** Zero network calls, zero Firebase integration.

#### 6. Buttons and interactions that do not work
- **Stat Cards**: Stat cards (`c1`, `c2`, `c3`, `c4`) are non-clickable display widgets; clicking them does not navigate to their corresponding modules.
- **Recent Leads Rows**: Clicking a row in the "High-Priority Leads & Enquiries" table does nothing (no row selection callback, no detail modal).

#### 7. Missing business logic
- No date-range or period filtering (e.g., Today, This Week, This Month).
- No agent commission calculation or sales target velocity tracking.
- No real-time webhook listeners for incoming leads.

#### 8. UI/UX problems
- On screens between 600px and 900px, the project spotlight header text and buttons can wrap awkwardly.
- The recent leads table uses a fixed `take(4)` slice; if more leads exist, there is no in-table pagination.

#### 9. Potential bugs and inconsistencies
- If no project is selected (`selectedProject == null`), clicking the action buttons in the Spotlight card safely aborts inside `appState`, but does not provide user feedback explaining that a project must be selected first.

---

### Module 2: Property Projects Portfolio

*File: `lib/screens/projects/projects_screen.dart`*

#### 1. What the module currently does
Manages the agent’s portfolio of property developments. Provides:
- A responsive card grid displaying development projects (images, status badge, location, state, price range, bedrooms, bathrooms, built-up sqft, and description).
- State-level filtering via choice chips ('All', 'Penang', 'Kedah').
- A modal dialog to add new property developments.
- Quick action triggers per card to set as active project, run audience discovery, run buyer matching, or delete the project.

#### 2. Fully functional features
- **State Filtering**: Correctly filters `appState.projects` based on the selected Malaysian state.
- **Set Active Project**: Updates `selectedProject` in `AppStateProvider`, propagating immediately to the top navigation bar and contextual screens.
- **Direct Navigation Links**: Clicking "Discover Audiences" or "Match Buyers" sets the project, navigates to the respective tab, and triggers the corresponding engine.
- **Delete Project**: Removes the project from `_projects` in `AppStateProvider`.

#### 3. UI demonstrations / Simulated features
- **Image URLs**: External Unsplash URLs (`https://images.unsplash.com/...`). If network connectivity fails, it falls back to a static icon placeholder.
- **Unit Inventory**: No actual inventory tracking (available vs. sold units, floor level, unit types A/B/C).

#### 4. Data sources
- In-memory `_projects` list in `AppStateProvider`. Seeded with:
  1. `EXSIM Demo Residence` (Batu Kawan, Penang)
  2. `Gurney Premier Suites` (George Town, Penang)

#### 5. Connected to Firebase or external APIs?
- **No.**

#### 6. Buttons and interactions that do not work
- **No Edit Project Feature**: There is no "Edit Project" button or dialog. Once a project is added, its price, name, or description cannot be edited.
- **Instant Deletion without Confirmation**: Clicking the delete icon (`Icons.delete_outline`) immediately deletes the project without any confirmation dialog or "Undo" snackbar.

#### 7. Missing business logic
- **Form Input Validation**: The "Add New Project" dialog does not validate that `startingPrice <= maximumPrice`, nor does it reject negative numbers or non-numeric inputs gracefully.
- **No Asset/Image Upload**: New projects cannot upload images, brochures, or floor plan PDFs. They are assigned an empty `imageUrls: []` list and render as blank dark cards.
- **State Filter Hardcoding**: The filter chips only offer `['All', 'Penang', 'Kedah']`. If a user adds a project in `'Kuala Lumpur'`, `'Selangor'`, or `'Johor'`, there is no chip for it; it can only be viewed under `'All'`.

#### 8. UI/UX problems
- Grid aspect ratio `childAspectRatio: 0.85` can cause description overflow or clipping on certain browser viewport widths.

#### 9. Potential bugs and inconsistencies
- **CRITICAL STRING INTERPOLATION BUG (Line 481)**:
  ```dart
  description: descCtrl.text.trim().isEmpty
      ? 'Modern high-yield property project located in $locCtrl.'
      : descCtrl.text.trim(),
  ```
  `$locCtrl` interpolates the `TextEditingController` instance instead of `locCtrl.text`. When triggered, it produces:  
  `"Modern high-yield property project located in TextEditingController#84920(TextEditingValue(text: 'Batu Kawan'))..."`

---

### Module 3: AI Audience Discovery

*Files: `lib/screens/audience/audience_discovery_screen.dart`, `lib/services/ai_service.dart`*

#### 1. What the module currently does
Analyzes the currently selected property project and generates target buyer persona archetypes and interstate geographic strategies for the Malaysian property market. Features:
- Rule-based persona generation (9 distinct archetypes: First-time buyers, Young tech professionals, Penang Island upgraders, Klang Valley investors, Singapore/Expat cross-border buyers, Medical tourism retirees, Short-stay/Airbnb operators, Multi-generational families, Industrial factory managers).
- Explainable suitability scoring (clamped between 60% and 93%) with explicit breakdown of positive drivers, negative friction points, and missing data gaps.
- Transparent demographic assumptions with explicit "hypothetical marketing estimate" disclaimers.
- Interstate geographic audience strategy covering Penang, Kedah, Perak, Klang Valley (KL/Selangor), Johor, and East Malaysia.
- Multi-channel marketing copy generators (Facebook, Instagram, TikTok scripts, headlines, call-to-actions).
- One-click copy-to-clipboard and a "Campaign Studio" handoff button.

#### 2. Fully functional features
- **Deterministic Heuristic Engine**: Dynamic property evaluation based on price tier, bedrooms, sqft, property type, and purpose.
- **Explainable Factor Attribution**: Positive factors, objections, and missing data gaps adapt logically to project characteristics.
- **Interstate Expansion Strategy**: Multi-state breakdown with rationales, angles, and marketing opportunities.
- **Reactive Project Switching**: Changing the focus project in the dropdown automatically re-evaluates audiences if discovery was previously run.
- **Copy-to-Clipboard**: Fully working clipboard integration with visual snackbar feedback.
- **Campaign Studio Integration**: Pre-selects the audience and project and transitions seamlessly into the Marketing Assistant.

#### 3. UI demonstrations / Simulated features
- **Simulated AI Processing**: The analysis includes an artificial delay (`Future.delayed(const Duration(milliseconds: 700))`) to simulate neural inference. The engine is entirely client-side Dart logic.
- **Hypothetical Market Data**: All demographic figures (e.g. median household income RM8,500 - RM14,000, age brackets) and interstate migration signals are heuristic estimates, not verified Census, JPPH, or NAPIC records (explicitly labeled as hypothetical).

#### 4. Data sources
- In-memory `AppStateProvider._audienceSegments` and `_geoStrategies`.

#### 5. Connected to Firebase or external APIs?
- **No.** Does not call OpenAI, Google Gemini, Anthropic, or external real estate data APIs.

#### 6. Buttons and interactions that do not work
- All interactive elements (tab switches, expand/collapse toggles, copy buttons, dropdowns) work as coded.

#### 7. Missing business logic
- No integration with advertising platforms (Meta Business SDK / TikTok Ads API) to create live custom audience segments or Lookalikes.
- No export feature to download the audience analysis as a client-ready PDF pitch deck.

#### 8. UI/UX problems
- Deep card expansion: when an audience card is expanded, the volume of content (positive factors, objections, marketing angles, channels, demographic assumptions, and multi-channel creative) creates a very tall card that requires significant vertical scrolling.

#### 9. Potential bugs and inconsistencies
- If a project has extreme values (e.g. RM 50,000 or RM 20,000,000), the heuristic rules handle boundaries with fallbacks, but some generated copy may read awkwardly for edge-case commercial properties.

---

### Module 4: Buyer Management

*Files: `lib/screens/buyers/buyers_screen.dart`, `lib/services/demo_data_service.dart`*

#### 1. What the module currently does
Displays a master directory of registered property buyers. Features:
- An in-memory searchable and filterable data table showing buyer name, budget range, preferred location/state, property type, purpose, timeline, lead status, and action buttons.
- Search input matching buyer name, location, and property type.
- Dropdown filter by lead status ('All', 'New', 'Contacted', 'Interested', 'Viewing Scheduled', 'Negotiating').
- Profile inspection dialog displaying complete buyer notes, consultation history, and demographic tags.
- Quick button to trigger "Match with Project".
- 100-demo-profile synthetic generator.

#### 2. Fully functional features
- **Search & Filtering**: Real-time filtering via `appState.setBuyerSearchQuery()` and `appState.setBuyerStatusFilter()`.
- **Demo Data Generator**: `generate100DemoBuyers()` populates the system with 100 synthetic Malaysian buyer profiles with realistic Penang/Kedah parameters.
- **Profile Inspector**: `_showBuyerDetailModal` displays all buyer parameters, notes, and demo isolation status.
- **Project Matching Shortcut**: Routes directly to matching engine and runs evaluation.

#### 3. UI demonstrations / Simulated features
- All 100 buyer profiles are generated via pseudorandom permutations of Malaysian names (Chinese, Malay, Indian), budget tiers, and location preferences in `DemoDataService`.

#### 4. Data sources
- In-memory `_buyers` list in `AppStateProvider`.

#### 5. Connected to Firebase or external APIs?
- **No.**

#### 6. Buttons and interactions that do not work
- **NO "ADD BUYER" BUTTON**: An agent cannot manually register a real walk-in or referral buyer from this screen.
- **NO EDIT / DELETE BUYER**: Individual buyer records cannot be edited or deleted.

#### 7. Missing business logic
- **Hardcoded Display Truncation (`.take(50)`)**:
  ```dart
  rows: appState.buyers.take(50).map((buyer) { ... })
  ```
  The table hardcodes a limit of 50 profiles. There are **no pagination controls** (no Page 2, no Next/Previous buttons). When 100 demo buyers are loaded, 50 of them are inaccessible unless filtered down by search.
- **No WhatsApp Communication Action**: The table does not offer a direct WhatsApp click-to-chat button (`https://wa.me/...`) to initiate conversations.
- **No CSV/Excel Import or Export**: Cannot import existing client lists from spreadsheets.

#### 8. UI/UX problems
- Horizontal scrolling is necessary on standard laptop viewports because the `DataTable` has 9 wide columns.
- No multi-select checkboxes for bulk operations.

#### 9. Potential bugs and inconsistencies
- The counter badge at the top shows `${appState.buyers.length} Profiles`, which reflects the *filtered* length, while the subtitle says `Total Buyers Registered`, causing confusion when search queries are active.

---

### Module 5: Lead Management Pipeline

*File: `lib/screens/leads/leads_screen.dart`*

#### 1. What the module currently does
Tracks active buyer enquiries through pipeline stages. Features:
- Filterable pipeline table showing Buyer Name, Project, Acquisition Source, Estimated Deal Value, and Stage.
- Stage filter choice chips ('All', 'New', 'Contacted', 'Qualified', 'Negotiating', 'Won', 'Lost').
- Dialog to capture new voluntary buyer enquiries.
- One-click action to mark a deal as "Won".

#### 2. Fully functional features
- **Filter Chips**: Filters leads list by stage.
- **Capture Enquiry Dialog**: Captures name, project, acquisition channel, deal value, and notes.

#### 3. UI demonstrations / Simulated features
- Default initial leads (4 records) loaded from `DemoDataService.getInitialLeads()`.

#### 4. Data sources
- In-memory `_leads` list in `AppStateProvider`.

#### 5. Connected to Firebase or external APIs?
- **No.**

#### 6. Buttons and interactions that do not work
- **Single-Direction Status Update Only**: The row action only has a single green checkmark icon (`Icons.check_circle_outline`) that marks the lead as "Won". **There is no way to advance a lead to 'Contacted', 'Qualified', 'Negotiating', or mark as 'Lost' from the table.**
- **No Detail Modal or Row Click**: Clicking on a lead does not open notes or contact details.
- **No Delete Action**: Leads cannot be deleted.

#### 7. Missing business logic
- **DIRECT STATE MUTATION BUG (Line 319)**:
  ```dart
  appState.leads.insert(0, newLead);
  Navigator.of(ctx).pop();
  setState(() {});
  ```
  `appState.leads` is mutated directly without calling a provider method or `notifyListeners()`. Other screens listening to `AppStateProvider` (such as the Dashboard and Analytics) will **not be notified** of the new lead until they trigger their own rebuilds.
- **No Kanban Board View**: Despite being presented as a "Lead Management Pipeline", it is rendered as a static `Table`. There is no drag-and-drop Kanban view across stages.
- No audit log of status changes, agent remarks, or follow-up history.

#### 8. UI/UX problems
- Column widths are tightly constrained (`FlexColumnWidth`), resulting in text clipping on lower resolution screens.

#### 9. Potential bugs and inconsistencies
- **Crash Risk on Empty Projects (Line 305)**:
  ```dart
  final project = appState.projects.firstWhere((p) => p.id == projectVal);
  ```
  If all projects have been deleted and a user tries to add an enquiry, this line throws an unhandled `StateError: Bad state: No element`.

---

### Module 6: AI Buyer Matching Engine

*Files: `lib/screens/matching/matching_screen.dart`, `lib/services/matching_service.dart`*

#### 1. What the module currently does
Matches registered buyers against the active property project. Features:
- 5-factor weighted matching algorithm in `matching_service.dart`:
  - Budget Compatibility: 25% weight
  - Location Preference: 25% weight
  - Property Type Fit: 20% weight
  - Purchase Purpose: 15% weight
  - Buying Timeline: 15% weight
- Cohort filter chips: 'All', 'High (>75%)', 'Moderate (50-75%)', 'Low (<50%)'.
- 2-column desktop split view: Candidate List on the left, deep-dive Inspector on the right.
- Detailed score breakdown progress bars, positive matching factors, potential concerns, and information gaps.
- "Convert to Qualified Lead Pipeline" button.

#### 2. Fully functional features
- **Algorithmic Evaluation**: Accurately computes multi-factor mathematical scores with explainable rationales.
- **Split-View Inspector**: Selecting a candidate immediately populates the inspector pane with dimension breakdowns.
- **Pipeline Conversion**: Converts a match into an active pipeline lead via `appState.addLeadFromMatch(match)`.

#### 3. UI demonstrations / Simulated features
- Artificial 400ms calculation delay (`Future.delayed(const Duration(milliseconds: 400))`).
- If no buyers exist when "Run Matching Engine" is triggered, it automatically executes `generate100DemoBuyers()` behind the scenes.

#### 4. Data sources
- In-memory `_matches` list generated from `_buyers` and `_selectedProject`.

#### 5. Connected to Firebase or external APIs?
- **No.**

#### 6. Buttons and interactions that do not work
- All buttons (filtering, selection, conversion) work as coded.

#### 7. Missing business logic
- **Duplicate Conversion**: Clicking "Convert to Qualified Lead Pipeline" multiple times creates duplicate leads in the pipeline; there is no deduplication check to see if `buyerId` and `projectId` already exist in `_leads`.
- **Rigid Scoring Weights**: Weights are hardcoded (25/25/20/15/15). Agents cannot adjust weight priorities (e.g. weighting budget higher for luxury properties).
- No batch export of matched candidates (e.g. export top 10 matches to CSV).

#### 8. UI/UX problems
- Candidate list uses `ListView.separated` with `physics: NeverScrollableScrollPhysics()` inside a `SingleChildScrollView`. When 100 matches are present, 100 full list tiles are instantiated simultaneously, which can cause micro-stutters during rendering on mobile or low-spec browsers.

#### 9. Potential bugs and inconsistencies
- If `selectedProject` is null, the "Run Matching Engine" button is disabled, but no tooltip or instruction indicates why it is disabled.

---

### Module 7: Marketing AI Assistant

*Files: `lib/screens/marketing/marketing_screen.dart`, `lib/services/marketing_service.dart`*

#### 1. What the module currently does
Generates multi-channel marketing collateral tailored to the active project and target audience segment. Features:
- Dropdowns for Focus Project and Target Audience Segment.
- Primary ad headline highlight banner with copy button.
- Tabbed copy views for 5 formats:
  1. Facebook Ad Copy (long-form with emojis, bullets, packages, hashtags)
  2. Instagram Caption (aesthetic copy, features, DM call-to-actions)
  3. TikTok Video Script & Hook (timed 30-second script with visual & audio cues)
  4. WhatsApp Direct Message (personalized agent outreach script)
  5. Campaign Strategy & Concept (angles, audience targeting, lead magnets)
- One-click copy-to-clipboard for every channel.
- "Launch Campaign" button that creates an active campaign.

#### 2. Fully functional features
- **Template Generation**: `MarketingService.generateContent()` interpolates project details (name, developer, location, price, beds, built-up sqft, purpose) and audience name.
- **Clipboard Integration**: Copies full copy to clipboard reliably.
- **Campaign Handoff**: `createCampaign()` generates a new `CampaignModel` in `_campaigns` and navigates to the Campaigns screen.

#### 3. UI demonstrations / Simulated features
- **Template Interpolation vs. AI Generation**: Generation uses fixed template string interpolation with a 400ms delay. It is **not generative AI** (no LLM prompts, no natural language variation). Running generation twice produces identical output.
- **"Launch Campaign" is In-Memory Only**: Does not publish ads to Meta Ads Manager, TikTok For Business, or WhatsApp Business API.

#### 4. Data sources
- In-memory `_generatedMarketingContent` in `AppStateProvider`.

#### 5. Connected to Firebase or external APIs?
- **No.**

#### 6. Buttons and interactions that do not work
- All copy buttons, tab transitions, and campaign creation buttons work as implemented.

#### 7. Missing business logic
- **No In-Place Copy Editing**: The copy is displayed inside a read-only `SelectableText`. Agents cannot customize or tweak the copy in-app before copying or launching a campaign.
- **No Asset/Creative Generation**: No visual ad creatives, banner mockups, or image assets are generated.
- **No Multiple Copy Variations**: Does not offer alternative angles (e.g. "Urgency Angle", "Investment Yield Angle", "Family Lifestyle Angle").

#### 8. UI/UX problems
- `SizedBox(height: 450)` for `TabBarView` is fixed-height. On long scripts (like the TikTok script or full Facebook copy), inner scrolling is required inside an already scrollable page (nested scrollviews).

#### 9. Potential bugs and inconsistencies
- If `selectedProject` is null, the generate button is disabled without explanatory text.

---

### Module 8: Multi-Channel Campaign Management

*File: `lib/screens/campaigns/campaigns_screen.dart`*

#### 1. What the module currently does
Displays and tracks advertising campaigns launched from the Marketing Assistant. Features:
- 3 top KPI summary cards: Total Estimated Reach, Ad Clicks / Engagements, Generated Enquiries.
- A list of campaign cards showing platform badge (Facebook, Instagram, TikTok, WhatsApp), campaign title, project, target audience, headline, status, and performance metrics (Reach, Clicks, Enquiries).
- Shortcut to Marketing AI to launch new campaigns.

#### 2. Fully functional features
- Dynamic sum calculations across all campaigns in memory for Total Reach, Clicks, and Enquiries.
- Navigation link to Marketing AI screen.

#### 3. UI demonstrations / Simulated features
- **Entirely Synthetic Performance Metrics**: When a campaign is created via `AppStateProvider.createCampaign()`, it receives hardcoded static metrics:
  ```dart
  reach: 1250,
  clicks: 84,
  enquiries: 6,
  ```
  These metrics never increment, change, or reflect real ad delivery.

#### 4. Data sources
- In-memory `_campaigns` list in `AppStateProvider`. Pre-seeded with 1 demo campaign: `EXSIM Batu Kawan - Facebook Investor Blast`.

#### 5. Connected to Firebase or external APIs?
- **No.** Zero integration with Meta Marketing API, Google Ads API, or TikTok Ads API.

#### 6. Buttons and interactions that do not work
- **NO PAUSE, STOP, OR RESUME**: Campaigns cannot be paused, stopped, or edited.
- **NO DELETE CAMPAIGN**: Campaigns cannot be deleted.
- Campaign cards are non-clickable static cards.

#### 7. Missing business logic
- No financial tracking (Ad Spend, Cost Per Click, Cost Per Lead, Return on Ad Spend).
- No link between campaign enquiries and the Lead Management Pipeline (enquiries generated by campaigns do not create entries in the Leads table).
- No date scheduling (Start Date, End Date, Daily Budget).

#### 8. UI/UX problems
- On narrow viewports, the child aspect ratio of the top stat cards (`3.0`) causes tight vertical squishing of text.

#### 9. Potential bugs and inconsistencies
- The status of every campaign is permanently hardcoded to `'Active'`.

---

### Module 9: Follow-up Management & Viewing Schedules

*File: `lib/screens/followups/followups_screen.dart`*

#### 1. What the module currently does
Provides a personal task checklist and viewing schedule for the agent. Features:
- List of scheduled tasks with buyer name, project name, task description, due date tag, category badge, and a completion checkbox.
- Toggling the checkbox strikes through the text.
- Dialog to schedule a new follow-up task.

#### 2. Fully functional features
- Checkbox toggle marks an item completed (visual strikethrough).
- Add task dialog appends a new follow-up item to the local list.

#### 3. UI demonstrations / Simulated features
- Seeded with 4 hardcoded items (`f-1` to `f-4`) featuring fictional buyers (`Ahmad Ismail`, `Wei Lun Tan`, `Kavitha Ramasamy`, `Chee Meng Wong`).

#### 4. Data sources
- **LOCAL STATE ONLY (`_FollowupsScreenState`)**:
  ```dart
  final List<Map<String, dynamic>> _followups = [ ... ];
  ```
  This data is **not stored in `AppStateProvider`** and has no model class (no `FollowupModel`).

#### 5. Connected to Firebase or external APIs?
- **No.**

#### 6. Buttons and interactions that do not work
- No edit task button.
- No delete task button.

#### 7. Missing business logic
- **TOTAL STATE VOLATILITY (State Loss on Navigation)**:
  Because `_followups` is stored in the local `State` of `FollowupsScreen`, whenever the agent navigates to another module and the widget unmounts, newly added tasks or checked checkboxes may reset to default upon returning.
- **Zero Integration with Buyers or Leads**: Buyer names are entered as raw unvalidated strings; they do not link to `BuyerModel` or `LeadModel`.
- **No Real Date/Time Selection**: The add dialog has no date or time picker; it assigns a hardcoded string `'Tomorrow, 10:00 AM'`.
- No calendar synchronization (Google Calendar, iCal) or browser notifications.

#### 8. UI/UX problems
- Lacks calendar views (Day, Week, Month) or urgency sorting (Overdue, Due Today, Upcoming).

#### 9. Potential bugs and inconsistencies
- **Hardcoded Target Project (Line 211)**:
  ```dart
  'project': 'Active Focus Project',
  ```
  When an agent adds a follow-up, the project name is literally stored as `'Active Focus Project'` rather than using `appState.selectedProject?.name`.

---

### Module 10: Market Analytics & Lead Intelligence

*File: `lib/screens/analytics/analytics_screen.dart`*

#### 1. What the module currently does
Intended to provide regional market intelligence and buyer intent signals. Displays:
- 4 high-level KPI cards: Total Demand Index, Avg. Target Budget, Lead Conversion Rate, Top Demand Area.
- "Regional Buyer Location Preference" progress bars (Batu Kawan, Bayan Lepas, Kulim, George Town, Central).
- "Buyer Budget Spectrum" progress bars (<RM450k, RM450k-RM650k, RM650k-RM900k, >RM900k).
- "Lead Acquisition Signals" table showing simulated search query surges.

#### 2. Fully functional features
- Responsive multi-column layout rendering cleanly on desktop and tablet.

#### 3. UI demonstrations / Simulated features
- **ALMOST 100% HARDCODED STATIC DEMO**:
  Despite accepting `final appState = context.watch<AppStateProvider>();` on line 11:
  - Total Demand Index: `'87.4'` (Hardcoded string)
  - Avg. Target Budget: `'RM 540,000'` (Hardcoded string, not calculated from `appState.buyers`)
  - Lead Conversion Rate: `'14.2%'` (Hardcoded string, completely ignores `appState.pipelineConversionRate`)
  - Top Demand Area: `'Batu Kawan'` (Hardcoded string)
  - Regional Buyer Location Preference: 38%, 26%, 18%, 12%, 6% (Hardcoded doubles)
  - Buyer Budget Spectrum: 30%, 42%, 18%, 10% (Hardcoded doubles)
  - Simulated Market Signals: 3 static text rows (+42%, +18%, +35%)

#### 4. Data sources
- None. Hardcoded inline constants inside widget build methods.

#### 5. Connected to Firebase or external APIs?
- **No.**

#### 6. Buttons and interactions that do not work
- No interactive controls exist on this screen. No date filtering, no region filtering, no chart drill-downs.

#### 7. Missing business logic
- Does not compute real distributions from registered buyer records or leads.
- No charting library (e.g. `fl_chart`) is integrated; only simple `LinearProgressIndicator` bars are drawn.
- No export or report generation capability.

#### 8. UI/UX problems
- Provides the visual impression of real-time market telemetry, but the values never change regardless of user actions in the app.

#### 9. Potential bugs and inconsistencies
- **Metric Contradiction with Dashboard**: The Dashboard displays the real computed conversion rate from active leads (e.g. `25%`), whereas the Analytics screen displays a hardcoded `'14.2%'`. An agent looking at both screens sees contradictory numbers.

---

### Module 11: Settings & System Configuration

*File: `lib/screens/settings/settings_screen.dart`*

#### 1. What the module currently does
Displays agent profile metadata, demo data isolation tools, security rules documentation, and build metadata. Features:
- Agent Profile Card (Agent name, REN title, Owner ID, Region).
- Demo Data Isolation Controls (buttons to regenerate or clear demo buyer profiles).
- Firestore Security Rules code preview.
- Application build metadata card.

#### 2. Fully functional features
- "Regenerate 100 Demo Buyers" calls `appState.generate100DemoBuyers()` and refreshes buyer profiles.

#### 3. UI demonstrations / Simulated features
- Agent profile information is hardcoded static text.
- The Firestore Security Rules block is an educational code preview of `firestore.rules`. Firestore itself is not connected.

#### 4. Data sources
- In-memory `appState.currentOwnerId` and `AppConstants`.

#### 5. Connected to Firebase or external APIs?
- **No.**

#### 6. Buttons and interactions that do not work
- Agent profile has no edit button or form to update agent name, REN number, phone number, or agency.

#### 7. Missing business logic
- **DIRECT MUTATION BUG ON CLEAR DEMO PROFILES (Line 119)**:
  ```dart
  appState.buyers.removeWhere((b) => b.isDemo);
  ```
  `appState.buyers` is directly mutated without calling a provider method or `notifyListeners()`. The rest of the app (Dashboard stat counters, Buyer directory badge, TopBar) will **not update** until the user forces a re-render.
- No authentication settings (change password, update email).
- No theme switcher (Dark / Light mode).
- No localization / language switcher (English / Bahasa Malaysia / Simplified Chinese).

#### 8. UI/UX problems
- Displaying raw Firestore rules code in an end-user real estate agent application settings page is developer-centric and confusing for non-technical property agents.

#### 9. Potential bugs and inconsistencies
- None beyond the unnotified state mutation on line 119.

---

### Auxiliary Core Components: Authentication & App Shell

*Files: `lib/main.dart`, `lib/app.dart`, `lib/screens/auth/login_screen.dart`, `lib/widgets/top_bar.dart`*

#### 1. Login & Session State
- **Default Authentication Bypass**: In `lib/app.dart`, `_isLoggedIn` is initialized to `true` by default:
  ```dart
  bool _isLoggedIn = true;
  ```
  When the app opens, it automatically bypasses the login screen directly to the Dashboard.
- **Hardcoded Credentials**: In `login_screen.dart`, authentication checks against hardcoded strings:
  ```dart
  if (_emailController.text == 'agent@propmatch.ai' && _passwordController.text == 'demo1234')
  ```
  with an artificial delay of 800ms.
- **No Auth Token or Persistence**: No Firebase Auth, JWT, or cookie session. Signing out via TopBar sets `_isLoggedIn = false`, but refreshing the page immediately logs back in due to `_isLoggedIn = true` default.

#### 2. Top Navigation Bar
- **Project Quick-Switcher**: Fully functional dropdown allowing the agent to switch focus projects globally.
- **Notifications Icon**: Triggers a simulated SnackBar message: `"Simulated Notifications: No pending alerts."`
- **Sign Out Action**: Triggers callback in `AppShell` to set `_isLoggedIn = false`.

---

## Section A: Overall Application Readiness Assessment

| Evaluation Dimension | Readiness Score | Status | Summary Assessment |
|:---|:---:|:---:|:---|
| **Frontend UI / UX Design** | **85%** | **Strong** | Highly polished, responsive desktop SaaS interface. Clean typography, consistent color palette, intuitive iconography, responsive breakpoints, and professional card layouts. |
| **Client-Side State Management** | **70%** | **Good** | Centralized `AppStateProvider` coordinates projects, buyers, leads, and audience segments well. Minor state bugs exist where collections are mutated directly without `notifyListeners()`. |
| **Heuristic & Rule-Based Engines** | **80%** | **High** | Audience Discovery and Buyer Matching engines have well-formulated, explainable mathematical logic with clear attribution of positive and negative compatibility factors. |
| **Data Persistence & Storage** | **0%** | **Non-Existent** | Zero persistent database. Refreshing the browser resets all state. No SQLite, Hive, IndexedDB, or Firestore integration. |
| **Real AI / LLM Capabilities** | **15%** | **Simulated** | Marketing copy and audience profiles are generated via heuristic rules and static string interpolation. No integration with Google Gemini, OpenAI, or LLMs. |
| **External Service Integrations** | **0%** | **Non-Existent** | No connections to Meta Ads, TikTok Ads, Google Ads, WhatsApp Business API, or Cloud Storage. |
| **Production Authentication & Security** | **10%** | **Mock Only** | Hardcoded login credentials with default bypass. No JWT tokens, session persistence, or real user roles. |
| **OVERALL SYSTEM READINESS** | **38%** | **Prototype Phase** | **Exceptional interactive prototype / MVP demo**. Not yet ready for commercial production deployment without backend integration. |

---

## Section B: Top 10 Critical Issues

1. **Zero Data Persistence (Browser Refresh Loss)**  
   *Severity: Critical (Blocker)*  
   Any page reload (`F5`) or closed tab completely wipes out all newly created projects, captured leads, generated demo profiles, and custom campaigns.

2. **Absence of Real Firebase or Backend Database**  
   *Severity: Critical (Blocker)*  
   `pubspec.yaml` does not include `firebase_core`, `cloud_firestore`, or `firebase_auth`. Despite `firestore.rules` and `firebase.json` existing in the repository, the Flutter app cannot communicate with Firestore.

3. **String Interpolation Bug in Project Creation (`projects_screen.dart#L481`)**  
   *Severity: High (Functional Bug)*  
   Creating a project with an empty description interpolates the controller instance (`$locCtrl`) instead of `locCtrl.text`, injecting raw memory object strings into the UI.

4. **Direct State Mutations Bypassing `notifyListeners()`**  
   *Severity: High (State Inconsistency)*  
   - In `leads_screen.dart#L319`: `appState.leads.insert(0, newLead)` bypasses provider notifications.  
   - In `settings_screen.dart#L119`: `appState.buyers.removeWhere((b) => b.isDemo)` bypasses provider notifications.  
   These cause other screens (Dashboard, Analytics, TopBar) to remain out of sync.

5. **Local Widget State Volatility in Follow-ups (`followups_screen.dart#L12`)**  
   *Severity: High (Data Loss)*  
   The Follow-ups module stores its checklist in the local `State` of `FollowupsScreen`. Navigating between sidebar tabs causes the widget to dispose, resetting all checks and newly added schedules.

6. **Hardcoded Truncation of Buyers Table (`buyers_screen.dart#L188`)**  
   *Severity: Medium (UX/Functionality Defect)*  
   The table hardcodes `.take(50)` with no pagination bar. Half of the 100 generated demo buyers are completely unreachable unless filtered down via search.

7. **One-Way Lead Pipeline Progression (`leads_screen.dart#L204`)**  
   *Severity: Medium (Workflow Incompleteness)*  
   The only action button on a lead row is "Mark Deal Won". Agents cannot transition leads to 'Contacted', 'Qualified', 'Negotiating', or 'Lost'.

8. **Hardcoded Mock Numbers in Analytics vs. Real Dashboard Stats**  
   *Severity: Medium (Data Discrepancy)*  
   `analytics_screen.dart` displays hardcoded conversion rates (`14.2%`), demand indices, and budget brackets, contradicting the live computed numbers on the Dashboard.

9. **Inability to Manually Register Real Buyers (`buyers_screen.dart`)**  
   *Severity: Medium (Missing Core Feature)*  
   There is no "Add Buyer" button in the Buyer Management screen. The system only permits generating synthetic demo buyers.

10. **Duplicate Lead Creation from AI Match Conversions (`matching_screen.dart#L389`)**  
    *Severity: Low (Data Integrity)*  
    Clicking "Convert to Qualified Lead Pipeline" repeatedly creates duplicate lead records with identical parameters without deduplication checks.

---

## Section C: Features Requiring Real Backend Integration

| Feature / Capability | Required Backend Infrastructure | External APIs / SDKs Needed |
|:---|:---|:---|
| **User Authentication & Multi-Tenancy** | Firebase Authentication / Supabase Auth | `firebase_auth`, Google Sign-In, Email/Password |
| **Persistent Data Storage (CRUD)** | Cloud Firestore / PostgreSQL | `cloud_firestore` / Supabase Client |
| **Property Brochure & Image Storage** | Cloud Storage for Firebase / AWS S3 | `firebase_storage` / AWS S3 SDK |
| **Generative Marketing Copy & Strategy** | Serverless Cloud Function / Cloud Run | Google Gemini 1.5 Pro/Flash API / OpenAI API |
| **WhatsApp Direct Outreach** | Twilio / Meta WhatsApp Business Cloud API | WhatsApp Cloud API Webhooks |
| **Ad Campaign Publishing & Reporting** | Meta Marketing API & TikTok Ads API | Meta Graph SDK / TikTok Business API |
| **Lead Ingestion & Webhook Capture** | Cloud Functions for Firebase (HTTP endpoints) | Webhooks from Facebook Lead Ads & Website Forms |
| **Calendar & Viewing Synchronization** | Google Calendar API / CalDAV | Google Calendar API / iCal sync |

---

## Section D: Recommended Development Priorities

```
Phase 1: Architecture & Persistence (Immediate)
├── 1. Add firebase_core, cloud_firestore, firebase_auth to pubspec.yaml
├── 2. Implement Repository Layer (ProjectRepository, BuyerRepository, LeadRepository)
├── 3. Replace in-memory lists in AppStateProvider with Firestore Streams
└── 4. Implement real authentication and session persistence (replace _isLoggedIn = true)

Phase 2: Core Workflow Enhancements (Short-term)
├── 1. Fix string interpolation bug in projects_screen.dart (#L481)
├── 2. Add "Add Buyer" and "Edit Buyer" forms in buyers_screen.dart
├── 3. Implement full pagination for Buyer Directory
├── 4. Convert Lead Management table into a drag-and-drop Kanban Board
├── 5. Migrate FollowupsScreen state to AppStateProvider and create FollowupModel
└── 6. Dynamicize analytics_screen.dart to compute metrics from actual database records

Phase 3: AI & Communication Integrations (Mid-term)
├── 1. Connect Google Gemini API for generative marketing copy variations
├── 2. Integrate WhatsApp click-to-chat links (wa.me) in Buyer and Match screens
├── 3. Implement PDF pitch deck export for AI Audience Discovery
└── 4. Add campaign budget, spend, and schedule management

Phase 4: Multi-Channel Ad Automation (Long-term)
├── 1. Meta Lead Ads webhook integration
└── 2. Google Calendar sync for property viewings
```

---

## Section E: Module-by-Module Functionality Matrix

| # | Module Name | Primary Screen File | UI Fidelity | Logic Maturity | Storage Status | API Integration | Production Readiness |
|:---:|:---|:---|:---:|:---:|:---:|:---:|:---:|
| **1** | **Dashboard** | `dashboard_screen.dart` | 95% | 85% | In-Memory | None | **Beta Ready** |
| **2** | **Property Projects** | `projects_screen.dart` | 90% | 75% | In-Memory | None | **Beta Ready** |
| **3** | **AI Audience Discovery** | `audience_discovery_screen.dart` | 95% | 90% | In-Memory | Rule-based (Simulated AI) | **Beta Ready** |
| **4** | **Buyer Management** | `buyers_screen.dart` | 85% | 65% | In-Memory | None | **Prototype** |
| **5** | **Lead Management** | `leads_screen.dart` | 80% | 60% | In-Memory | None | **Prototype** |
| **6** | **AI Buyer Matching** | `matching_screen.dart` | 95% | 90% | In-Memory | Heuristic Engine | **Beta Ready** |
| **7** | **Marketing Assistant** | `marketing_screen.dart` | 90% | 75% | In-Memory | Template Strings | **Beta Ready** |
| **8** | **Campaign Management** | `campaigns_screen.dart` | 85% | 40% | In-Memory | Hardcoded Stats | **Prototype** |
| **9** | **Follow-up Schedules** | `followups_screen.dart` | 75% | 30% | Local State | None | **Early Prototype** |
| **10** | **Market Analytics** | `analytics_screen.dart` | 90% | 20% | Static Code | Hardcoded Mockup | **UI Demo Only** |
| **11** | **Settings & Config** | `settings_screen.dart` | 80% | 40% | In-Memory | Static Display | **Prototype** |
| **12** | **Auth & App Shell** | `login_screen.dart` / `app.dart` | 85% | 30% | Memory (Bypassed) | None | **Prototype** |

---

*Report prepared and certified by Antigravity Technical Audit Agent.*  
*All findings are directly corroborated by source code inspection of the master repository.*
