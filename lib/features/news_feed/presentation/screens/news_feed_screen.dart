import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/board_news.dart';
import '../../../../services/firestore_service.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  final FirestoreService _firestore = FirestoreService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedBoard = 'All';
  String? _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<BoardNews> _applyFilters(List<BoardNews> all) {
    return all.where((item) {
      if (_selectedBoard != 'All' && item.source != _selectedBoard) return false;
      if (_selectedCategory != null && item.category != _selectedCategory) return false;
      if (_searchQuery.isNotEmpty && !item.title.toLowerCase().contains(_searchQuery)) return false;
      return true;
    }).toList();
  }

  Set<String> _extractCategories(List<BoardNews> items) {
    return items.map((e) => e.category).where((c) => c.isNotEmpty).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _header(),
      _searchBar(),
      _boardChips(),
      Expanded(
        child: StreamBuilder<List<BoardNews>>(
          stream: _firestore.getBoardNewsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snapshot.hasError) return _error(snapshot.error.toString());
            final all = snapshot.data ?? [];
            final cats = _extractCategories(all);
            final filtered = _applyFilters(all);
            return Column(children: [
              if (cats.isNotEmpty) _categoryChips(cats),
              Expanded(child: filtered.isEmpty ? _empty() : _AnimatedNewsList(items: filtered, onItemTap: _open)),
            ]);
          },
        ),
      ),
    ]);
  }

  void _open(BoardNews item) async {
    final uri = Uri.tryParse(item.originalUrl);
    if (uri != null && uri.hasScheme) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(children: [
        const Text('Board News', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.autorenew_rounded, size: 14, color: AppColors.secondary),
            const SizedBox(width: 4),
            const Text('Live', style: TextStyle(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.onSurface),
        decoration: InputDecoration(
          hintText: 'Search news...',
          hintStyle: const TextStyle(color: AppColors.onSurfaceMuted),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.onSurfaceMuted),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear_rounded, color: AppColors.onSurfaceMuted), onPressed: () => _searchController.clear())
              : null,
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  Widget _boardChips() {
    const boards = ['All', 'BSEK', 'BIEK'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: boards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = boards[i];
          final display = label == 'All' ? 'All' : label == 'BSEK' ? 'BSEK (Matric)' : 'BIEK (Inter)';
          return _AnimatedChip(selected: _selectedBoard == label, onTap: () => setState(() => _selectedBoard = label), label: display);
        },
      ),
    );
  }

  Widget _categoryChips(Set<String> categories) {
    final sorted = categories.toList()..sort();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: sorted.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _AnimatedChip(selected: _selectedCategory == null, onTap: () => setState(() => _selectedCategory = null), label: 'All', selectedBg: AppColors.primary.withValues(alpha: 0.10), selectedFg: AppColors.primary);
          }
          final cat = sorted[i - 1];
          final sel = _selectedCategory == cat;
          final col = _catColor(cat);
          return _AnimatedChip(selected: sel, onTap: () => setState(() => _selectedCategory = sel ? null : cat), label: cat, selectedBg: col.withValues(alpha: 0.10), selectedFg: col);
        },
      ),
    );
  }

  Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'exams': return AppColors.primary;
      case 'results': return AppColors.success;
      case 'admissions': return AppColors.warning;
      default: return Colors.grey;
    }
  }

  Widget _empty() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.article_outlined, size: 64, color: AppColors.onSurfaceMuted.withValues(alpha: 0.4)),
      const SizedBox(height: 16),
      Text(_searchQuery.isNotEmpty || _selectedCategory != null || _selectedBoard != 'All' ? 'No matching news' : 'No board news yet',
        style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(_searchQuery.isNotEmpty || _selectedCategory != null || _selectedBoard != 'All' ? 'Try adjusting your search' : 'Board news will appear here once scraped',
        style: TextStyle(color: AppColors.onSurfaceMuted.withValues(alpha: 0.7), fontSize: 13)),
    ]));
  }

  Widget _error(String err) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.onSurfaceMuted.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        const Text('Could not load news', style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(err, textAlign: TextAlign.center, style: TextStyle(color: AppColors.onSurfaceMuted.withValues(alpha: 0.7), fontSize: 12)),
      ]),
    ));
  }
}

