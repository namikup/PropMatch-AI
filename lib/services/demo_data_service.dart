import '../models/project_model.dart';
import '../models/buyer_model.dart';
import '../models/lead_model.dart';

class DemoDataService {
  static const String demoOwnerId = 'demo-agent-001';

  /// Initial sample property projects (Penang and Kedah prioritized)
  static List<ProjectModel> getInitialProjects() {
    return [
      ProjectModel(
        id: 'proj-001',
        ownerId: demoOwnerId,
        name: 'EXSIM Demo Residence',
        developer: 'EXSIM Development Sdn Bhd',
        location: 'Batu Kawan',
        state: 'Penang',
        propertyType: 'Condominium',
        startingPrice: 450000,
        maximumPrice: 580000,
        bedrooms: 3,
        bathrooms: 2,
        builtUpArea: 950,
        purpose: 'Own Stay & Investment',
        status: 'New Launch',
        description:
            'A vibrant modern transit-oriented development situated in the heart of Batu Kawan eco-hub. '
            'Walking distance to Design Village Outlet Mall, IKEA Batu Kawan, and 5 minutes drive to Batu Kawan Industrial Park (BKIP). '
            'Features resort-style sky amenities, Olympic-length infinity pool, and co-working lounge for tech professionals.',
        facilities: [
          'Infinity Lap Pool',
          'Co-working Lounge & High-speed WiFi',
          'Sky Gymnasium',
          'EV Charging Stations',
          'Children Splash Park',
          'BBQ Pavilion & Sky Dining',
          '24/7 Multi-tier Smart Security',
        ],
        nearbyAmenities: [
          'IKEA Batu Kawan (800m)',
          'Design Village Outlet Mall (500m)',
          'Batu Kawan Industrial Park / BKIP (3km)',
          'UOW Malaysia KDU Penang University (1.2km)',
          'Penang Second Bridge (4.5km)',
          'Columbia Asia Hospital Batu Kawan (2km)',
        ],
        imageUrls: [
          'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=800&q=80',
        ],
      ),
      ProjectModel(
        id: 'proj-002',
        ownerId: demoOwnerId,
        name: 'Gurney Premier Suites',
        developer: 'Eastern & Oriental Berhad',
        location: 'Gurney Drive, George Town',
        state: 'Penang',
        propertyType: 'Serviced Residence',
        startingPrice: 880000,
        maximumPrice: 1450000,
        bedrooms: 2,
        bathrooms: 2,
        builtUpArea: 1100,
        purpose: 'Investment',
        status: 'Under Construction',
        description:
            'Luxury seafront residences along the iconic Gurney promenade. '
            'Offering panoramic views of the Andaman Sea and direct linkage to Gurney Wharf public coastal park. '
            'Engineered for premium short-stay returns and affluent expatriate tenants.',
        facilities: [
          'Sea-facing Infinity Pool',
          'Concierge Service',
          'Private Yacht Booking Deck',
          'Rooftop Sky Bar & Lounge',
          'Steam & Sauna Wellness Suite',
        ],
        nearbyAmenities: [
          'Gurney Plaza & Gurney Paragon (600m)',
          'Gurney Bay Waterfront Park (Adjacent)',
          'Gleneagles Hospital Penang (1.5km)',
          'St. Christopher International School (2km)',
        ],
        imageUrls: [
          'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?auto=format&fit=crop&w=800&q=80',
        ],
      ),
      ProjectModel(
        id: 'proj-003',
        ownerId: demoOwnerId,
        name: 'Kulim Hi-Tech Green Residences',
        developer: 'BDB Land Sdn Bhd',
        location: 'Kulim Hi-Tech Park',
        state: 'Kedah',
        propertyType: 'Terrace House',
        startingPrice: 380000,
        maximumPrice: 460000,
        bedrooms: 4,
        bathrooms: 3,
        builtUpArea: 1800,
        purpose: 'Own Stay',
        status: 'New Launch',
        description:
            'Spacious 2-storey freehold landed homes catered for engineers, executives, and growing families working in Kulim Hi-Tech Park. '
            'Surrounded by 15 acres of lush landscaped linear parks, jogging trails, and guarded gated community.',
        facilities: [
          'Guarded Community with RFID Access',
          '15-acre Central Green Park',
          'Outdoor Calisthenics Gym',
          'Basketball & Futsal Court',
          'Children Adventure Playground',
        ],
        nearbyAmenities: [
          'Kulim Hi-Tech Park Zone 1-4 (2km)',
          'Hospital Kulim (3.5km)',
          'Politeknik Tuanku Sultanah Bahiyah (1.5km)',
          'Kulim Golf & Country Resort (4km)',
          'BKE Highway Interchange (5km)',
        ],
        imageUrls: [
          'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=800&q=80',
        ],
      ),
      ProjectModel(
        id: 'proj-004',
        ownerId: demoOwnerId,
        name: 'Bayu Sentral Residences',
        developer: 'IJM Land',
        location: 'Bayan Lepas',
        state: 'Penang',
        propertyType: 'Condominium',
        startingPrice: 520000,
        maximumPrice: 680000,
        bedrooms: 3,
        bathrooms: 2,
        builtUpArea: 1050,
        purpose: 'Own Stay & Investment',
        status: 'Under Construction',
        description:
            'Strategically situated right next to the Bayan Lepas Free Industrial Zone (FIZ) and Penang International Airport. '
            'Ideal for multinational semiconductor engineers, pilots, and airline executives.',
        facilities: [
          '50m Olympic Pool',
          'Badminton & Squash Courts',
          'Indoor Simulator Golf',
          'Multi-purpose Hall',
          'Sky Garden',
        ],
        nearbyAmenities: [
          'Bayan Lepas Free Industrial Zone (1.5km)',
          'Penang International Airport (2km)',
          'Queensbay Mall (6km)',
          'Pantai Hospital Penang (2.5km)',
        ],
        imageUrls: [
          'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?auto=format&fit=crop&w=800&q=80',
        ],
      ),
    ];
  }

