import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/widgets/smart_text.dart';
import '../../data/services/flashcard_service.dart';
import '../../data/models/flashcard_card.dart';

class FlashcardReviewScreen extends StatefulWidget {
  final String deckId;
  const FlashcardReviewScreen({super.key, required this.deckId});

  @override
  State<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends State<FlashcardReviewScreen>
    with TickerProviderStateMixin {
  final FlashcardService _service = FlashcardService();
  List<FlashcardCard> _cards = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _loaded = false;

  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  double _dragX = 0;
  bool _showButtons = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
    _loadCards();
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    final cards = await _service.getDueCards(widget.deckId);
    cards.shuffle(Random());
    if (mounted) {
      setState(() { _cards = cards; _loaded = true; });
    }
  }

  void _flip() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    _isFlipped = !_isFlipped;
  }

  Future<void> _rate(int rating) async {
    if (_currentIndex >= _cards.length) return;
    final card = _cards[_currentIndex];
    await _service.reviewCard(widget.deckId, card.id, rating);
    if (_isFlipped) _flip();
    setState(() {
      _currentIndex++;
      _dragX = 0;
      _showButtons = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        title: Text(
          _loaded && _currentIndex < _cards.length
              ? '${_currentIndex + 1} / ${_cards.length}'
              : 'Review',
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.onSurface),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_stories_rounded, size: 72, color: AppColors.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('No cards to review', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
            const SizedBox(height: 8),
            const Text('Generate flashcards from your notes or chapter text.', style: TextStyle(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 24),
              FilledButton.icon(
              onPressed: () => context.go('/flashcards/generate/${widget.deckId}'),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate flashcards'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to decks'),
            ),
          ],
        ),
      );
    }
    if (_currentIndex >= _cards.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.celebration_rounded, size: 72, color: AppColors.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            const Text('Review complete!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.onSurface)),
            const SizedBox(height: 8),
            Text('${_cards.length} cards reviewed.', style: const TextStyle(color: AppColors.onSurfaceMuted)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/flashcards/generate/${widget.deckId}'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Generate more'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }

    final card = _cards[_currentIndex];
    final screenW = MediaQuery.of(context).size.width;
    final cardW = screenW - 48;

    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          'Tap card to flip · Swipe to rate',
          style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted.withValues(alpha: 0.7)),
        ),
        Expanded(
          child: Center(
            child: GestureDetector(
              onTap: _flip,
              onHorizontalDragUpdate: (d) {
                setState(() { _dragX += d.delta.dx; _showButtons = false; });
              },
              onHorizontalDragEnd: (d) {
                if (_dragX.abs() > 80) {
                  final rating = _dragX > 0 ? 2 : 0;
                  _rate(rating);
                } else {
                  setState(() { _dragX = 0; _showButtons = true; });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: cardW,
                height: cardW * 1.35,
                transform: Matrix4.identity()
                  ..rotateZ((_dragX / 300).clamp(-0.15, 0.15)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _flipAnimation,
                      builder: (context, child) {
                        final angle = _flipAnimation.value * pi;
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle),
                          child: angle < pi / 2 ? _buildCardFront(card) : Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()..rotateY(pi),
                            child: _buildCardBack(card),
                          ),
                        );
                      },
                    ),
                    if (_dragX.abs() > 40)
                      Positioned(
                        top: 24,
                        left: _dragX > 0 ? null : 24,
                        right: _dragX > 0 ? 24 : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: _dragX > 0 ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _dragX > 0 ? 'EASY' : 'HARD',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedOpacity(
          opacity: _showButtons ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ratingButton(Icons.close_rounded, 'Hard', Colors.red, 0),
                _ratingButton(Icons.check_rounded, 'Good', AppColors.primary, 1),
                _ratingButton(Icons.done_all_rounded, 'Easy', Colors.green, 2),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ratingButton(IconData icon, String label, Color color, int rating) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _rate(rating),
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _buildCardFront(FlashcardCard card) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('QUESTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 1)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: SmartText(
                  card.front,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface, height: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Tap to reveal answer', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(FlashcardCard card) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('ANSWER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green, letterSpacing: 1)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: SmartText(
                  card.back,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, color: AppColors.onSurface, height: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Swipe right: Easy · Left: Hard', style: TextStyle(fontSize: 11, color: AppColors.onSurfaceMuted.withValues(alpha: 0.6))),
          ),
        ],
      ),
    );
  }
}
