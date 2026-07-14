import 'package:cloud_firestore/cloud_firestore.dart';

class LibraryItem {
  final String id;
  final String title;
  final String subject;
  final String pdfUrl;
  final bool isPremium;
  final int year;
  final String board;       // BSEK, BIEK
  final String classLevel;  // 9, 10, 11, 12, O1, O2, O3

  LibraryItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.pdfUrl,
    required this.isPremium,
    required this.year,
    required this.board,
    required this.classLevel,
  });

  factory LibraryItem.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return LibraryItem(
      id: doc.id,
      title: data['title'] ?? '',
      subject: data['subject'] ?? '',
      pdfUrl: data['pdfUrl'] ?? '',
      isPremium: data['isPremium'] ?? false,
      year: data['year'] ?? 0,
      board: data['board'] ?? 'BSEK',
      classLevel: data['classLevel'] ?? '9',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'subject': subject,
      'pdfUrl': pdfUrl,
      'isPremium': isPremium,
      'year': year,
      'board': board,
      'classLevel': classLevel,
    };
  }
}