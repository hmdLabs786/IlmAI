import 'package:cloud_firestore/cloud_firestore.dart';

class FlashcardCard {
  final String id;
  final String front;
  final String back;
  final DateTime nextReviewDate;
  final int intervalDays;
  final double easeFactor;
  final DateTime createdAt;

  FlashcardCard({
    required this.id,
    required this.front,
    required this.back,
    required this.nextReviewDate,
    this.intervalDays = 0,
    this.easeFactor = 2.5,
    required this.createdAt,
  });

  factory FlashcardCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FlashcardCard(
      id: doc.id,
      front: data['front'] ?? '',
      back: data['back'] ?? '',
      nextReviewDate: (data['nextReviewDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      intervalDays: (data['intervalDays'] ?? 0) as int,
      easeFactor: (data['easeFactor'] ?? 2.5).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'front': front,
    'back': back,
    'nextReviewDate': Timestamp.fromDate(nextReviewDate),
    'intervalDays': intervalDays,
    'easeFactor': easeFactor,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
