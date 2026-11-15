class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'PropMatch AI';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'AI-Powered Property Lead Discovery';

  // Malaysian states (priority order)
  static const List<String> malaysianStates = [
    'Penang',
    'Kedah',
    'Johor',
    'Selangor',
    'Kuala Lumpur',
    'Perak',
    'Sabah',
    'Sarawak',
    'Pahang',
    'Negeri Sembilan',
    'Melaka',
    'Kelantan',
    'Terengganu',
    'Perlis',
    'Putrajaya',
    'Labuan',
  ];

  // Property types
  static const List<String> propertyTypes = [
    'Condominium',
    'Apartment',
    'Terrace House',
    'Semi-Detached',
    'Bungalow',
    'Townhouse',
    'Penthouse',
    'Studio',
    'Serviced Residence',
    'Commercial',
  ];

  // Property purposes
  static const List<String> propertyPurposes = [
    'Own Stay',
    'Investment',
    'Own Stay & Investment',
  ];

  // Project statuses
  static const List<String> projectStatuses = [
    'New Launch',
    'Under Construction',
    'Completed',
    'Upcoming',
  ];

  // Buyer statuses
  static const List<String> buyerStatuses = [
    'New',
    'Contacted',
    'Interested',
    'Viewing Scheduled',
    'Negotiating',
    'Converted',
    'Lost',
  ];

  // Lead statuses
  static const List<String> leadStatuses = [
    'New',
    'Contacted',
    'Qualified',
    'Proposal Sent',
    'Negotiating',
    'Won',
    'Lost',
  ];

  // Lead sources
  static const List<String> leadSources = [
    'Facebook Ads',
    'Instagram',
    'TikTok',
    'Google Search',
    'WhatsApp Enquiry',
    'Referral',
    'Walk-in',
    'Property Portal',
    'Landing Page',
    'Other',
  ];

  // Buying timelines
  static const List<String> buyingTimelines = [
    'Immediately',
    'Within 3 months',
    'Within 6 months',
    'Within 1 year',
    'Just exploring',
  ];

  // Marketing platforms
  static const List<String> marketingPlatforms = [
    'Facebook',
    'Instagram',
    'TikTok',
    'WhatsApp',
    'Google Ads',
    'Property Portal',
    'Email',
  ];

  // Matching weights
  static const double weightBudget = 0.25;
  static const double weightLocation = 0.25;
  static const double weightPropertyType = 0.20;
  static const double weightPurpose = 0.15;
  static const double weightTimeline = 0.15;

  // Responsive breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
}
