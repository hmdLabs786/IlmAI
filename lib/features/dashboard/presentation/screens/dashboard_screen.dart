import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../onboarding/presentation/widgets/onboarding_tour.dart';
import '../../../onboarding/presentation/screens/permission_request_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _notesCount = 0;
  int _examsCount = 0;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _loadingStats = true;

  late AnimationController _entranceCtrl;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadStats();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstTimeUser());
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool('is_first_time_user') ?? true;
    if (!isFirst || !mounted) return;
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final permsShown = prefs.getBool('permissions_requested') ?? false;
    if (!permsShown) {
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: true,
          pageBuilder: (_, __, ___) => PermissionRequestScreen(
            onComplete: () => Navigator.of(context).pop(),
          ),
        ),
      );
      if (!mounted) return;
    }
    _showAppTour();
  }

  void _showAppTour() {
    final size = MediaQuery.of(context).size;
    final steps = [
      OnboardingTourStep(
        title: 'IlmAI Agent',
        description: 'Chat with your personalised AI tutor, tuned to your board syllabus, class, and learning level.',
        targetRect: (_) => Rect.fromCenter(center: Offset(size.width * 0.25, size.height * 0.42), width: 130, height: 130),
      ),
      OnboardingTourStep(
        title: 'Mock Papers',
        description: 'Generate AI-built board-pattern exam papers for any chapter — MCQs, short & long questions.',
        targetRect: (_) => Rect.fromCenter(center: Offset(size.width * 0.75, size.height * 0.42), width: 130, height: 130),
      ),
      OnboardingTourStep(
        title: 'News Feed',
        description: 'Stay updated with live BSEK and BIEK board announcements, results, and date sheets.',
        targetRect: (_) => Rect.fromCenter(center: Offset(size.width * 0.25, size.height * 0.54), width: 130, height: 130),
      ),
    ];
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => OnboardingTour(steps: steps, child: const SizedBox.shrink()),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn), child: child),
      ),
    );
  }

  Future<void> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final notes = await FirebaseFirestore.instance.collection('notes').where('userId', isEqualTo: uid).get();
      final exams = await FirebaseFirestore.instance.collection('exams').where('userId', isEqualTo: uid).get();

      final list = <Map<String, dynamic>>[];
      for (var d in notes.docs) {
        list.add({'type': 'Note', 'title': d.data()['title'] ?? 'Study Note', 'date': (d.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(), 'icon': Icons.auto_stories_rounded, 'color': const Color(0xFFD97706)});
      }
      for (var d in exams.docs) {
        list.add({'type': 'Exam', 'title': d.data()['title'] ?? 'Exam Paper', 'date': (d.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(), 'icon': Icons.assignment_turned_in_rounded, 'color': const Color(0xFF7C3AED)});
      }
      list.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      if (mounted) {
        setState(() {
          _notesCount = notes.docs.length;
          _examsCount = exams.docs.length;
          _recentActivities = list.take(4).toList();
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;
    if (auth.isLoading) return const Center(child: CircularProgressIndicator());

    final name = profile?.name.split(' ').first ?? 'Student';
    final tier = auth.subscriptionTier;
    final isFree = tier.toLowerCase() == 'free' || tier.toLowerCase() == 'pending';

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          children: [
            _FadeSlide(ctrl: _entranceCtrl, delay: 0.0, child: _WelcomeCard(name: name, profile: profile)),
            const SizedBox(height: 20),
            _FadeSlide(ctrl: _entranceCtrl, delay: 0.1, child: _QuickStats(notesCount: _notesCount, examsCount: _examsCount, loading: _loadingStats)),
            const SizedBox(height: 20),
            _FadeSlide(ctrl: _entranceCtrl, delay: 0.18, child: _ProgressCard()),
            const SizedBox(height: 20),
            _FadeSlide(ctrl: _entranceCtrl, delay: 0.24, child: _QuickActions(tier: tier)),
            if (_recentActivities.isNotEmpty) ...[
              const SizedBox(height: 24),
              _FadeSlide(
                ctrl: _entranceCtrl, delay: 0.34,
                child: Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context))),
              ),
              const SizedBox(height: 14),
              _FadeSlide(ctrl: _entranceCtrl, delay: 0.40, child: _ActivityList(activities: _recentActivities)),
            ],
            const SizedBox(height: 24),
            _FadeSlide(ctrl: _entranceCtrl, delay: 0.46, child: _UpgradeBanner(isFree: isFree)),
          ],
        ),
      ),
    );
  }
}

