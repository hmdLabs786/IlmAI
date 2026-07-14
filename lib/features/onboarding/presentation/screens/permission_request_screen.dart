import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/app_colors.dart';

const String _permKey = 'permissions_requested';

class PermissionRequestScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const PermissionRequestScreen({super.key, required this.onComplete});

  @override
  State<PermissionRequestScreen> createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _notifGranted = false;
  bool _storageGranted = false;
  bool _cameraGranted = false;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    final notif = await Permission.notification.isGranted;
    final storage = await Permission.storage.isGranted;
    final camera = await Permission.camera.isGranted;
    if (mounted) setState(() { _notifGranted = notif; _storageGranted = storage; _cameraGranted = camera; });
  }

  Future<void> _requestNotif() async {
    final s = await Permission.notification.request();
    if (mounted) setState(() => _notifGranted = s.isGranted);
  }

  Future<void> _requestStorage() async {
    final s = await Permission.storage.request();
    if (mounted) setState(() => _storageGranted = s.isGranted);
  }

  Future<void> _requestCamera() async {
    final s = await Permission.camera.request();
    if (mounted) setState(() => _cameraGranted = s.isGranted);
  }

  Future<void> _finish() async {
    setState(() => _isRequesting = true);
    // Request any remaining denied permissions
    if (!_notifGranted) { final s = await Permission.notification.request(); _notifGranted = s.isGranted; }
    if (!_storageGranted) { final s = await Permission.storage.request(); _storageGranted = s.isGranted; }
    if (!_cameraGranted) { final s = await Permission.camera.request(); _cameraGranted = s.isGranted; }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permKey, true);
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(Icons.security_rounded, size: 72, color: AppColors.primary),
              const SizedBox(height: 20),
              const Text(
                'App Permissions',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Grant these permissions for the best experience.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.onSurfaceMuted),
              ),
              const SizedBox(height: 36),
              _permTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Board alerts, study reminders & updates',
                granted: _notifGranted,
                onRequest: _requestNotif,
              ),
              const SizedBox(height: 12),
              _permTile(
                icon: Icons.storage_outlined,
                title: 'Storage',
                subtitle: 'Save PDFs, notes & download books',
                granted: _storageGranted,
                onRequest: _requestStorage,
              ),
              const SizedBox(height: 12),
              _permTile(
                icon: Icons.camera_alt_outlined,
                title: 'Camera',
                subtitle: 'Snap & Solve — scan questions',
                granted: _cameraGranted,
                onRequest: _requestCamera,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isRequesting ? null : _finish,
                  child: Text(_isRequesting ? 'Requesting...' : 'Continue'),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback onRequest,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: (granted ? Colors.green : AppColors.primary).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: granted ? Colors.green : AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          granted
              ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24)
              : TextButton(
                  onPressed: onRequest,
                  child: const Text('Allow', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
        ],
      ),
    );
  }
}