  /// Generates 100 fictional buyer profiles for testing.
  /// Clearly labelled as DEMO DATA with isDemo: true.
  /// Never contains real personal data.
  static List<BuyerModel> generate100DemoBuyers() {
    final List<BuyerModel> buyers = [];

    final firstNames = [
      'Ahmad', 'Wei Lun', 'Kavitha', 'Muhammad', 'Siti', 'Chong', 'Priya', 'Hafiz',
      'Mei Ling', 'Rajesh', 'Nurul', 'Kah Seng', 'Farah', 'Suresh', 'Boon Keat',
      'Anis', 'Zulhilmi', 'Li Ying', 'Dinesh', 'Azlan', 'Siew Hong', 'Devi',
      'Khairul', 'Hui Min', 'Arun', 'Fazilah', 'Chee Meng', 'Thivya', 'Izzat',
      'Yoke San', 'Murali', 'Nabila', 'Kok Wah', 'Subashini', 'Shahril', 'Pei Shan',
      'Logeswaran', 'Zainab', 'Jason', 'Sarah', 'Kenneth', 'Amanda', 'Bernard',
      'Evelyn', 'Daniel', 'Rachel', 'Kelvin', 'Stephanie', 'Raymond', 'Melissa'
    ];

    final lastNames = [
      'Tan', 'Lee', 'Lim', 'Wong', 'Ng', 'Abdullah', 'Ismail', 'Ibrahim', 'Ramasamy',
      'Subramaniam', 'Krishnan', 'Ooi', 'Khor', 'Teoh', 'Cheah', 'Hashim', 'Yusof',
      'Goh', 'Chan', 'Yeoh', 'Low', 'Chua', 'Nadarajan', 'Mohd Nor', 'Zakaria',
      'Fernandez', 'Pillay', 'Mahmood', 'Chin', 'Loo', 'Leong', 'Sim', 'Khoo'
    ];

    final locations = [
      {'loc': 'Batu Kawan', 'state': 'Penang'},
      {'loc': 'Bayan Lepas', 'state': 'Penang'},
      {'loc': 'George Town', 'state': 'Penang'},
      {'loc': 'Tanjung Tokong', 'state': 'Penang'},
      {'loc': 'Butterworth', 'state': 'Penang'},
      {'loc': 'Kulim', 'state': 'Kedah'},
      {'loc': 'Sungai Petani', 'state': 'Kedah'},
      {'loc': 'Alor Setar', 'state': 'Kedah'},
      {'loc': 'Petaling Jaya', 'state': 'Selangor'},
      {'loc': 'Kuala Lumpur', 'state': 'Kuala Lumpur'},
      {'loc': 'Johor Bahru', 'state': 'Johor'},
    ];

    final propertyTypes = [
      'Condominium',
      'Terrace House',
      'Serviced Residence',
      'Apartment',
      'Semi-Detached',
      'Townhouse',
    ];

    final purposes = [
      'Own Stay',
      'Investment',
      'Own Stay & Investment',
    ];

    final timelines = [
      'Immediately',
      'Within 3 months',
      'Within 6 months',
      'Within 1 year',
      'Just exploring',
    ];

    final sources = [
      'Facebook Ads',
      'WhatsApp Enquiry',
      'Instagram',
      'Google Search',
      'TikTok',
      'Property Portal',
      'Referral',
    ];

    final statuses = [
      'New',
      'Contacted',
      'Interested',
      'Viewing Scheduled',
      'Negotiating',
    ];

    final audienceSegments = [
      'Young Tech Professionals',
      'First-time Homebuyers',
      'Property Investors',
      'Upgrading Families',
      'Out-of-State Relocators',
      'Rental Yield Seekers',
      'Retirees & Empty Nesters',
    ];

    final budgetTiers = [
      {'min': 300000.0, 'max': 450000.0},
      {'min': 400000.0, 'max': 550000.0},
      {'min': 450000.0, 'max': 600000.0},
      {'min': 500000.0, 'max': 700000.0},
      {'min': 650000.0, 'max': 900000.0},
      {'min': 800000.0, 'max': 1200000.0},
      {'min': 1000000.0, 'max': 1600000.0},
    ];

    for (int i = 1; i <= 100; i++) {
      final fName = firstNames[(i * 3 + 7) % firstNames.length];
      final lName = lastNames[(i * 5 + 11) % lastNames.length];
      final fullName = '$fName $lName';
      final locData = locations[(i * 2 + 1) % locations.length];
      final propType = propertyTypes[(i * 3) % propertyTypes.length];
      final purpose = purposes[(i * 2) % purposes.length];
      final timeline = timelines[(i * 4) % timelines.length];
      final source = sources[(i * 3 + 2) % sources.length];
      final status = statuses[(i * 2 + 1) % statuses.length];
      final segment = audienceSegments[(i * 2 + 3) % audienceSegments.length];
      final tier = budgetTiers[(i + (i ~/ 15)) % budgetTiers.length];

      buyers.add(
        BuyerModel(
          id: 'demo-buyer-${i.toString().padLeft(3, '0')}',
          ownerId: demoOwnerId,
          name: fullName,
          email: '${fName.toLowerCase()}.${lName.toLowerCase()}$i@demo.propmatch.ai',
          phone: '+60 1${(i % 9) + 1}-${1000000 + (i * 73931) % 8999999}',
          budgetMin: tier['min']!,
          budgetMax: tier['max']!,
          preferredLocation: locData['loc']!,
          preferredState: locData['state']!,
          propertyType: propType,
          purchasePurpose: purpose,
          buyingTimeline: timeline,
          leadSource: source,
          status: status,
          isDemo: true, // MANDATORY DEMO DATA FLAG
          audienceSegment: segment,
          notes: 'Fictional demo profile generated for testing and verification purposes.',
          createdAt: DateTime.now().subtract(Duration(days: (i * 3) % 45, hours: (i * 7) % 24)),
        ),
      );
    }

    return buyers;
  }

