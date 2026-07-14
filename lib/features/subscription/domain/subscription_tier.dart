class SubscriptionTierInfo {
  final String id;
  final String title;
  final int monthlyPricePkr;
  final String subtitle;
  final List<String> features;
  final bool isPremium;

  const SubscriptionTierInfo({
    required this.id,
    required this.title,
    required this.monthlyPricePkr,
    required this.subtitle,
    required this.features,
    required this.isPremium,
  });

  static const free = SubscriptionTierInfo(
    id: 'Free',
    title: 'Free Tier',
    monthlyPricePkr: 0,
    subtitle: 'Core learning tools for every student',
    features: [
      'Access to dashboard and basic AI tutor',
      'Limited notes and paper previews',
      'Offline-ready document downloads',
    ],
    isPremium: false,
  );

  static const basic = SubscriptionTierInfo(
    id: 'Basic',
    title: 'IlmAI Basic',
    monthlyPricePkr: 200,
    subtitle: 'Best for consistent board preparation',
    features: [
      'Smart revision flows',
      'Expanded document access',
      'Targeted board news alerts',
    ],
    isPremium: true,
  );

  static const pro = SubscriptionTierInfo(
    id: 'Pro',
    title: 'IlmAI Pro',
    monthlyPricePkr: 450,
    subtitle: 'Multimodal tutoring with audio support',
    features: [
      'Snap & Solve and Board Paper Checker',
      'Premium contextual RAG answers',
      'AI Audio Teacher summaries',
    ],
    isPremium: true,
  );

  static const all = [free, basic, pro];
}
