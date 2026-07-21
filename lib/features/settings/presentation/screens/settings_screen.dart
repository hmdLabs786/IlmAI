import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/app_colors.dart';
import '../../../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  bool _notificationsEnabled = false;
  String _reminderTime = '08:00 PM';
  bool _boardNewsAlerts = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
        parent: _pulseController, curve: Curves.easeOut));
    _loadPrefs();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _pulse() => _pulseController.forward(from: 0);

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _reminderTime = prefs.getString('reminder_time') ?? '08:00 PM';
      _boardNewsAlerts = prefs.getBool('board_news_alerts') ?? false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setString('reminder_time', _reminderTime);
    await prefs.setBool('board_news_alerts', _boardNewsAlerts);
  }

  Future<void> _toggleBoardNewsAlerts(bool value) async {
    if (value) {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await messaging.subscribeToTopic('karachi_board_updates');
        setState(() => _boardNewsAlerts = true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission denied. Enable in Settings.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    } else {
      await FirebaseMessaging.instance
          .unsubscribeFromTopic('karachi_board_updates');
      setState(() => _boardNewsAlerts = false);
    }
    await _savePrefs();
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(DateTime.now()),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _reminderTime = picked.format(context);
      _notificationsEnabled = true;
    });
    await _savePrefs();
  }

  Future<void> _toggleDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', value);
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── APPEARANCE ──
          _sectionHeader('Appearance', Icons.palette_outlined),
          _settingsCard(
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, themeMode, _) {
                final dark = themeMode == ThemeMode.dark;
                return _switchTile(
                  icon: dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  iconColor: dark ? const Color(0xFF7C3AED) : Colors.amber,
                  title: 'Theme Mode',
                  subtitle: dark ? 'Dark appearance is active' : 'Light appearance is active',
                  value: dark,
                  onChanged: _toggleDarkMode,
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── NOTIFICATIONS ──
          _sectionHeader('Notifications', Icons.notifications_none_rounded),
          _settingsCard(
            child: Column(
              children: [
                // Study reminders toggle
                _switchTile(
                  icon: Icons.alarm_rounded,
                  iconColor: AppColors.primary,
                  title: 'Study Reminders',
                  subtitle: _notificationsEnabled
                      ? 'Enabled at $_reminderTime'
                      : 'Notifications are off',
                  value: _notificationsEnabled,
                  onChanged: (v) async {
                    setState(() => _notificationsEnabled = v);
                    await _savePrefs();
                  },
                ),

                _divider(),

                // Board news alerts toggle
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: child,
                  ),
                  child: _switchTile(
                    icon: Icons.campaign_rounded,
                    iconColor: const Color(0xFF0891B2),
                    title: 'Board News Alerts',
                    subtitle: _boardNewsAlerts
                        ? 'Live alerts from BSEK & BIEK enabled'
                        : 'Get notified about board announcements',
                    value: _boardNewsAlerts,
                    onChanged: (v) {
                      _pulse();
                      _toggleBoardNewsAlerts(v);
                    },
                  ),
                ),

                _divider(),

                // Reminder time picker
                _actionTile(
                  icon: Icons.access_time_rounded,
                  iconColor: AppColors.warning,
                  title: 'Reminder Time',
                  subtitle: _reminderTime,
                  onTap: _pickReminderTime,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          const SizedBox(height: 24),

          // ── App info footer ──
          Center(
            child: Text(
              'IlmAI v1.2.7 · Made in Karachi',
              style: TextStyle(
                color: AppColors.onSurfaceMutedOf(context).withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    final muted = AppColors.onSurfaceMutedOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    final onSurf = AppColors.onSurfaceOf(context);
    final muted = AppColors.onSurfaceMutedOf(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: onSurf,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
          inactiveThumbColor: AppColors.surfaceAltOf(context),
          inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final onSurf = AppColors.onSurfaceOf(context);
    final muted = AppColors.onSurfaceMutedOf(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: onSurf,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: muted,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(
        color: AppColors.primary.withValues(alpha: 0.10),
        height: 1,
      ),
    );
  }
}
