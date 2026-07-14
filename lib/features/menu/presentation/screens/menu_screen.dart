import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/app_colors.dart';
import '../../../../main.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _darkMode = themeNotifier.value == ThemeMode.dark;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const _items = [
    _MenuItem('AI Tutor', Icons.psychology_rounded, AppColors.primary, '/chat'),
    _MenuItem('Exams & Tests', Icons.assignment_turned_in_rounded, Color(0xFF7C3AED), '/exams'),
    _MenuItem('Revision Notes', Icons.auto_stories_rounded, Color(0xFFD97706), '/notes'),
    _MenuItem('Flashcards', Icons.credit_card_rounded, Color(0xFFD97706), '/flashcards'),
    _MenuItem('Library', Icons.library_books_rounded, Color(0xFF059669), '/library'),
    _MenuItem('News Feed', Icons.campaign_rounded, Color(0xFF0891B2), '/news-feed'),
    _MenuItem('Settings', Icons.settings_rounded, Color(0xFF64748B), '/settings'),
    _MenuItem('Help Center', Icons.help_rounded, Color(0xFF0284C7), '/help'),
    _MenuItem('Profile', Icons.person_rounded, Color(0xFF1E3A8A), '/profile'),
  ];

  List<_MenuItem> get _filtered {
    if (_query.isEmpty) return _items;
    final q = _query.toLowerCase();
    return _items.where((i) => i.title.toLowerCase().contains(q)).toList();
  }

  Future<void> _toggleDark(bool val) async {
    themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', val);
    if (mounted) setState(() => _darkMode = val);
  }

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted) context.go('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final showLogout = _query.isEmpty || 'logout'.contains(_query.toLowerCase());
    final bg = AppColors.surfaceOf(context);
    final onSurf = AppColors.onSurfaceOf(context);
    final onMuted = AppColors.onSurfaceMutedOf(context);
    final bdr = AppColors.borderOf(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                  ),
                  const Spacer(),
                  Text(
                    'Menu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: onSurf,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search features...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: onMuted),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceAltOf(context),
                  hintStyle: TextStyle(color: onMuted, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: bdr),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: bdr.withValues(alpha: 0.7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  if (_filtered.isEmpty && !showLogout)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: onMuted.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text('No features found', style: TextStyle(color: onMuted, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ..._filtered.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, color: item.color, size: 20),
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: onSurf,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded, size: 20, color: onMuted),
                      onTap: () => context.go(item.route),
                    ),
                  )),
                  const SizedBox(height: 8),
                  Divider(color: bdr.withValues(alpha: 0.6)),
                  const SizedBox(height: 4),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Dark Theme',
                      style: TextStyle(fontWeight: FontWeight.w600, color: onSurf, fontSize: 14),
                    ),
                    trailing: Switch(
                      value: _darkMode,
                      activeThumbColor: AppColors.warning,
                      onChanged: _toggleDark,
                    ),
                  ),
                  if (showLogout) ...[
                    const SizedBox(height: 4),
                    Divider(color: bdr.withValues(alpha: 0.6)),
                    const SizedBox(height: 4),
                    ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      ),
                      title: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      onTap: _confirmLogout,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  const _MenuItem(this.title, this.icon, this.color, this.route);
}