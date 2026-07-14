import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../data/services/subscription_service.dart';
import '../../domain/subscription_tier.dart';

class TierSelectionScreen extends StatefulWidget {
  const TierSelectionScreen({super.key});

  @override
  State<TierSelectionScreen> createState() => _TierSelectionScreenState();
}

class _TierSelectionScreenState extends State<TierSelectionScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isProcessing = false;

  Future<void> _selectFreeTier(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user ?? FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isProcessing = true);
    try {
      await _subscriptionService.activateFreeTier(user.uid);
      await auth.setSubscriptionTier('Free');
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not activate free tier: $e')));
    } finally { if (mounted) setState(() => _isProcessing = false); }
  }

  Future<void> _triggerPremiumGateway(BuildContext context, SubscriptionTierInfo tier) async {
    final auth = context.read<AuthProvider>();
    final user = auth.user ?? FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _subscriptionService.logPremiumGatewayTrigger(uid: user.uid, tierId: tier.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trigger EasyPaisa/JazzCash Payment Gateway Workflow')));
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text('Choose your IlmAI access tier', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.onSurface)),
              const SizedBox(height: 10),
              Text('We have prepared a tailored experience for ${profile?.boardName ?? 'your board'} students.', style: const TextStyle(color: AppColors.onSurfaceMuted, height: 1.4)),
              const SizedBox(height: 28),
              ...SubscriptionTierInfo.all.map((tier) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _TierCard(
                  tier: tier,
                  isHighlighted: tier.id == 'Pro',
                  isProcessing: _isProcessing && tier.id == 'Free',
                  onFreeTap: () => _selectFreeTier(context),
                  onPremiumTap: () => _triggerPremiumGateway(context, tier),
                ),
              )),
              const SizedBox(height: 8),
              const Text('Premium tiers are currently wired as payment gateway stubs for EasyPaisa and JazzCash.', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final SubscriptionTierInfo tier;
  final bool isHighlighted;
  final bool isProcessing;
  final VoidCallback onFreeTap;
  final VoidCallback onPremiumTap;

  const _TierCard({required this.tier, required this.isHighlighted, required this.isProcessing, required this.onFreeTap, required this.onPremiumTap});

  @override
  Widget build(BuildContext context) {
    final gradient = tier.id == 'Pro' ? const [Color(0xFF111827), Color(0xFF1E3A8A)] : tier.id == 'Basic' ? const [Color(0xFF0F766E), Color(0xFF14B8A6)] : const [Colors.white, Colors.white];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(colors: gradient),
        border: Border.all(color: isHighlighted ? AppColors.primary : AppColors.border, width: isHighlighted ? 1.4 : 1),
        boxShadow: isHighlighted ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 10))] : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tier.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tier.id == 'Free' ? AppColors.onSurface : Colors.white)),
                      const SizedBox(height: 4),
                      Text(tier.subtitle, style: TextStyle(color: tier.id == 'Free' ? AppColors.onSurfaceMuted : Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: tier.id == 'Free' ? AppColors.primary.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                  child: Text(tier.monthlyPricePkr == 0 ? 'PKR 0' : 'PKR ${tier.monthlyPricePkr}/mo', style: TextStyle(fontWeight: FontWeight.bold, color: tier.id == 'Free' ? AppColors.primary : Colors.white)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...tier.features.map((feature) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(Icons.check_circle_rounded, size: 18, color: tier.id == 'Free' ? AppColors.primary : Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(feature, style: TextStyle(color: tier.id == 'Free' ? AppColors.onSurface : Colors.white))),
              ]),
            )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tier.id == 'Free' ? AppColors.primary : Colors.white,
                  foregroundColor: tier.id == 'Free' ? Colors.white : AppColors.onSurface,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: isProcessing ? null : (tier.id == 'Free' ? onFreeTap : onPremiumTap),
                child: isProcessing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : Text(tier.id == 'Free' ? 'Start Free' : 'Continue with ${tier.title}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
