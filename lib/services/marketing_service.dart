import '../models/project_model.dart';
import '../models/audience_segment_model.dart';

class MarketingContentResult {
  final String headline;
  final String facebookPost;
  final String instagramCaption;
  final String tikTokScript;
  final String whatsAppMessage;
  final String campaignConcept;
  final String callToAction;

  MarketingContentResult({
    required this.headline,
    required this.facebookPost,
    required this.instagramCaption,
    required this.tikTokScript,
    required this.whatsAppMessage,
    required this.campaignConcept,
    required this.callToAction,
  });
}

class MarketingService {
  /// Generates tailored marketing collateral for a given project and target audience segment.
  static MarketingContentResult generateContent({
    required ProjectModel project,
    AudienceSegmentModel? audience,
  }) {
    final audienceName = audience?.name ?? 'High-Intent Property Seekers';
    final location = project.location;
    final state = project.state;
    final startingPrice = 'RM${project.startingPrice.toStringAsFixed(0)}';
    final bedrooms = project.bedrooms;
    final developer = project.developer;
    final projectName = project.name;

    // Headlines
    final headline = '✨ Luxury Living in $location from $startingPrice | Designed for $audienceName';

    // Facebook Post
    final facebookPost = '''
🏡 STOP RENTING. START OWNING IN ${location.toUpperCase()}, ${state.toUpperCase()}!

Introducing $projectName by $developer — tailored specifically for $audienceName!

💎 Why You’ll Love It:
✅ Starting from only $startingPrice (Monthly installment ~RM2,200/mo*)
✅ $bedrooms Bedrooms & modern functional layout (${project.builtUpArea.toStringAsFixed(0)} sqft)
✅ Full resort facilities: Infinity Pool, Sky Gym, Co-working Hub
✅ Prime hotspot: Minutes to international schools, commercial malls & highway links

🎁 Exclusive Early-Bird Package Available This Week:
• 0% Downpayment Option Available*
• Free SPA & Legal Fees Subsidies
• Smart Home Digital Lock Voucher

👉 Don’t miss your choice unit before official public launch!
Click the link below to download the official floor plan & view actual showroom units! 
👇👇👇
[Link: Download Floor Plan & Price List]

#MalaysianProperty #PenangProperty #$projectName #$location #HomeOwnership #PropertyInvestment
''';

    // Instagram Caption
    final instagramCaption = '''
Finding your dream home in $location just got easier. ✨

Say hello to $projectName:
🛋️ $bedrooms Bedrooms | ${project.builtUpArea.toStringAsFixed(0)} sqft of pure comfort
🏊 Resort-grade sky amenities overlooking $location skyline
💰 From $startingPrice | Designed for $audienceName

Tag someone who needs to see this! 👇
DM us "FLOORPLAN" or tap the link in bio to get an instant brochure.

.
.
#PenangLiving #$location #MalaysianHomes #PropTech #DreamHome #InteriorInspo
''';

    // TikTok Video Concept & Hook
    final tikTokScript = '''
🎬 TIKTOK HOOK & SCRIPT (30s Short):
--------------------------------------------------
[00:00 - 00:03] HOOK:
(Host pointing at camera in modern showroom)
"Are you still paying RM2,000 monthly rent in $location without building equity? Watch this!"

[00:04 - 00:12] SHOWCASING:
(Fast b-roll cuts: Walking into the master bedroom, showing the infinity pool, drone shot of $location)
"This brand-new development just opened in $location starting at only $startingPrice. Look at this Olympic-size pool and co-working lounge!"

[00:13 - 00:22] VALUE PROPOSITION:
"If you are a $audienceName, you can qualify for zero downpayment packages with monthly installments as low as RM2,200."

[00:23 - 00:30] CALL TO ACTION:
"Limited units with sea/city view are left! Comment 'EXP' below or click the link in my bio to get the layout booklet right now!"
''';

    // WhatsApp Message
    final whatsAppMessage = '''
Hi [Buyer Name], hope you are having a wonderful week! 😊

I noticed you were looking for a $bedrooms-bedroom property around the $location area. 

I wanted to share an exclusive early-bird update on a new development — *$projectName* by $developer.

🌟 Quick Highlights:
• Starting from *$startingPrice*
• Practical *$bedrooms-bedroom* layout (${project.builtUpArea.toStringAsFixed(0)} sqft)
• Ideal for *${project.purpose}*
• Walking distance to key lifestyle conveniences

We are currently hosting private VIP showroom previews this weekend. Would you be free this Saturday or Sunday at 2:00 PM to view the show units?

I can also send over the PDF floor plan right here if you'd like to take a look first! 👍
''';

    // Campaign Concept
    final campaignConcept = '''
📌 CAMPAIGN: "Own Your Future at $projectName"
🎯 TARGET AUDIENCE: $audienceName
📍 CHANNELS: Meta Ads (FB/IG) + TikTok Spark Ads + WhatsApp Follow-up Drip
💡 CORE ANGLE: Overcoming affordability hesitation with structured transparent financing and lifestyle benefits.
🎁 LEAD HOOK: Download "The Complete First-Timer & Investor Guide to $location Real Estate (PDF)" with exclusive developer rebate token.
''';

    final callToAction = 'Download Free Floor Plan & Schedule Private VIP Showroom Preview';

    return MarketingContentResult(
      headline: headline,
      facebookPost: facebookPost,
      instagramCaption: instagramCaption,
      tikTokScript: tikTokScript,
      whatsAppMessage: whatsAppMessage,
      campaignConcept: campaignConcept,
      callToAction: callToAction,
    );
  }
}
