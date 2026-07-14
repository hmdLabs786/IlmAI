import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../data/models/flashcard_deck.dart';
import '../../data/models/flashcard_card.dart';
import '../../../../core/config.dart';

class FlashcardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _decksRef => _db.collection('flashcard_decks');
  CollectionReference _cardsRef(String deckId) =>
      _decksRef.doc(deckId).collection('cards');

  // ── Subscription guard ──────────────────────────────────────────

  Future<bool> canCreateDeck(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final tier = (userDoc.data()?['subscriptionTier'] ?? 'Free').toString();
    if (tier.toLowerCase() != 'free') return true;

    final snapshot = await _decksRef.where('userId', isEqualTo: userId).get();
    return snapshot.docs.length < 2;
  }

  Future<bool> canAddCard(String deckId, String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final tier = (userDoc.data()?['subscriptionTier'] ?? 'Free').toString();
    if (tier.toLowerCase() != 'free') return true;

    final snapshot = await _cardsRef(deckId).get();
    return snapshot.docs.length < 20;
  }

  // ── Deck operations ─────────────────────────────────────────────

  Future<FlashcardDeck> createDeck(String userId, String title, String subject) async {
    final docRef = await _decksRef.add({
      'userId': userId,
      'title': title,
      'subject': subject,
      'cardCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return FlashcardDeck(
      id: docRef.id,
      userId: userId,
      title: title,
      subject: subject,
      createdAt: DateTime.now(),
    );
  }

  Future<void> deleteDeck(String deckId) async {
    final cards = await _cardsRef(deckId).get();
    final batch = _db.batch();
    for (final doc in cards.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_decksRef.doc(deckId));
    await batch.commit();
  }

  Stream<List<FlashcardDeck>> getDecksStream(String userId) {
    return _decksRef
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) => FlashcardDeck.fromFirestore(doc)).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<int> getDueCount(String deckId) async {
    final snapshot = await _cardsRef(deckId).get();
    final now = DateTime.now();
    return snapshot.docs.where((d) {
      final date = (d['nextReviewDate'] as Timestamp?)?.toDate();
      return date != null && !date.isAfter(now);
    }).length;
  }

  // ── Card operations ─────────────────────────────────────────────

  Future<void> addCards(String deckId, List<Map<String, String>> cards) async {
    final batch = _db.batch();
    for (final card in cards) {
      final docRef = _cardsRef(deckId).doc();
      batch.set(docRef, {
        'front': card['front'] ?? '',
        'back': card['back'] ?? '',
        'nextReviewDate': Timestamp.fromDate(DateTime.now()),
        'intervalDays': 0,
        'easeFactor': 2.5,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    batch.update(_decksRef.doc(deckId), {
      'cardCount': FieldValue.increment(cards.length),
    });
    await batch.commit();
  }

  Stream<List<FlashcardCard>> getCardsStream(String deckId) {
    return _cardsRef(deckId)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) => FlashcardCard.fromFirestore(doc)).toList();
          list.sort((a, b) => a.nextReviewDate.compareTo(b.nextReviewDate));
          return list;
        });
  }

  Future<List<FlashcardCard>> getDueCards(String deckId) async {
    final snapshot = await _cardsRef(deckId).get();
    final now = DateTime.now();
    final list = snapshot.docs
        .map((doc) => FlashcardCard.fromFirestore(doc))
        .where((c) => !c.nextReviewDate.isAfter(now))
        .toList();
    list.sort((a, b) => a.nextReviewDate.compareTo(b.nextReviewDate));
    return list;
  }

  // ── SM-2 spaced repetition ──────────────────────────────────────

  /// `rating`: 0 = Hard, 1 = Good, 2 = Easy
  Future<void> reviewCard(String deckId, String cardId, int rating) async {
    final docRef = _cardsRef(deckId).doc(cardId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final card = FlashcardCard.fromFirestore(snap);
    final now = DateTime.now();

    int newInterval;
    double newEase;

    switch (rating) {
      case 0: // Hard
        newInterval = (card.intervalDays / 2).ceil().clamp(1, 9999);
        newEase = (card.easeFactor - 0.2).clamp(1.3, 5.0);
      case 2: // Easy
        newInterval = card.intervalDays == 0
            ? 3
            : (card.intervalDays * card.easeFactor * 1.3).round().clamp(1, 9999);
        newEase = (card.easeFactor + 0.15).clamp(1.3, 5.0);
      default: // Good
        newInterval = card.intervalDays == 0
            ? 1
            : card.intervalDays == 1
                ? 3
                : (card.intervalDays * card.easeFactor).round().clamp(1, 9999);
        newEase = (card.easeFactor + 0.05).clamp(1.3, 5.0);
    }

    await docRef.update({
      'intervalDays': newInterval,
      'easeFactor': newEase,
      'nextReviewDate': Timestamp.fromDate(
        now.add(Duration(days: newInterval)),
      ),
    });
  }

  // ── Gemini card generation ──────────────────────────────────────

  String get _geminiApiKey {
    if (AppConfig.geminiApiKey.isNotEmpty && AppConfig.geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE') {
      return AppConfig.geminiApiKey;
    }
    return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  }

  Future<List<Map<String, String>>> generateCardsFromText(String sourceText, {int count = 10}) async {
    if (_geminiApiKey.isEmpty) {
      return _mockCards(count);
    }

    final prompt = '''
You are an AI that creates flashcards for active recall study.

Given the following study material, generate exactly $count flashcards (question-answer pairs) that cover the most important concepts.

Return ONLY a valid JSON array. No markdown, no code fences, no extra text.
Each object must have exactly two keys: "front" (the question) and "back" (the answer).

Example:
[{"front": "What is Newton's first law?", "back": "An object at rest stays at rest unless acted upon by an external force."}]

Material:
$sourceText
''';

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiApiKey);
      final response = await model.generateContent([Content.text(prompt)]);
      final raw = response.text ?? '';
      return _parseCardJson(raw);
    } catch (e) {
      debugPrint('Gemini card generation error: $e');
      return _mockCards(count);
    }
  }

  List<Map<String, String>> _parseCardJson(String raw) {
    String cleaned = raw.trim();
    if (cleaned.startsWith('```')) {
      final first = cleaned.indexOf('\n');
      if (first != -1) cleaned = cleaned.substring(first + 1);
      final last = cleaned.lastIndexOf('```');
      if (last != -1) cleaned = cleaned.substring(0, last);
    }
    cleaned = cleaned.trim();

    try {
      final list = jsonDecode(cleaned) as List;
      return list
          .map((e) => {
                'front': (e['front'] ?? '').toString().trim(),
                'back': (e['back'] ?? '').toString().trim(),
              })
          .where((m) => m['front']!.isNotEmpty && m['back']!.isNotEmpty)
          .toList();
    } catch (_) {
      return _mockCards(5);
    }
  }

  List<Map<String, String>> _mockCards(int count) {
    final samples = [
      {'front': 'What is the capital of France?', 'back': 'Paris'},
      {'front': 'What is 2 + 2?', 'back': '4'},
      {'front': 'What planet is known as the Red Planet?', 'back': 'Mars'},
      {'front': 'What is H₂O commonly known as?', 'back': 'Water'},
      {'front': 'Who wrote "Romeo and Juliet"?', 'back': 'William Shakespeare'},
      {'front': 'What is the largest ocean on Earth?', 'back': 'Pacific Ocean'},
      {'front': 'What gas do plants absorb from the atmosphere?', 'back': 'Carbon dioxide (CO₂)'},
      {'front': 'What is the boiling point of water in Celsius?', 'back': '100°C'},
      {'front': 'What is the speed of light approximately?', 'back': '3 × 10⁸ m/s'},
      {'front': 'What force keeps planets orbiting the Sun?', 'back': 'Gravity'},
    ];
    return samples.take(count).toList();
  }
}
