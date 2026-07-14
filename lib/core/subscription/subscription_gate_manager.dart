import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../app_colors.dart';

class SubscriptionGateManager {
  SubscriptionGateManager._();

  // ── Tier limit constants ─────────────────────────────────────────

  static const Map<String, int> _dailyChatMessages = {
    'free': 5,
    'pro': 35,
    'elite': 150,
  };

  static const Map<String, int> _dailyImageUploads = {
    'free': 0,
    'pro': 5,
    'elite': 10,
  };

  static const Map<String, int> _dailyNotesGenerated = {
    'free': 1,
    'pro': 8,
    'elite': 15,
  };

  static const Map<String, int> _dailyExamsGenerated = {
    'free': 1,
    'pro': 10,
    'elite': 25,
  };

  static const Map<String, int> _maxDecks = {
    'free': 1,
    'pro': 5,
    'elite': 15,
  };

  static const Map<String, int> _maxCardsPerDeck = {
    'free': 15,
    'pro': 50,
    'elite': 999999,
  };

  // ── Tier helpers ─────────────────────────────────────────────────

  static String normalizeTier(String raw) => raw.toLowerCase();
  static bool isFree(String tier) => normalizeTier(tier) == 'free';
  static bool isPro(String tier) => normalizeTier(tier) == 'pro';
  static bool isElite(String tier) => normalizeTier(tier) == 'elite';
  static String displayName(String tier) {
    final n = normalizeTier(tier);
    if (n == 'elite') return 'Elite';
    if (n == 'pro') return 'Pro';
    return 'Free';
  }

  static int limit(String tier, Map<String, int> table) {
    final n = normalizeTier(tier);
    if (table.containsKey(n)) return table[n]!;
    if (n == 'pending') return table['free']!;
    return table['free']!;
  }

  // ── Daily usage (Firestore sub-collection) ────────────────────────

  static String get _today => DateTime.now().toIso8601String().substring(0, 10);

  static DocumentReference _dailyRef(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('daily_usage').doc(_today);

  static Future<Map<String, int>> getDailyUsage(String uid) async {
    try {
      final snap = await _dailyRef(uid).get();
      if (!snap.exists) return {};
      final data = snap.data() as Map<String, dynamic>;
      return {
        'chatMessagesCount': (data['chatMessagesCount'] ?? 0) as int,
        'imageUploadsCount': (data['imageUploadsCount'] ?? 0) as int,
        'notesGeneratedCount': (data['notesGeneratedCount'] ?? 0) as int,
        'examsGeneratedCount': (data['examsGeneratedCount'] ?? 0) as int,
      };
    } catch (_) {
      return {};
    }
  }

  static Future<void> incrementDailyUsage(String uid, String field) async {
    try {
      await _dailyRef(uid).set({
        field: FieldValue.increment(1),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Public limit accessors ────────────────────────────────────────

  static int dailyChatMessageLimit(String tier) => limit(tier, _dailyChatMessages);
  static int dailyImageUploadLimit(String tier) => limit(tier, _dailyImageUploads);
  static int dailyNotesLimit(String tier) => limit(tier, _dailyNotesGenerated);
  static int dailyExamLimit(String tier) => limit(tier, _dailyExamsGenerated);
  static int maxDecks(String tier) => limit(tier, _maxDecks);
  static int maxCardsPerDeck(String tier) => limit(tier, _maxCardsPerDeck);

  // ── Per-feature checks ────────────────────────────────────────────

  static Future<bool> canChat(String uid, String tier) async {
    final max = limit(tier, _dailyChatMessages);
    if (max >= 999) return true;
    final usage = await getDailyUsage(uid);
    return (usage['chatMessagesCount'] ?? 0) < max;
  }

  static Future<bool> canUploadImage(String uid, String tier) async {
    final max = limit(tier, _dailyImageUploads);
    if (max >= 999) return true;
    if (max == 0) return false;
    final usage = await getDailyUsage(uid);
    return (usage['imageUploadsCount'] ?? 0) < max;
  }

  static Future<bool> canGenerateNotes(String uid, String tier) async {
    final max = limit(tier, _dailyNotesGenerated);
    if (max >= 999) return true;
    final usage = await getDailyUsage(uid);
    return (usage['notesGeneratedCount'] ?? 0) < max;
  }

  static Future<bool> canGenerateExam(String uid, String tier) async {
    final max = limit(tier, _dailyExamsGenerated);
    if (max >= 999) return true;
    final usage = await getDailyUsage(uid);
    return (usage['examsGeneratedCount'] ?? 0) < max;
  }

  static Future<bool> canCreateDeck(String uid, String tier, int currentDecks) async {
    final max = limit(tier, _maxDecks);
    return currentDecks < max;
  }

  static Future<bool> canAddCard(String uid, String tier, int currentCards) async {
    final max = limit(tier, _maxCardsPerDeck);
    return currentCards < max;
  }

  // ── Limit-reached dialog ─────────────────────────────────────────

  static Future<void> showLimitDialog(BuildContext context, String tier, String featureName, int maxAllowed) {
    final tierDisplay = displayName(tier);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.lock_clock_rounded, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 20),
            const Text(
              'Daily Limit Reached!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'You have used all $maxAllowed allowed slots for $featureName on your $tierDisplay plan today. Upgrade to unlock more power tomorrow!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.75), height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () { Navigator.pop(ctx); context.push('/subscription'); },
                child: const Text('Upgrade Plan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Maybe later', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ),
          ],
        ),
      ),
    );
  }

  // ── Image scan requires Pro+ dialog ──────────────────────────────

  static Future<void> showImageScanRequiresProDialog(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.image_outlined, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 20),
            const Text(
              'Image Scanning',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Image scanning requires Pro or Elite tier. Upgrade to send photos and get AI-powered visual solutions.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.75), height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () { Navigator.pop(ctx); context.push('/subscription'); },
                child: const Text('Upgrade Plan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Maybe later', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ),
          ],
        ),
      ),
    );
  }

  // ── Full exam gated (Free: only MCQs) ─────────────────────────────

  static Future<void> showFullExamGatedDialog(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 20),
            const Text(
              'Full Exam Locked',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              'Full Board Pattern Exams (Short + Long questions) are available on Pro & Elite plans. Quick MCQs are unlocked for Free tier.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.75), height: 1.5),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () { Navigator.pop(ctx); context.push('/subscription'); },
                child: const Text('Upgrade Plan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Maybe later', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ),
          ],
        ),
      ),
    );
  }
}
