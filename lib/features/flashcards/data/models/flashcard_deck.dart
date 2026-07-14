import 'package:cloud_firestore/cloud_firestore.dart';

class FlashcardDeck {
  final String id;
  final String userId;
  final String title;
  final String subject;
  final int cardCount;
  final DateTime createdAt;

  FlashcardDeck({
    required this.id,
    required this.userId,
    required this.title,
    required this.subject,
    this.cardCount = 0,
    required this.createdAt,
  });

  factory FlashcardDeck.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FlashcardDeck(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? 'Untitled Deck',
      subject: data['subject'] ?? '',
      cardCount: (data['cardCount'] ?? 0) as int,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'title': title,
    'subject': subject,
    'cardCount': cardCount,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
