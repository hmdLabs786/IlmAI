import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';

class ScanProgressDialog {
  static OverlayEntry? _overlayEntry;
  static StreamController<String>? _messageController;

  static void show(BuildContext context, {String initialMessage = 'Processing...'}) {
    _messageController = StreamController<String>.broadcast();
    _messageController!.add(initialMessage);

    _overlayEntry = OverlayEntry(
      builder: (context) => _ProgressOverlay(messageStream: _messageController!.stream),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void updateMessage(BuildContext context, String message) {
    _messageController?.add(message);
  }

  static void hide(BuildContext context) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _messageController?.close();
    _messageController = null;
  }
}

class _ProgressOverlay extends StatefulWidget {
  final Stream<String> messageStream;

  const _ProgressOverlay({required this.messageStream});

  @override
  State<_ProgressOverlay> createState() => _ProgressOverlayState();
}

class _ProgressOverlayState extends State<_ProgressOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  String _message = 'Processing...';

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    widget.messageStream.listen((msg) {
      if (mounted) setState(() => _message = msg);
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) => Transform.rotate(
                  angle: _rotationController.value * 2 * 3.14159,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF0F2460)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.auto_fix_high_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.border,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}