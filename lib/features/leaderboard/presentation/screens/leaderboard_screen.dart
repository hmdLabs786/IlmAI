import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/auth_provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _podiumCtrl;

  @override
  void initState() {
    super.initState();
    _podiumCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _podiumCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.profile;
    final currentUserName = profile?.name ?? 'Student';

    final participants = [
      {
        'rank': 1,
        'name': 'Ayesha Khan',
        'points': 4950,
        'district': 'Karachi Central',
        'isUser': false,
      },
      {
        'rank': 2,
        'name': 'Muhammad Ali',
        'points': 4780,
        'district': 'Karachi East',
        'isUser': false,
      },
      {
        'rank': 3,
        'name': 'Zainab Fatima',
        'points': 4610,
        'district': 'Karachi South',
        'isUser': false,
      },
      {
        'rank': 4,
        'name': currentUserName,
        'points': 3850,
        'district': 'Karachi West',
        'isUser': true,
      },
      {
        'rank': 5,
        'name': 'Bilal Siddiqui',
        'points': 3700,
        'district': 'Malir',
        'isUser': false,
      },
      {
        'rank': 6,
        'name': 'Hania Amir',
        'points': 3540,
        'district': 'Korangi',
        'isUser': false,
      },
      {
        'rank': 7,
        'name': 'Mustafa Kamal',
        'points': 3210,
        'district': 'Karachi North',
        'isUser': false,
      },
    ];

    final top3 = participants.take(3).toList();
    final rest = participants.skip(3).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          // ── Stats header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                      title: 'Your Rank',
                      value: '#4',
                      icon: Icons.emoji_events_rounded,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      title: 'Points',
                      value: '3,850',
                      icon: Icons.bolt_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      title: 'Accuracy',
                      value: '84%',
                      icon: Icons.auto_graph_rounded,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Podium header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Top Karachi Competitors',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Weekly Reset',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── TOP 3 Podium ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PodiumRow(top3: top3, controller: _podiumCtrl),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Divider label ──
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Divider(color: AppColors.border)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'Rankings 4–7',
                      style: TextStyle(
                        color: AppColors.onSurfaceMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.border)),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // ── Rest of participants ──
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final p = rest[index];
                final isUser = p['isUser'] as bool;
                final rank = p['rank'] as int;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppColors.primary.withValues(alpha: 0.07)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isUser ? AppColors.primary : AppColors.border,
                        width: isUser ? 1.5 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Rank badge
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : AppColors.border.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '#$rank',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isUser
                                    ? AppColors.primary
                                    : AppColors.onSurfaceMuted,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Avatar
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: _avatarColor(rank)
                              .withValues(alpha: 0.15),
                          child: Text(
                            (p['name'] as String)[0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _avatarColor(rank),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p['name'] as String,
                                style: TextStyle(
                                  fontWeight: isUser
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: AppColors.onSurface,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p['district'] as String,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.onSurfaceMuted,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmt(p['points'] as int),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.onSurface,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.bolt,
                                color: Colors.amber, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: rest.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Color _avatarColor(int rank) {
    const colors = [
      AppColors.primary,
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFF7C3AED),
      Color(0xFF0891B2),
    ];
    return colors[rank % colors.length];
  }

  String _fmt(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return n.toString();
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.onSurfaceMuted,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Animated Podium Component ────────────────────────────────────────────────

class _PodiumRow extends StatelessWidget {
  final List<Map<String, dynamic>> top3;
  final AnimationController controller;

  const _PodiumRow({required this.top3, required this.controller});

  @override
  Widget build(BuildContext context) {
    // Order: 2nd, 1st, 3rd — classic podium layout
    final order = [top3[1], top3[0], top3[2]];
    final heights = [100.0, 130.0, 85.0];
    final delays = [0.1, 0.0, 0.2];
    final medalColors = [
      const Color(0xFFC0C0C0), // silver
      const Color(0xFFFFD700), // gold
      const Color(0xFFCD7F32), // bronze
    ];
    final medalRanks = [2, 1, 3];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final p = order[i];
        final delay = delays[i];

        final slideAnim = Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: controller,
          curve: Interval(delay, delay + 0.6, curve: Curves.easeOutCubic),
        ));

        final fadeAnim = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(delay, delay + 0.5, curve: Curves.easeIn),
          ),
        );

        final scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(delay, delay + 0.7, curve: Curves.easeOutBack),
          ),
        );

        return Expanded(
          child: FadeTransition(
            opacity: fadeAnim,
            child: SlideTransition(
              position: slideAnim,
              child: ScaleTransition(
                scale: scaleAnim,
                child: _PodiumCard(
                  name: p['name'] as String,
                  points: p['points'] as int,
                  district: p['district'] as String,
                  rank: medalRanks[i],
                  medalColor: medalColors[i],
                  podiumHeight: heights[i],
                  isFirst: i == 1,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final String name;
  final int points;
  final String district;
  final int rank;
  final Color medalColor;
  final double podiumHeight;
  final bool isFirst;

  const _PodiumCard({
    required this.name,
    required this.points,
    required this.district,
    required this.rank,
    required this.medalColor,
    required this.podiumHeight,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown for 1st place
        if (isFirst)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 20),
          ),

        // Avatar
        Container(
          width: isFirst ? 56 : 46,
          height: isFirst ? 56 : 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: medalColor.withValues(alpha: 0.15),
            border: Border.all(color: medalColor, width: isFirst ? 2.5 : 2),
            boxShadow: isFirst
                ? [
                    BoxShadow(
                      color: medalColor.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              name[0].toUpperCase(),
              style: TextStyle(
                fontSize: isFirst ? 22 : 18,
                fontWeight: FontWeight.w900,
                color: medalColor,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Name
        Text(
          name.split(' ').first,
          style: TextStyle(
            fontSize: isFirst ? 13 : 11,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 2),

        // Points
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${(points / 1000).toStringAsFixed(1)}k',
              style: TextStyle(
                fontSize: isFirst ? 12 : 10,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.bolt, color: Colors.amber, size: 12),
          ],
        ),

        const SizedBox(height: 8),

        // Podium block
        Container(
          height: podiumHeight,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                medalColor.withValues(alpha: 0.85),
                medalColor.withValues(alpha: 0.55),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: medalColor.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: isFirst ? 22 : 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
