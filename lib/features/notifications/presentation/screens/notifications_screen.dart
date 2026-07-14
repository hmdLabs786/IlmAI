import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/app_colors.dart';

enum _NotifCategory { system, board, chat, exam }

class _Notif {
  final String id;
  final _NotifCategory category;
  final String title;
  final String body;
  final DateTime time;
  final bool isRead;
  final String? route;

  const _Notif({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
    this.route,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _listCtrl;

  static const String _readKey = 'notif_read_ids';
  static const String _clearedKey = 'notif_cleared_ids';

  final List<_Notif> _allNotifications = [
    _Notif(
      id: 'bsek_results_2025',
      category: _NotifCategory.board,
      title: 'BSEK Matric Results 2025',
      body: 'The Board of Secondary Education Karachi has announced that Matric Part II results will be available on the official website.',
      time: DateTime.now().subtract(const Duration(minutes: 12)),
      route: '/news-feed',
    ),
    _Notif(
      id: 'mock_paper_ready',
      category: _NotifCategory.exam,
      title: 'Mock Paper Ready',
      body: 'Your AI-generated Physics test paper for Class 10 (Chapters 1–4) is ready to review.',
      time: DateTime.now().subtract(const Duration(hours: 1, minutes: 34)),
      route: '/exams',
    ),
    _Notif(
      id: 'ilmai_response',
      category: _NotifCategory.chat,
      title: 'IlmAI Agent Response',
      body: 'Your question about "Newton\'s Laws of Motion" has been answered with board-aligned structured notes.',
      time: DateTime.now().subtract(const Duration(hours: 3)),
      route: '/chat',
    ),
    _Notif(
      id: 'weekly_progress',
      category: _NotifCategory.system,
      title: 'Weekly Progress Report',
      body: 'Mashallah! You\'ve generated 3 exam papers and 5 notes this week. Keep up the great momentum!',
      time: DateTime.now().subtract(const Duration(hours: 22)),
      route: '/',
    ),
    _Notif(
      id: 'biek_schedule',
      category: _NotifCategory.board,
      title: 'BIEK Intermediate Schedule',
      body: 'BIEK has released the updated date sheet for Intermediate Part I annual examinations 2025.',
      time: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
      route: '/news-feed',
    ),
    _Notif(
      id: 'subscription_reminder',
      category: _NotifCategory.system,
      title: 'Subscription Reminder',
      body: 'Upgrade to IlmAI Pro to unlock audio-based AI teaching, past paper solutions, and premium exam checking.',
      time: DateTime.now().subtract(const Duration(days: 2)),
      route: '/subscription',
    ),
  ];

  Set<String> _readIds = {};
  Set<String> _clearedIds = {};

  List<_Notif> get _notifications => _allNotifications
      .where((n) => !_clearedIds.contains(n.id))
      .map((n) => _Notif(
            id: n.id,
            category: n.category,
            title: n.title,
            body: n.body,
            time: n.time,
            isRead: _readIds.contains(n.id),
            route: n.route,
          ))
      .toList();

  @override
  void initState() {
    super.initState();
    _listCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _readIds = prefs.getStringList(_readKey)?.toSet() ?? {};
      _clearedIds = prefs.getStringList(_clearedKey)?.toSet() ?? {};
    });
  }

  Future<void> _saveRead() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readKey, _readIds.toList());
  }

  Future<void> _saveCleared() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_clearedKey, _clearedIds.toList());
  }

  void _markRead(int index) {
    final n = _notifications[index];
    _readIds.add(n.id);
    _saveRead();
    setState(() {});
    if (n.route != null) {
      context.go(n.route!);
    }
  }

  void _markAllRead() {
    for (final n in _notifications) {
      _readIds.add(n.id);
    }
    _saveRead();
    setState(() {});
  }

  void _clearAll() {
    for (final n in _notifications) {
      _clearedIds.add(n.id);
    }
    _saveCleared();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: AppColors.onSurfaceOf(context)),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/menu'),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.onSurfaceOf(context),
                          ),
                        ),
                        if (unreadCount > 0)
                          Text(
                            '$unreadCount unread',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_notifications.isNotEmpty)
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text(
                        'Clear all',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (unreadCount > 0)
                    TextButton(
                      onPressed: _markAllRead,
                      child: const Text(
                        'Mark all read',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Category legend chips ──
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _NotifCategory.values.map((c) {
                  final meta = _categoryMeta(c);
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: (meta['color'] as Color).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          meta['icon'] as IconData,
                          size: 13,
                          color: meta['color'] as Color,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          meta['label'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: meta['color'] as Color,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // ── List ──
            Expanded(
              child: _notifications.isEmpty
                  ? _empty()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final n = _notifications[index];
                        final delay = index * 0.06;

                        return AnimatedBuilder(
                          animation: _listCtrl,
                          builder: (context, child) {
                            final t = Interval(
                              delay.clamp(0.0, 0.7),
                              (delay + 0.3).clamp(0.0, 1.0),
                              curve: Curves.easeOutCubic,
                            ).transform(_listCtrl.value);
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, 20 * (1 - t)),
                                child: child,
                              ),
                            );
                          },
                          child: Dismissible(
                            key: ValueKey('notif_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: AppColors.error,
                              ),
                            ),
                            onDismissed: (_) {
                              _clearedIds.add(_notifications[index].id);
                              _saveCleared();
                              setState(() {});
                            },
                            child: _NotifCard(
                              notif: n,
                              onTap: () => _markRead(index),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 72,
            color: AppColors.onSurfaceMutedOf(context).withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurfaceOf(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Board alerts and system updates will appear here.',
            style: TextStyle(
              color: AppColors.onSurfaceMutedOf(context),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> _categoryMeta(_NotifCategory cat) {
    switch (cat) {
      case _NotifCategory.board:
        return {
          'label': 'Board',
          'icon': Icons.account_balance_rounded,
          'color': const Color(0xFF0891B2),
        };
      case _NotifCategory.system:
        return {
          'label': 'System',
          'icon': Icons.info_outline_rounded,
          'color': const Color(0xFF64748B),
        };
      case _NotifCategory.chat:
        return {
          'label': 'IlmAI Chat',
          'icon': Icons.psychology_rounded,
          'color': AppColors.primary,
        };
      case _NotifCategory.exam:
        return {
          'label': 'Exams',
          'icon': Icons.assignment_turned_in_rounded,
          'color': const Color(0xFF7C3AED),
        };
    }
  }
}

class _NotifCard extends StatelessWidget {
  final _Notif notif;
  final VoidCallback onTap;

  const _NotifCard({required this.notif, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final meta = _NotificationsScreenState._categoryMeta(notif.category);
    final color = meta['color'] as Color;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notif.isRead
              ? AppColors.surfaceAltOf(context)
              : color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: notif.isRead
                ? AppColors.borderOf(context)
                : color.withValues(alpha: 0.25),
            width: notif.isRead ? 1 : 1.5,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                meta['icon'] as IconData,
                color: color,
                size: 20,
              ),
            ),

            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Category badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          meta['label'] as String,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Time
                      Text(
                        _timeAgo(notif.time),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceMutedOf(context),
                        ),
                      ),

                      // Unread dot
                      if (!notif.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    notif.title,
                    style: TextStyle(
                      fontWeight:
                          notif.isRead ? FontWeight.w600 : FontWeight.w800,
                      color: AppColors.onSurfaceOf(context),
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    notif.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.onSurfaceMutedOf(context),
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
