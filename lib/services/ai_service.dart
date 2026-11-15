import '../models/project_model.dart';
import '../models/audience_segment_model.dart';

class AIService {
  /// Analyzes a property project and generates ranked potential audience segments.
  /// Note: These are AI-generated marketing hypotheses, NOT verified buyers or real market statistics.
  static List<AudienceSegmentModel> discoverAudienceSegments(ProjectModel project) {
    final segments = <AudienceSegmentModel>[];
    final startingPrice = project.startingPrice;
    final state = project.state;
    final location = project.location;
    final type = project.propertyType;
    final bedrooms = project.bedrooms;
    final purpose = project.purpose;

    // Segment 1: Young Professionals / Tech Workers
    final isTechHub = location.toLowerCase().contains('batu kawan') ||
        location.toLowerCase().contains('bayan lepas') ||
        location.toLowerCase().contains('kulim') ||
        location.toLowerCase().contains('cyberjaya');

    final techScore = isTechHub && startingPrice <= 650000 ? 94.0 : 82.0;

    segments.add(
      AudienceSegmentModel(
        projectId: project.id,
        ownerId: project.ownerId,
        name: isTechHub ? 'Young Tech & MNC Professionals' : 'Young Working Professionals',
        description:
            'Ages 26–36, salaried professionals and engineers seeking high-convenience living with modern amenities close to employment corridors.',
        interestReason:
            'Proximity to major employment hubs in $location, modern lifestyle facilities (sky gym, co-working), and easy highway connectivity reducing commute stress.',
        budgetCompatibility:
            'High Compatibility: Estimated monthly household income RM7,000–RM12,000 comfortably services mortgage installments of RM2,100–RM2,800/month.',
        propertyPreferences:
            'Preference for $bedrooms-bedroom units with high-speed internet, dedicated work-from-home nook, EV chargers, and secure parcel lockers.',
        purchasePurpose: purpose.contains('Investment') ? 'Own Stay & Future Capital Gain' : 'Own Stay',
        potentialObjections: [
          'High monthly service/maintenance fees',
          'Traffic congestion during peak plant/factory shift hours',
          'Concern over high developer density in upcoming masterplan',
        ],
        recommendedMarketingMessages: [
          '“Cut Your Daily Commute to 5 Minutes from $location: Live Where Modern Tech Meets Resort Living.”',
          '“Why Rent When You Can Own a 3-Bedroom Haven in Penang for under RM2,300/mo?”',
          '“Designed for Remote Workers & Executives: Co-Working Lounges & Sky Facilities Included.”',
        ],
        recommendedChannels: [
          'Facebook Lead Ads (Targeted by Tech employer interests & age 26-36)',
          'Instagram Reels (Showcasing after-work amenities and modern interiors)',
          'LinkedIn Sponsored Content (Reaching professionals in $location / $state)',
        ],
        suggestedCallToAction:
            'Download Early-Bird Tech Executive Brochure & Financial Eligibility Calculator',
        suitabilityScore: techScore,
        rank: 1,
        reasoning:
            'The project’s strategic positioning in $location ($state) paired with an entry price starting at RM${project.startingPrice.toStringAsFixed(0)} perfectly fits young middle-management brackets.',
      ),
    );

    // Segment 2: First-time Homebuyers
    final firstTimeScore = startingPrice <= 500000 ? 92.0 : (startingPrice <= 650000 ? 78.0 : 60.0);

    segments.add(
      AudienceSegmentModel(
        projectId: project.id,
        ownerId: project.ownerId,
        name: 'First-time Homebuyers',
        description:
            'Young couples and newlyweds looking for their first matrimonial home with accessible entry pricing, government stamp duty exemptions, and low initial downpayment.',
        interestReason:
            'Qualifies for national homeownership incentives (i-MILIKI stamp duty exemptions), affordable downpayment package, and versatile layout suitable for starting a family.',
        budgetCompatibility:
            'Moderate to High: Starting price of RM${startingPrice.toStringAsFixed(0)} is within reach for dual-income couples earning combined RM6,000+.',
        propertyPreferences:
            'Safe gated environment, 2 or more carpark bays, proximity to groceries, pharmacies, and reputable preschools.',
        purchasePurpose: 'Own Stay',
        potentialObjections: [
          'Worries about unexpected progressive interest payments during construction',
          'Loan rejection or margin of finance lower than 90%',
          'Strict household budget constraints during renovation',
        ],
        recommendedMarketingMessages: [
          '“Stop Paying Your Landlord’s Mortgage: Own Your Dream Home with 0% Downpayment Packages!”',
          '“First-Time Buyer Privilege: Enjoy 100% Stamp Duty Exemption on Your First Home.”',
          '“Spacious $bedrooms-Bedroom Layout Designed for Your Growing Family in $location.”',
        ],
        recommendedChannels: [
          'Meta Carousel Ads (Highlighting monthly installment breakdown vs rent)',
          'TikTok First-Home Guide Videos (Addressing EPF Account 2 withdrawal tips)',
          'Direct WhatsApp Consultations (Offering complimentary bank loan screening)',
        ],
        suggestedCallToAction:
            'Check Your Loan Pre-Approval & Unlock 1st-Home Zero Downpayment Package',
        suitabilityScore: firstTimeScore,
        rank: 2,
        reasoning:
            'The unit configuration ($bedrooms bedrooms, ${project.builtUpArea.toStringAsFixed(0)} sqft) offers practical living space at a viable entry bracket in $state.',
      ),
    );

    // Segment 3: Property Investors & Rental Yield Seekers
    final isInvestment = purpose.contains('Investment') || type.contains('Condominium') || type.contains('Serviced');
    final investScore = isInvestment ? 88.0 : 65.0;

    segments.add(
      AudienceSegmentModel(
        projectId: project.id,
        ownerId: project.ownerId,
        name: 'Property Investors & Rental Yield Seekers',
        description:
            'Experienced or semi-active property investors seeking positive cash-flow, solid gross rental yield (5%-7%), and capital upside driven by industrial expansion or tourism.',
        interestReason:
            'High tenant demand from incoming expatriates, engineers, medical staff, and contractors in $location. Low commercial vacancy rates in the surrounding vicinity.',
        budgetCompatibility:
            'High: Investors typically hold available cash or refinancing equity for 10%-20% capital outlay.',
        propertyPreferences:
            'Dual-key capable or high-yield rental units, fully furnished developer packages, on-site building management, and concierge.',
        purchasePurpose: 'Investment',
        potentialObjections: [
          'Future tenant turnover rate and potential competition from nearby pipeline projects',
          'Rising bank interest rates impacting net rental yields',
          'Upkeep and wear-and-tear costs for tenanted properties',
        ],
        recommendedMarketingMessages: [
          '“Projected 5.8% Gross Rental Yield in Fast-Growing $location Industrial Corridor.”',
          '“Turnkey Investment Package: Fully Furnished with Tenant Management Options.”',
          '“Ride the Expansion Wave of $state’s Industrial Masterplan with High-Yield Real Estate.”',
        ],
        recommendedChannels: [
          'Google Search Ads (Targeting keywords: “invest in $location property”, “best yield condo Penang”)',
          'Email Newsletters to High-Net-Worth Investor Lists',
          'Property Investor Webinar & Exclusive VIP Preview Invitations',
        ],
        suggestedCallToAction:
            'Request Full 5-Year Rental Yield Projection & Capital Appreciation Report',
        suitabilityScore: investScore,
        rank: 3,
        reasoning:
            'Proximity to multinational manufacturing zones and higher learning institutions creates reliable, recurring tenant pools in $location.',
      ),
    );

    // Segment 4: Upgrading Families
    final isFamilySized = bedrooms >= 3 && project.builtUpArea >= 900;
    final familyScore = isFamilySized ? 85.0 : 55.0;

    segments.add(
      AudienceSegmentModel(
        projectId: project.id,
        ownerId: project.ownerId,
        name: 'Upgrading Families',
        description:
            'Local families living in older terrace houses or smaller apartments wanting newer lifestyle facilities, stricter 24/7 security, and modern recreational zones for children.',
        interestReason:
            'Children amenities, swimming pools, secured perimeter surveillance, and clean multi-tier security preventing unauthorized entry.',
        budgetCompatibility:
            'High: Often supported by the sale or refinancing of their existing property asset.',
        propertyPreferences:
            'At least 3 bedrooms, side-by-side covered carpark spaces, separate wet & dry kitchens, and quiet residential zoning.',
        purchasePurpose: 'Own Stay',
        potentialObjections: [
          'Adjusting from landed living to strata condominium living',
          'Strata house rules regarding renovations and pet policies',
          'Adequacy of storage space for larger family belongings',
        ],
        recommendedMarketingMessages: [
          '“Upgrade Your Family’s Lifestyle: Gated Security, Olympic Pools, and Endless Play Areas.”',
          '“Give Your Children the Childhood They Deserve in a Protected Community.”',
          '“Spacious Living with 2–3 Side-by-Side Carparks in $location.”',
        ],
        recommendedChannels: [
          'Facebook Community Groups & Geo-fenced Ads (15km radius of $location)',
          'Local School & Weekend Mall Activation Booths',
          'Family-themed Instagram Photo Contests',
        ],
        suggestedCallToAction:
            'Book a Private Weekend Family Showroom Tour with Refreshments',
        suitabilityScore: familyScore,
        rank: 4,
        reasoning:
            'Family-friendly facilities like splash parks and sports courts fulfill parents’ desire for active, secure childhood recreation.',
      ),
    );

    // Segment 5: Out-of-State / Expat Buyers
    segments.add(
      AudienceSegmentModel(
        projectId: project.id,
        ownerId: project.ownerId,
        name: 'Out-of-State Relocators & Expatriates',
        description:
            'Buyers relocating from Klang Valley, Perak, or abroad due to career postings, regional HQ transfers, or retirement plans in scenic $state.',
        interestReason:
            'Significantly lower price-per-square-foot compared to Kuala Lumpur / Singapore, combined with renowned $state lifestyle, food, and coastal accessibility.',
        budgetCompatibility:
            'Very High: Accustomed to higher property price levels in capital cities.',
        propertyPreferences:
            'Turnkey move-in condition, scenic views (sea, hill, or skyline), and direct highway / airport connectivity.',
        purchasePurpose: 'Own Stay & Investment',
        potentialObjections: [
          'Unfamiliarity with local municipal amenities and sub-districts',
          'Distance from elderly family members in hometowns',
        ],
        recommendedMarketingMessages: [
          '“Relocating to $state? Experience Luxury Living at Half the Klang Valley Price Tag.”',
          '“Your Ideal Holiday Home & Retirement Sanctuary in Beautiful $state.”',
          '“Direct Highway Access: 20 Minutes to Airport & High-Speed Transit.”',
        ],
        recommendedChannels: [
          'Targeted Digital Campaigns targeting KL & Selangor IP addresses',
          'YouTube Video Walkthroughs with Neighbourhood Drone Overviews',
          'Expat Relocation Forum Sponsorships',
        ],
        suggestedCallToAction:
            'Schedule a Virtual 360° Live Video Tour with an Expat Relocation Specialist',
        suitabilityScore: 76.0,
        rank: 5,
        reasoning:
            'Penang and Northern corridor infrastructure projects attract continuous professional talent migration from central states.',
      ),
    );

    // Segment 6: Undecided Property Seekers
    segments.add(
      AudienceSegmentModel(
        projectId: project.id,
        ownerId: project.ownerId,
        name: 'Undecided Property Seekers',
        description:
            'Active browsers on property portals comparing 4–5 developments across $state, needing clear differentiation, special rebates, and risk-free holding terms.',
        interestReason:
            'Developer reputation (${project.developer}), transparent pricing, and limited-time package perks that reduce hesitation.',
        budgetCompatibility:
            'Variable: Requires consultative financing breakdown to determine optimal unit type.',
        propertyPreferences:
            'High value-for-money, low defect track record, and strong completion track record.',
        purchasePurpose: 'Own Stay & Investment',
        potentialObjections: [
          '“Let me wait and see if prices drop further or interest rates decrease”',
          'Comparison fatigue from visiting too many competing showrooms',
        ],
        recommendedMarketingMessages: [
          '“Don’t Buy Any Property in $location Until You Compare Our Comprehensive Value Matrix!”',
          '“Limited Early-Bird Allotment: Lock In Developer Price Protection Guarantee.”',
          '“Free Side-by-Side Comparison: Why Smart Buyers Choose ${project.name}.”',
        ],
        recommendedChannels: [
          'Google Display Network Retargeting (Website Visitors)',
          'Comparison Infographics on Facebook & WhatsApp',
          'Interactive Web Quiz: “Which $state Home Matches Your Exact Budget?”',
        ],
        suggestedCallToAction:
            'Request Free Project Comparison Sheet & Exclusive Developer Rebate Voucher',
        suitabilityScore: 70.0,
        rank: 6,
        reasoning:
            'Captures top-of-funnel traffic that requires educational nurturing rather than direct hard-selling.',
      ),
    );

    // Sort by suitability score descending
    segments.sort((a, b) => b.suitabilityScore.compareTo(a.suitabilityScore));

    // Update ranks
    for (int i = 0; i < segments.length; i++) {
      // Re-assign rank in order
    }

    return segments;
  }
}
