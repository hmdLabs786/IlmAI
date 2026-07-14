import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import '../../../../core/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/subscription/subscription_gate_manager.dart';
import '../../data/models/chapter_score.dart';
import '../../data/services/analytics_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _service = AnalyticsService();
  List<SubjectSummary>? _summaries;
  bool _loading = true;
  String _recommendation = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    setState(() => _loading = true);
    final summaries = await _service.getSubjectSummaries(uid);
    if (!mounted) return;

    final isPremium = context.read<AuthProvider>().subscriptionTier.toLowerCase() != 'free';
    String recommendation = '';
    if (isPremium && summaries.isNotEmpty) {
      recommendation = await _service.getRecommendation(summaries);
    }

    if (mounted) {
      setState(() {
        _summaries = summaries;
        _recommendation = recommendation;
        _loading = false;
      });
    }
  }

  Color _heatColor(double pct) {
    if (pct >= 80) return const Color(0xFF22C55E);
    if (pct >= 50) return const Color(0xFFEAB308);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final tier = context.watch<AuthProvider>().subscriptionTier;
    final isElite = SubscriptionGateManager.isElite(tier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _summaries == null || _summaries!.isEmpty
              ? _buildEmpty()
              : _buildContent(isElite),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 72, color: AppColors.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('No data yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
          const SizedBox(height: 8),
          const Text('Complete mock exams and quizzes\nto see your weakness heatmap.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.onSurfaceMuted)),
        ],
      ),
    );
  }

  Widget _buildContent(bool isElite) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isElite && _recommendation.isNotEmpty) _buildRecommendationBox(),
          if (isElite && _recommendation.isNotEmpty) const SizedBox(height: 20),
          ..._summaries!.map((s) => _buildSubjectCard(s, isElite)),
        ],
      ),
    );
  }

  Widget _buildRecommendationBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withValues(alpha: 0.08), AppColors.primary.withValues(alpha: 0.02)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text('AI Study Plan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.onSurface)),
            ],
          ),
          const SizedBox(height: 10),
          Text(_recommendation, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.onSurface)),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(SubjectSummary summary, bool isElite) {
    final color = _heatColor(summary.overallPercentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.menu_book_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.subject, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.onSurface)),
                      const SizedBox(height: 2),
                      Text('${summary.chapters.length} chapters · ${summary.overallPercentage.toStringAsFixed(0)}% overall',
                        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Text('${summary.overallPercentage.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 14)),
                ),
              ],
            ),
          ),
          if (isElite)
            _buildHeatmap(summary)
          else
            _buildBlurredHeatmap(summary),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeatmap(SubjectSummary summary) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        children: summary.chapters.map((ch) {
          final color = _heatColor(ch.percentage);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(ch.chapterName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                ),
                Expanded(
                  flex: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 20,
                      color: AppColors.border.withValues(alpha: 0.3),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (ch.percentage / 100).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text('${ch.percentage.toStringAsFixed(0)}%', textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBlurredHeatmap(SubjectSummary summary) {
    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AbsorbPointer(
            child: Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5))),
              ),
              child: Column(
                children: summary.chapters.map((ch) {
                  final color = _heatColor(ch.percentage);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(ch.chapterName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface))),
                        Expanded(flex: 4, child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(height: 20, color: AppColors.border.withValues(alpha: 0.3),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: (ch.percentage / 100).clamp(0.0, 1.0),
                              child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))),
                            ),
                          ),
                        )),
                        const SizedBox(width: 10),
                        SizedBox(width: 40, child: Text('${ch.percentage.toStringAsFixed(0)}%', textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.12),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, size: 40, color: AppColors.primary),
                    const SizedBox(height: 12),
                    const Text('Elite Premium Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text('Unlock your full Syllabus Weakness Heatmap to see exactly which board exam topics are pulling your score down.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.75), height: 1.4)),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          minimumSize: const Size.fromHeight(46),
                        ),
                        onPressed: () => context.push('/subscription'),
                        child: const Text('Upgrade to Elite', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
