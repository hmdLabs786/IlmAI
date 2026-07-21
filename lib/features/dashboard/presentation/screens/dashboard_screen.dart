import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/student_profile.dart';
import '../../../onboarding/presentation/widgets/onboarding_tour.dart';
import '../../../onboarding/presentation/screens/permission_request_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _notesCount = 0;
  int _examsCount = 0;
  int _flashcardCount = 0;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _loadingStats = true;

  static const _studyTips = [
    'Review one chapter daily to stay ahead',
    'Practice past papers for exam confidence',
    'Teach someone else to solidify concepts',
    'Take short breaks every 25 minutes',
    'Summarise each topic in your own words',
    'Use spaced repetition for long-term memory',
    'Solve MCQs daily to sharpen speed',
    'Create mind maps for complex topics',
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFirstTimeUser());
  }

  Future<void> _checkFirstTimeUser() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirst = prefs.getBool('is_first_launch') ?? true;
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
      final flashcards = await FirebaseFirestore.instance.collection('flashcard_decks').where('userId', isEqualTo: uid).get();

      final list = <Map<String, dynamic>>[];
      for (var d in notes.docs) {
        list.add({'type': 'Note', 'title': d.data()['title'] ?? 'Study Note', 'date': (d.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(), 'icon': Icons.auto_stories_rounded, 'color': const Color(0xFFD97706), 'route': '/notes'});
      }
      for (var d in exams.docs) {
        list.add({'type': 'Exam', 'title': d.data()['title'] ?? 'Exam Paper', 'date': (d.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(), 'icon': Icons.assignment_turned_in_rounded, 'color': const Color(0xFF7C3AED), 'route': '/exams'});
      }
      list.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      if (mounted) {
        setState(() {
          _notesCount = notes.docs.length;
          _examsCount = exams.docs.length;
          _flashcardCount = flashcards.docs.length;
          _recentActivities = list.take(5).toList();
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
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomPad + 16),
        children: [
          _buildHero(name, profile),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildStatsRow(),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSectionHeader('Quick Access', Icons.touch_app_rounded),
          ),
          const SizedBox(height: 12),
          _buildQuickActions(tier),
          const SizedBox(height: 24),
          _buildBoardUpdates(),
          if (_recentActivities.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSectionHeader('Recent Activity', Icons.history_rounded),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildActivityTimeline(),
            ),
          ],
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildUpgradeBanner(isFree),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
      ],
    );
  }

  Widget _buildHero(String name, StudentProfile? profile) {
    final today = DateFormat('EEEE, MMM d').format(DateTime.now());
    final tip = _studyTips[DateTime.now().day % _studyTips.length];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, Color(0xFF0F2460), Color(0xFF1E3A8A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
                  onPressed: () => context.push('/menu'),
                ),
              ),
              const Spacer(),
              Stack(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                      onPressed: () => context.push('/notifications'),
                    ),
                  ),
                  Positioned(
                    right: 8, top: 8,
                    child: Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(today, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome, size: 10, color: Colors.amber.shade200),
                              const SizedBox(width: 4),
                              Text('IlmAI', style: TextStyle(color: Colors.amber.shade200, fontSize: 10, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('Salaam, $name \u{1F44B}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2.5),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _heroBadge(Icons.school_rounded, profile?.boardName ?? 'Board'),
              _heroBadge(Icons.grade_rounded, 'Class ${profile?.studentClass ?? '-'}'),
              _heroBadge(Icons.trending_up_rounded, profile?.levelName ?? 'Level'),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: Colors.amber.shade200, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Tip: $tip',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 12),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _StatCard(
          icon: Icons.auto_stories_rounded,
          label: 'Notes',
          value: _loadingStats ? '-' : '$_notesCount',
          color: const Color(0xFFD97706),
          onTap: () => context.go('/notes'),
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          icon: Icons.assignment_turned_in_rounded,
          label: 'Exams',
          value: _loadingStats ? '-' : '$_examsCount',
          color: const Color(0xFF7C3AED),
          onTap: () => context.go('/exams'),
        )),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(
          icon: Icons.style_rounded,
          label: 'Cards',
          value: _loadingStats ? '-' : '$_flashcardCount',
          color: const Color(0xFF059669),
          onTap: () => context.go('/flashcards'),
        )),
      ],
    );
  }

  Widget _buildQuickActions(String tier) {
    final actions = [
      _ActionData(Icons.chat_rounded, 'AI Chat', () => context.go('/chat'), AppColors.primary),
      _ActionData(Icons.auto_stories_rounded, 'Notes', () => context.go('/notes'), const Color(0xFFD97706)),
      _ActionData(Icons.assignment_rounded, 'Exams', () => context.go('/exams'), const Color(0xFF7C3AED)),
      _ActionData(Icons.library_books_rounded, 'Library', () => context.go('/library'), const Color(0xFF059669)),
      _ActionData(Icons.style_rounded, 'Flashcards', () => context.go('/flashcards'), const Color(0xFFE11D48)),
      _ActionData(Icons.feed_rounded, 'News', () => context.go('/news-feed'), const Color(0xFF0891B2)),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final a = actions[i];
          return GestureDetector(
            onTap: a.onTap,
            child: Container(
              width: 78,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAltOf(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.borderOf(context)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: a.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(a.icon, color: a.color, size: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(a.label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onSurface), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoardUpdates() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSectionHeader('Board Updates', Icons.campaign_rounded),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('board_news')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text('No board updates yet',
                    style: TextStyle(color: AppColors.onSurfaceMutedOf(context), fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                );
              }
              final newsList = snapshot.data!.docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                final id = d.id;
                final title = data['title']?.toString() ?? '';
                final originalUrl = data['originalUrl']?.toString() ?? '';
                final source = data['source']?.toString() ?? '';
                final category = data['category']?.toString() ?? 'General';
                final imageUrl = data['imageUrl']?.toString() ?? '';
                final timestamp = data['timestamp'] as Timestamp?;
                return _BoardNewsItem(id: id, title: title, originalUrl: originalUrl, source: source, category: category, imageUrl: imageUrl, timestamp: timestamp);
              }).toList();
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: newsList.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) {
                  final n = newsList[i];
                  return GestureDetector(
                    onTap: () => context.go('/news-feed'),
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAltOf(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.borderOf(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: n.source == 'BSEK' ? const Color(0xFFD97706).withValues(alpha: 0.12) : const Color(0xFF7C3AED).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(n.source,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                    color: n.source == 'BSEK' ? const Color(0xFFD97706) : const Color(0xFF7C3AED),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(n.category, style: TextStyle(fontSize: 10, color: AppColors.onSurfaceMutedOf(context), fontWeight: FontWeight.w500)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Text(n.title,
                              maxLines: 3, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.onSurfaceOf(context), height: 1.4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 11, color: AppColors.onSurfaceMutedOf(context)),
                              const SizedBox(width: 4),
                              Text(
                                n.timestamp != null ? DateFormat('MMM d').format(n.timestamp!.toDate()) : 'Recent',
                                style: TextStyle(fontSize: 10, color: AppColors.onSurfaceMutedOf(context), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTimeline() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        children: List.generate(_recentActivities.length, (i) {
          final a = _recentActivities[i];
          final isLast = i == _recentActivities.length - 1;
          return InkWell(
            onTap: () => context.go(a['route'] as String),
            borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(20)) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: (a['color'] as Color).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 16),
                      ),
                      if (!isLast)
                        Container(
                          width: 1.5, height: 20,
                          color: AppColors.borderOf(context),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 16 : 16, top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a['title'] as String,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.onSurfaceOf(context)),
                          ),
                          const SizedBox(height: 3),
                          Text("${a['type']} \u00b7 ${DateFormat('MMM d, h:mm a').format(a['date'] as DateTime)}",
                            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMutedOf(context)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: 6, bottom: isLast ? 16 : 16),
                    child: Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.onSurfaceMutedOf(context)),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildUpgradeBanner(bool isFree) {
    if (!isFree) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => context.push('/subscription'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withValues(alpha: 0.06), const Color(0xFF0F2460).withValues(alpha: 0.03)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Go Pro', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context))),
                  const SizedBox(height: 2),
                  Text('Audio teacher, Snap & Solve, paper grading & more',
                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMutedOf(context)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardNewsItem {
  final String id;
  final String title;
  final String originalUrl;
  final String source;
  final String category;
  final String imageUrl;
  final Timestamp? timestamp;
  _BoardNewsItem({required this.id, required this.title, required this.originalUrl, required this.source, required this.category, required this.imageUrl, this.timestamp});
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAltOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Column(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: int.tryParse(value) ?? 0),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text('$v', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.onSurfaceOf(context))),
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: AppColors.onSurfaceMutedOf(context), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
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
