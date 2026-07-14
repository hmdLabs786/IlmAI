import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/auth_provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    final tier = auth.subscriptionTier;

    final plans = [
      _PlanData(
        title: 'Free Tier',
        price: 'PKR 0',
        period: 'Forever',
        accent: const Color(0xFF64748B),
        tier: 'Free',
        description: 'Dashboard access, basic AI and selected study tools.',
        features: [
          'AI Chat — limited queries',
          'Basic revision notes',
          'Dashboard analytics',
          'Board news feed',
        ],
      ),
      _PlanData(
        title: 'IlmAI Basic',
        price: 'PKR 200',
        period: '/month',
        accent: const Color(0xFF0F766E),
        tier: 'Basic',
        description: 'Expanded study tools and full document access.',
        features: [
          'Unlimited AI Chat sessions',
          'Generate revision notes',
          'Mock test papers',
          'Library — all PDFs',
          'Priority support',
        ],
      ),
      _PlanData(
        title: 'IlmAI Pro',
        price: 'PKR 450',
        period: '/month',
        accent: AppColors.primary,
        tier: 'Pro',
        description: 'Multimodal, audio and all premium tutoring modules.',
        features: [
          'Everything in Basic',
          'Audio teacher (voice AI)',
          'Past paper solutions',
          'Exam paper grading',
          'Leaderboard premium badge',
          'Early access to new features',
        ],
        badge: 'Most Popular',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 20, color: AppColors.onSurface),
                          onPressed: () => context.canPop() ? context.pop() : context.go('/menu'),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Subscription',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Current plan: $tier',
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Plan cards ──
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final plan = plans[i];
                  final isActive = tier == plan.tier;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: _PlanCard(
                      plan: plan,
                      isActive: isActive,
                      glowAnim: isActive ? _glowAnim : null,
                    ),
                  );
                },
                childCount: plans.length,
              ),
            ),

            // ── CTA button ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: ElevatedButton(
                  onPressed: () => context.go('/tier-selection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Change Plan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),

            // ── Profile context ──
            if (profile != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Profile: ${profile.promptSummary}',
                    style: const TextStyle(
                        color: AppColors.onSurfaceMuted, fontSize: 12),
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _PlanData {
  final String title;
  final String price;
  final String period;
  final Color accent;
  final String tier;
  final String description;
  final List<String> features;
  final String? badge;

  const _PlanData({
    required this.title,
    required this.price,
    required this.period,
    required this.accent,
    required this.tier,
    required this.description,
    required this.features,
    this.badge,
  });
}

class _PlanCard extends StatelessWidget {
  final _PlanData plan;
  final bool isActive;
  final Animation<double>? glowAnim;

  const _PlanCard({
    required this.plan,
    required this.isActive,
    this.glowAnim,
  });

  @override
  Widget build(BuildContext context) {
    final accent = plan.accent;

    return AnimatedBuilder(
      animation: glowAnim ?? const AlwaysStoppedAnimation(0),
      builder: (context, child) {
        final glowOpacity = glowAnim != null
            ? 0.08 + 0.10 * glowAnim!.value
            : 0.03;
        final glowBlur = glowAnim != null ? 20.0 + 12.0 * glowAnim!.value : 12.0;

        return AnimatedScale(
          scale: isActive ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isActive ? accent : AppColors.border,
                width: isActive ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: glowOpacity),
                  blurRadius: glowBlur,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: plan.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: plan.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          plan.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        if (plan.badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: plan.accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              plan.badge!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan.description,
                      style: const TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.price,
                    style: TextStyle(
                      color: plan.accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    plan.period,
                    style: const TextStyle(
                      color: AppColors.onSurfaceMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: AppColors.border.withValues(alpha: 0.6)),
          const SizedBox(height: 12),

          // ── Features ──
          ...plan.features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: plan.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Active badge ──
          if (isActive) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: plan.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: plan.accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Your Current Plan',
                    style: TextStyle(
                      color: plan.accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