class _AnimatedChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String label;
  final Color? selectedBg;
  final Color? selectedFg;

  const _AnimatedChip({required this.selected, required this.onTap, required this.label, this.selectedBg, this.selectedFg});

  @override
  Widget build(BuildContext context) {
    final bg = selected ? (selectedBg ?? AppColors.primary) : AppColors.border.withValues(alpha: 0.5);
    final fg = selected ? (selectedFg ?? Colors.white) : AppColors.onSurfaceMuted;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.96,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
        ),
      ),
    );
  }
}

class _AnimatedNewsList extends StatefulWidget {
  final List<BoardNews> items;
  final void Function(BoardNews) onItemTap;
  const _AnimatedNewsList({super.key, required this.items, required this.onItemTap});

  @override
  State<_AnimatedNewsList> createState() => _AnimatedNewsListState();
}

class _AnimatedNewsListState extends State<_AnimatedNewsList> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Interval> _intervals = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _buildIntervals();
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedNewsList old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length || (widget.items.isNotEmpty && old.items.first.id != widget.items.first.id)) {
      _buildIntervals();
      _controller.forward(from: 0);
    }
  }

  void _buildIntervals() {
    _intervals.clear();
    for (int i = 0; i < widget.items.length; i++) {
      final d = (i * 0.04).clamp(0.0, 0.7);
      _intervals.add(Interval(d, (d + 0.2).clamp(0.0, 1.0), curve: Curves.easeOutCubic));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.items.length,
      itemBuilder: (context, index) {
        final item = widget.items[index];
        final interval = _intervals[index];
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = interval.transform(_controller.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(offset: Offset(0, 30 * (1 - t)), child: child),
            );
          },
          child: _NewsCard(item: item, onTap: () => widget.onItemTap(item)),
        );
      },
    );
  }
}

class _NewsCard extends StatelessWidget {
  final BoardNews item;
  final VoidCallback onTap;
  const _NewsCard({required this.item, required this.onTap});

  Color _srcColor() => item.source == 'BSEK' ? const Color(0xFF06B6D4) : const Color(0xFF8B5CF6);

  Color _catColor() {
    switch (item.category.toLowerCase()) {
      case 'exams': return AppColors.primary;
      case 'results': return AppColors.success;
      case 'admissions': return AppColors.warning;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl.isNotEmpty;
    final sc = _srcColor();
    final cc = _catColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hasImage)
            AspectRatio(aspectRatio: 16 / 9,
              child: Image.network(item.imageUrl, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(sc),
                loadingBuilder: (_, child, p) => p == null ? child : _placeholder(sc)),
            )
          else
            _placeholder(sc),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _badge(sc, Colors.white, item.source == 'BSEK' ? 'BSEK (Matric)' : 'BIEK (Inter)'),
                const SizedBox(width: 6),
                _badge(cc.withValues(alpha: 0.12), cc, item.category),
                const Spacer(),
                if (item.timestamp != null)
                  Text(DateFormat('MMM dd, yyyy').format(item.timestamp!.toDate()),
                    style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 10),
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3, color: AppColors.onSurface),
                maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                Text('View source', style: TextStyle(color: sc, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.open_in_new_rounded, size: 13, color: sc),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _badge(Color bg, Color tc, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: tc, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  Widget _placeholder(Color accent) {
    return Container(
      height: 140,
      decoration: BoxDecoration(gradient: LinearGradient(colors: [accent.withValues(alpha: 0.15), AppColors.surface], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(child: Icon(Icons.article_rounded, size: 40, color: accent.withValues(alpha: 0.3))),
    );
  }
}