  /// Initial sample leads
  static List<LeadModel> getInitialLeads() {
    return [
      LeadModel(
        id: 'lead-001',
        ownerId: demoOwnerId,
        buyerId: 'demo-buyer-001',
        projectId: 'proj-001',
        buyerName: 'Ahmad Ismail (Demo)',
        projectName: 'EXSIM Demo Residence',
        status: 'Qualified',
        source: 'Facebook Ads',
        dealValue: 480000,
        notes: 'Pre-approved loan with Maybank. Highly keen on high-floor unit facing park.',
        isDemo: true,
      ),
      LeadModel(
        id: 'lead-002',
        ownerId: demoOwnerId,
        buyerId: 'demo-buyer-005',
        projectId: 'proj-001',
        buyerName: 'Wei Lun Tan (Demo)',
        projectName: 'EXSIM Demo Residence',
        status: 'Contacted',
        source: 'WhatsApp Enquiry',
        dealValue: 520000,
        notes: 'Senior engineer at Western Digital BKIP. Wants 3BR with 2 carparks.',
        isDemo: true,
      ),
      LeadModel(
        id: 'lead-003',
        ownerId: demoOwnerId,
        buyerId: 'demo-buyer-012',
        projectId: 'proj-002',
        buyerName: 'Kavitha Ramasamy (Demo)',
        projectName: 'Gurney Premier Suites',
        status: 'Negotiating',
        source: 'Google Search',
        dealValue: 920000,
        notes: 'Seeking passive rental yield. Requested gross rental return projections.',
        isDemo: true,
      ),
    ];
  }
}
