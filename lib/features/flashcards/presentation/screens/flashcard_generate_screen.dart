import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../../core/app_colors.dart';
import '../../../../core/constants/syllabus_data.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../core/subscription/subscription_gate_manager.dart';
import '../../data/services/flashcard_service.dart';

class FlashcardGenerateScreen extends StatefulWidget {
  final String? initialDeckId;
  const FlashcardGenerateScreen({super.key, this.initialDeckId});

  @override
  State<FlashcardGenerateScreen> createState() => _FlashcardGenerateScreenState();
}

class _FlashcardGenerateScreenState extends State<FlashcardGenerateScreen> {
  final FlashcardService _service = FlashcardService();
  final TextEditingController _freeTextController = TextEditingController();

  SyllabusSubject? _selectedSubject;
  String? _selectedChapter;
  String? _selectedDeckId;
  List<Map<String, dynamic>> _userDecks = [];
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _selectedDeckId = widget.initialDeckId;
    _loadDecks();
  }

  @override
  void dispose() {
    _freeTextController.dispose();
    super.dispose();
  }

  Future<void> _loadDecks() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('flashcard_decks')
        .where('userId', isEqualTo: uid)
        .get();
    if (mounted) {
      setState(() {
        _userDecks = snapshot.docs.map((d) => {'id': d.id, 'title': d['title'] ?? 'Untitled'}).toList();
      });
    }
  }

  Future<void> _generate() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    final profile = auth.profile;
    if (uid == null) return;

    String sourceText = _freeTextController.text.trim();

    if (_selectedSubject != null && _selectedChapter != null) {
      sourceText = 'Subject: ${_selectedSubject!.name}\nChapter: $_selectedChapter\nBoard: ${profile?.boardName ?? ""} Class: ${profile?.studentClass ?? ""}';
    }

    if (sourceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter text or select a subject/chapter first.')),
      );
      return;
    }

    String deckId = _selectedDeckId ?? '';

    if (deckId.isEmpty) {
      final title = _selectedChapter ?? 'Generated Cards';
      final subject = _selectedSubject?.name ?? 'General';
      final deck = await _service.createDeck(uid, title, subject);
      deckId = deck.id;
    } else {
      final auth = context.read<AuthProvider>();
      final tier = auth.subscriptionTier;
      final existingCards = await _service.getCardsStream(deckId).first;
      if (!await SubscriptionGateManager.canAddCard(uid, tier, existingCards.length)) {
        final max = SubscriptionGateManager.maxCardsPerDeck(tier);
        if (mounted) SubscriptionGateManager.showLimitDialog(context, tier, 'Cards per Deck', max);
        return;
      }
    }

    setState(() => _generating = true);

    final cards = await _service.generateCardsFromText(sourceText);
    if (cards.isNotEmpty) {
      await _service.addCards(deckId, cards);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${cards.length} flashcards created!')),
        );
        Navigator.pop(context, true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate cards. Try again.')),
        );
      }
    }

    if (mounted) setState(() => _generating = false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<AuthProvider>().profile;
    final subjects = profile != null
        ? SyllabusData.getSubjects(profile.boardName, profile.studentClass.toString())
        : <SyllabusSubject>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _generating
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 70, height: 70, child: CircularProgressIndicator(color: AppColors.primary)),
                  const SizedBox(height: 24),
                  const Text('AI is creating flashcards...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  const SizedBox(height: 8),
                  const Text('Generating question-answer pairs', style: TextStyle(color: AppColors.onSurfaceMuted)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.primary),
                        onPressed: () => context.go('/'),
                      ),
                    ),
                  ),
                  const Text('1. Source material', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.onSurface)),
                  const SizedBox(height: 6),
                  const Text('Paste study text below or select a subject+chapter.', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMuted)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _freeTextController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Paste your study notes or chapter text here...',
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (subjects.isNotEmpty) ...[
                    const Text('— or —', textAlign: TextAlign.center, style: TextStyle(color: AppColors.onSurfaceMuted)),
                    const SizedBox(height: 16),
                    const Text('2. Select subject & chapter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.onSurface)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<SyllabusSubject>(
                      initialValue: _selectedSubject,
                      items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name, style: const TextStyle(color: AppColors.onSurface)))).toList(),
                      onChanged: (val) => setState(() { _selectedSubject = val; _selectedChapter = null; }),
                      decoration: _inputDecoration('Choose subject'),
                      dropdownColor: Colors.white,
                    ),
                    if (_selectedSubject != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedChapter,
                        items: _selectedSubject!.chapters.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, color: AppColors.onSurface)))).toList(),
                        onChanged: (val) => setState(() => _selectedChapter = val),
                        decoration: _inputDecoration('Choose chapter'),
                        dropdownColor: Colors.white,
                      ),
                    ],
                    const SizedBox(height: 20),
                  ],
                  const Text('3. Target deck (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.onSurface)),
                  const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDeckId,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('New deck (auto-create)', style: TextStyle(color: AppColors.onSurfaceMuted))),
                        ..._userDecks.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['title'] as String, style: const TextStyle(color: AppColors.onSurface)))),
                      ],
                      onChanged: (val) => setState(() => _selectedDeckId = val),
                      decoration: _inputDecoration('Select existing deck or auto-create'),
                      dropdownColor: Colors.white,
                    ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: FilledButton(
                      onPressed: _generating ? null : _generate,
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: const Text('Generate Flashcards', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint, filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
