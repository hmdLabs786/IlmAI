import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/subscription/subscription_gate_manager.dart';
import '../../data/services/flashcard_service.dart';
import '../../data/models/flashcard_deck.dart';

class FlashcardDecksScreen extends StatefulWidget {
  const FlashcardDecksScreen({super.key});

  @override
  State<FlashcardDecksScreen> createState() => _FlashcardDecksScreenState();
}

class _FlashcardDecksScreenState extends State<FlashcardDecksScreen> {
  final FlashcardService _service = FlashcardService();
  final Map<String, int> _dueCounts = {};

  String? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = context.read<AuthProvider>().user;
    if (user != null && user.uid != _userId) {
      _userId = user.uid;
      _loadDueCounts();
    }
  }

  Future<void> _loadDueCounts() async {
    if (_userId == null) return;
    final decks = await _service.getDecksStream(_userId!).first;
    final counts = <String, int>{};
    for (final deck in decks) {
      final c = await _service.getDueCount(deck.id);
      counts[deck.id] = c;
    }
    if (mounted) setState(() { _dueCounts.clear(); _dueCounts.addAll(counts); });
  }

  Future<void> _createNewDeck() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    final tier = auth.subscriptionTier;
    if (uid == null) return;

    final decks = await _service.getDecksStream(uid).first;
    if (!await SubscriptionGateManager.canCreateDeck(uid, tier, decks.length)) {
      final max = SubscriptionGateManager.maxDecks(tier);
      if (mounted) SubscriptionGateManager.showLimitDialog(context, tier, 'Flashcard Decks', max);
      return;
    }
    if (!mounted) return;

    final titleC = TextEditingController();
    final subjectC = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Flashcard Deck'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleC,
              decoration: InputDecoration(
                labelText: 'Deck title',
                hintText: 'e.g. Physics Ch 5',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectC,
              decoration: InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g. Physics',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && titleC.text.trim().isNotEmpty) {
      await _service.createDeck(uid, titleC.text.trim(), subjectC.text.trim());
      if (mounted) _loadDueCounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewDeck,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<FlashcardDeck>>(
        stream: _service.getDecksStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final decks = snapshot.data ?? [];
          if (decks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card_rounded, size: 72, color: AppColors.primary.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text('No decks yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  const SizedBox(height: 8),
                  const Text('Create a deck to start reviewing', style: TextStyle(color: AppColors.onSurfaceMuted)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _createNewDeck,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Deck'),
                    style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ],
              ),
            );
          }

          final dueDecks = decks.where((d) => (_dueCounts[d.id] ?? 0) > 0).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceOf(context),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.primary),
                    onPressed: () => context.pop(),
                  ),
                ),
              ),
              if (dueDecks.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.today_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Due for review today', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                    ],
                  ),
                ),
                ...dueDecks.map((d) => _buildDeckCard(d, isDue: true)),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
              ],
              ...decks.where((d) => (_dueCounts[d.id] ?? 0) == 0).map((d) => _buildDeckCard(d)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeckCard(FlashcardDeck deck, {bool isDue = false}) {
    final due = _dueCounts[deck.id] ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDue ? AppColors.primary : AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (deck.cardCount == 0) {
            context.go('/flashcards/generate/${deck.id}');
          } else {
            context.go('/flashcards/review/${deck.id}');
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: isDue ? AppColors.primary : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.auto_stories_rounded, color: isDue ? Colors.white : AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deck.title, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      '${deck.subject} · ${deck.cardCount} cards${due > 0 ? " · $due due" : ""}',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              if (due > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text('$due due', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (val) async {
                  if (val == 'generate') {
                    context.go('/flashcards/generate/${deck.id}');
                  } else if (val == 'review') {
                    context.go('/flashcards/review/${deck.id}');
                  } else if (val == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete deck?'),
                        content: const Text('All cards will be permanently deleted.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _service.deleteDeck(deck.id);
                      if (mounted) _loadDueCounts();
                    }
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'generate', child: Row(children: [Icon(Icons.auto_awesome, color: AppColors.primary, size: 18), SizedBox(width: 8), Text('Generate cards')])),
                  const PopupMenuItem(value: 'review', child: Row(children: [Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 18), SizedBox(width: 8), Text('Review')])),
                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete')])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