class _FadeSlide extends StatelessWidget {
  final AnimationController ctrl;
  final double delay;
  final Widget child;
  const _FadeSlide({required this.ctrl, required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    final end = (delay + 0.35).clamp(0.0, 1.0);
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: ctrl, curve: Interval(delay, end, curve: Curves.easeIn))),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(CurvedAnimation(parent: ctrl, curve: Interval(delay, end, curve: Curves.easeOutCubic))),
        child: child,
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final String name;
  final dynamic profile;
  const _WelcomeCard({required this.name, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF0F2460)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.22), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Salaam,', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _badge(Icons.school_rounded, profile?.boardName ?? 'Board'),
              _badge(Icons.grade_rounded, 'Class ${profile?.studentClass ?? ''}'),
              _badge(Icons.trending_up_rounded, profile?.levelName ?? 'Level'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 13),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final int notesCount;
  final int examsCount;
  final bool loading;
  const _QuickStats({required this.notesCount, required this.examsCount, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatCard(label: 'Saved Notes', value: loading ? '-' : '$notesCount', icon: Icons.auto_stories_rounded, color: const Color(0xFFD97706))),
        const SizedBox(width: 14),
        Expanded(child: _StatCard(label: 'Mock Exams', value: loading ? '-' : '$examsCount', icon: Icons.assignment_turned_in_rounded, color: const Color(0xFF7C3AED))),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context), borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.onSurfaceOf(context))),
                Text(label, style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMutedOf(context), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weekly Progress', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.onSurfaceOf(context))),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 0.65),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => Text('${(v * 100).toInt()}%', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 0.65),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: v, minHeight: 9, backgroundColor: AppColors.borderOf(context), valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)),
            ),
          ),
          const SizedBox(height: 12),
          Text("Mashallah! You've been consistent this week. Keep it up!", style: TextStyle(color: AppColors.onSurfaceMutedOf(context), fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final String tier;
  const _QuickActions({required this.tier});

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionData(Icons.chat_rounded, 'AI Chat', () => context.go('/chat'), AppColors.primary),
      _ActionData(Icons.auto_stories_rounded, 'Notes', () => context.go('/notes'), const Color(0xFFD97706)),
      _ActionData(Icons.assignment_rounded, 'Exams', () => context.go('/exams'), const Color(0xFF7C3AED)),
      _ActionData(Icons.library_books_rounded, 'Library', () => context.go('/library'), const Color(0xFF059669)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Access', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context))),
        const SizedBox(height: 12),
        Row(
          children: actions.map((a) => Expanded(child: _ActionButton(data: a))).toList(),
        ),
      ],
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  _ActionData(this.icon, this.label, this.onTap, this.color);
}

class _ActionButton extends StatelessWidget {
  final _ActionData data;
  const _ActionButton({required this.data});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAltOf(context), borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: data.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(data.icon, color: data.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(data.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onSurfaceOf(context))),
          ],
        ),
      ),
    );
  }
}

class _UpgradeBanner extends StatelessWidget {
  final bool isFree;
  const _UpgradeBanner({required this.isFree});

  @override
  Widget build(BuildContext context) {
    if (!isFree) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => context.push('/subscription'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.08), const Color(0xFF0F2460).withValues(alpha: 0.04)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unlock Pro Features', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context))),
                  SizedBox(height: 2),
                  Text('Audio teacher, Snap & Solve, paper grading & more', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMutedOf(context))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  final List<Map<String, dynamic>> activities;
  const _ActivityList({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: activities.length,
        separatorBuilder: (_, __) => Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.borderOf(context)),
        itemBuilder: (_, i) {
          final a = activities[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: (a['color'] as Color).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
            ),
            title: Text(a['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.onSurfaceOf(context))),
            subtitle: Text("${a['type']} \u00b7 ${DateFormat('MMM d, h:mm a').format(a['date'] as DateTime)}", style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMutedOf(context))),
            trailing: Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.onSurfaceMutedOf(context)),
            onTap: () => context.go(a['type'] == 'Note' ? '/notes' : '/exams'),
          );
        },
      ),
    );
  }
}
