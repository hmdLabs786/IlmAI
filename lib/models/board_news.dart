import 'package:cloud_firestore/cloud_firestore.dart';

class BoardNews {
  final String id;
  final String title;
  final String originalUrl;
  final String source;
  final String category;
  final String imageUrl;
  final Timestamp? timestamp;

  BoardNews({
    required this.id,
    required this.title,
    required this.originalUrl,
    required this.source,
    required this.category,
    required this.imageUrl,
    this.timestamp,
  });

  factory BoardNews.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BoardNews(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      originalUrl: data['originalUrl']?.toString() ?? '',
      source: data['source']?.toString() ?? '',
      category: data['category']?.toString() ?? 'General',
      imageUrl: data['imageUrl']?.toString() ?? '',
      timestamp: data['timestamp'] as Timestamp?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'originalUrl': originalUrl,
      'source': source,
      'category': category,
      'imageUrl': imageUrl,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
    };
  }
}
