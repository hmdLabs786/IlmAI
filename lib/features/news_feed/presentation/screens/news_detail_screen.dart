import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/board_news.dart';

class NewsDetailScreen extends StatefulWidget {
  final BoardNews item;
  const NewsDetailScreen({super.key, required this.item});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _contentFade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasImage = item.imageUrl.isNotEmpty;
    final sc = item.source == 'BSEK' ? const Color(0xFF06B6D4) : const Color(0xFF8B5CF6);

    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: hasImage ? 280 : 160,
          pinned: true,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: hasImage
                ? Image.network(item.imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(sc))
                : _placeholder(sc),
          ),
        ),
        SliverToBoxAdapter(
          child: FadeTransition(
            opacity: _contentFade,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _badge(sc, Colors.white, item.source == 'BSEK' ? 'BSEK (Matric)' : 'BIEK (Inter)'),
                  const SizedBox(width: 8),
                  _badge(_catColor().withValues(alpha: 0.12), _catColor(), item.category),
                ]),
                const SizedBox(height: 16),
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, height: 1.25, color: AppColors.onSurface)),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.onSurfaceMuted),
                  const SizedBox(width: 6),
                  Text(item.timestamp != null ? DateFormat('MMMM dd, yyyy').format(item.timestamp!.toDate()) : 'Date unknown',
                    style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 13)),
                ]),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openUrl(item.originalUrl),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('View Original Source'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Color _catColor() {
    switch (widget.item.category.toLowerCase()) {
      case 'exams': return AppColors.primary;
      case 'results': return AppColors.success;
      case 'admissions': return AppColors.warning;
      default: return Colors.grey;
    }
  }

  Widget _badge(Color bg, Color tc, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: tc, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _placeholder(Color accent) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [accent.withValues(alpha: 0.3), Colors.white], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: Center(child: Icon(Icons.article_rounded, size: 48, color: accent.withValues(alpha: 0.4))),
    );
  }

  void _openUrl(String url) async {
    final encoded = Uri.encodeFull(url);
    final uri = Uri.tryParse(encoded);
    if (uri == null || !uri.hasScheme) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}
