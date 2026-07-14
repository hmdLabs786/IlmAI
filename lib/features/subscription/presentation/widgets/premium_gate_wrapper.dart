import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../../../../core/app_colors.dart';

class PremiumGateWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onUpgrade;
  final String title;
  final String description;

  const PremiumGateWrapper({
    super.key,
    required this.child,
    this.onUpgrade,
    this.title = 'Premium feature locked',
    this.description = 'Upgrade to Basic or Pro to unlock this action.',
  });

  @override
  Widget build(BuildContext context) {
    final subscriptionTier = context.watch<AuthProvider>().subscriptionTier;
    final isFree = subscriptionTier.toLowerCase() == 'free';

    if (!isFree) return child;

    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AbsorbPointer(child: child),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 22,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium_rounded, size: 48, color: AppColors.primaryBlue),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54, height: 1.4),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: onUpgrade ??
                              () => showPremiumUpsellDialog(context),
                          child: const Text('Upgrade Now'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> showPremiumUpsellDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Unlock Premium'),
          content: const Text(
            'This action is available on IlmAI Basic and Pro. Choose a plan to continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe later'),
            ),
          ],
        );
      },
    );
  }
}
