import 'package:cloud_firestore/cloud_firestore.dart';

class NewsFeedItem {
  final String id;
  final String title;
  final String source;
  final DateTime date;
  final bool isTargetedAlert;
  final String boardTag;

  const NewsFeedItem({
    required this.id,
    required this.title,
    required this.source,
    required this.date,
    required this.isTargetedAlert,
    required this.boardTag,
  });

  factory NewsFeedItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NewsFeedItem(
      id: doc.id,
      title: data['title']?.toString() ?? 'Announcement',
      source: data['source']?.toString() ?? 'IlmAI',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isTargetedAlert: data['isTargetedAlert'] == true,
      boardTag: data['boardTag']?.toString() ?? 'General',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'source': source,
      'date': Timestamp.fromDate(date),
      'isTargetedAlert': isTargetedAlert,
      'boardTag': boardTag,
    };
  }
}
