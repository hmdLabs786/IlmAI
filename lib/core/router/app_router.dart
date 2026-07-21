import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../views/splash_screen.dart';
import '../../views/signin_screen.dart';
import '../../views/signup_screen.dart';
import '../../features/subscription/presentation/screens/tier_selection_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/notes/presentation/screens/notes_screen.dart';
import '../../features/exams/presentation/screens/exams_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/news_feed/presentation/screens/news_feed_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/about/presentation/screens/about_screen.dart';
import '../../features/leaderboard/presentation/screens/leaderboard_screen.dart';
import '../../features/help/presentation/screens/help_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/flashcards/presentation/screens/flashcard_decks_screen.dart';
import '../../features/flashcards/presentation/screens/flashcard_review_screen.dart';
import '../../features/flashcards/presentation/screens/flashcard_generate_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/menu/presentation/screens/menu_screen.dart';
import '../app_colors.dart';

// ── Premium fade + upward slide transition ───────────────────────────────────
Page<void> _premiumPage(Widget child, {String? key}) {
  return CustomTransitionPage<void>(
    key: ValueKey(key ?? child.runtimeType.toString()),
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: animation, curve: Curves.easeIn),
      );
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

// ── Horizontal slide transition (for same-level pushes) ──────────────────────
Page<void> _slidePage(Widget child, {String? key}) {
  return CustomTransitionPage<void>(
    key: ValueKey(key ?? child.runtimeType.toString()),
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ));
      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: animation,
          curve: const Interval(0, 0.6, curve: Curves.easeIn),
        ),
      );
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (_, s) => _premiumPage(const SplashScreen()),
    ),
    GoRoute(
      path: '/signin',
      pageBuilder: (_, s) => _slidePage(const SignInScreen()),
    ),
    GoRoute(
      path: '/signup',
      pageBuilder: (_, s) => _slidePage(const SignUpScreen()),
    ),
    GoRoute(
      path: '/tier-selection',
      pageBuilder: (_, s) => _slidePage(const TierSelectionScreen()),
    ),
    GoRoute(
      path: '/subscription',
      pageBuilder: (_, s) => _slidePage(const SubscriptionScreen()),
    ),
    GoRoute(
      path: '/about',
      pageBuilder: (_, s) => _slidePage(const AboutScreen()),
    ),
    GoRoute(
      path: '/notifications',
      pageBuilder: (_, s) => _slidePage(const NotificationsScreen()),
    ),
    GoRoute(
      path: '/menu',
      pageBuilder: (_, s) => _slidePage(const MenuScreen()),
    ),
    ShellRoute(
      navigatorKey: shellNavigatorKey,
      builder: (context, state, child) =>
          ShellLayout(state: state, child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (_, s) => _premiumPage(const DashboardScreen(), key: '/'),
        ),
        GoRoute(
          path: '/chat',
          pageBuilder: (_, s) => _premiumPage(const ChatScreen(), key: '/chat'),
        ),
        GoRoute(
          path: '/notes',
          pageBuilder: (_, s) => _premiumPage(const NotesScreen(), key: '/notes'),
        ),
        GoRoute(
          path: '/library',
          pageBuilder: (_, s) => _premiumPage(const LibraryScreen(), key: '/library'),
        ),
        GoRoute(
          path: '/news-feed',
          pageBuilder: (_, s) => _premiumPage(const NewsFeedScreen(), key: '/news-feed'),
        ),
        GoRoute(
          path: '/exams',
          pageBuilder: (_, s) => _premiumPage(const ExamsScreen(), key: '/exams'),
        ),
        GoRoute(
          path: '/quiz',
          pageBuilder: (_, s) => _premiumPage(const ExamsScreen(), key: '/quiz'),
        ),
        GoRoute(
          path: '/flashcards',
          pageBuilder: (_, s) => _premiumPage(const FlashcardDecksScreen(), key: '/flashcards'),
          routes: [
            GoRoute(
              path: 'review/:deckId',
              pageBuilder: (_, s) => _premiumPage(FlashcardReviewScreen(deckId: s.pathParameters['deckId']!), key: '/flashcards/review'),
            ),
            GoRoute(
              path: 'generate',
              pageBuilder: (_, s) => _premiumPage(const FlashcardGenerateScreen(), key: '/flashcards/generate'),
            ),
        GoRoute(
          path: '/flashcards/generate/:deckId',
          pageBuilder: (_, s) => _premiumPage(FlashcardGenerateScreen(initialDeckId: s.pathParameters['deckId']), key: '/flashcards/generate/deck'),
        ),
      ],
    ),
    GoRoute(
      path: '/analytics',
      pageBuilder: (_, s) => _premiumPage(const AnalyticsScreen(), key: '/analytics'),
    ),
    GoRoute(
      path: '/settings',
          pageBuilder: (_, s) => _premiumPage(const SettingsScreen(), key: '/settings'),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (_, s) => _premiumPage(const ProfileScreen(), key: '/profile'),
        ),
        GoRoute(
          path: '/leaderboard',
          pageBuilder: (_, s) => _premiumPage(const LeaderboardScreen(), key: '/leaderboard'),
        ),
        GoRoute(
          path: '/help',
          pageBuilder: (_, s) => _premiumPage(const HelpScreen(), key: '/help'),
        ),
      ],
    ),
  ],
  // Auth routing handled by splash_screen.dart after Firebase session restores.
);

// ─────────────────────────────────────────────────────────────────────────────
//  Shell Layout — luxury light-mode chrome
// ─────────────────────────────────────────────────────────────────────────────

class ShellLayout extends StatelessWidget {
  final GoRouterState state;
  final Widget child;

  const ShellLayout({super.key, required this.state, required this.child});

  int _navIndex(String path) {
    if (path == '/chat') return 0;
    if (path == '/') return 1;
    if (path == '/profile') return 2;
    return -1;
  }

  void _onNav(BuildContext context, int i) {
    switch (i) {
      case 0: context.go('/chat'); break;
      case 1: context.go('/'); break;
      case 2: context.go('/profile'); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = state.matchedLocation;
    final navIdx = _navIndex(path);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(child: child),
      bottomNavigationBar: _PremiumBottomNav(
        currentIndex: navIdx,
        onTap: (i) => _onNav(context, i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Premium Bottom Nav Bar
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const _PremiumBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.border.withValues(alpha: 0.7)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.psychology_outlined,
            activeIcon: Icons.psychology_rounded,
            label: 'IlmAI',
            index: 0,
            currentIndex: currentIndex,
            onTap: onTap,
          ),
          _HomeButton(
            isActive: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            activeIcon: Icons.person_rounded,
            label: 'Profile',
            index: 2,
            currentIndex: currentIndex,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sel = index == currentIndex;
    return InkWell(
      onTap: () => onTap(index),
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                sel ? activeIcon : icon,
                color: sel ? AppColors.primary : AppColors.onSurfaceMuted,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                color: sel ? AppColors.primary : AppColors.onSurfaceMuted,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _HomeButton({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF0F2460)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(
                  alpha: isActive ? 0.40 : 0.22),
              blurRadius: isActive ? 18 : 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: isActive
              ? Border.all(color: Colors.white, width: 2.5)
              : null,
        ),
        child: const Icon(Icons.home_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}


