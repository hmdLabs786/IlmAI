import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ilmai/features/library/data/models/library_book.dart';
import 'package:ilmai/models/board_news.dart';
import 'package:ilmai/models/news_item.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<LibraryBook>> getLibraryBooks() {
    return _db.collectionGroup('books').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) {
          final pathSegments = doc.reference.path.split('/');
          final board = pathSegments.length > 1 ? pathSegments[1] : '';
          final cl = pathSegments.length > 3 ? pathSegments[3] : '';
          final sub = pathSegments.length > 5 ? pathSegments[5] : '';
          return LibraryBook.fromFirestore(
            id: doc.id,
            boardName: board,
            classId: cl,
            subjectId: sub,
            data: doc.data(),
          );
        }).toList());
  }

  Stream<List<NewsItem>> getNewsFeed() {
    return _db
        .collection('news_feed')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => NewsItem.fromFirestore(doc)).toList());
  }

  Stream<List<BoardNews>> getBoardNewsStream() {
    return _db
        .collection('board_news')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => BoardNews.fromFirestore(doc)).toList());
  }
}