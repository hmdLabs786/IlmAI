import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/library_document.dart';

class LibraryRepository {
  final FirebaseFirestore _db;

  LibraryRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> documentsCollection({
    required String boardName,
    required String classId,
    required String subjectId,
  }) {
    return _db
        .collection('boards')
        .doc(boardName)
        .collection('classes')
        .doc(classId)
        .collection('subjects')
        .doc(subjectId)
        .collection('books');
  }

  Stream<List<LibraryDocument>> watchDocuments({
    required String boardName,
    required String classId,
    required String subjectId,
  }) {
    return documentsCollection(
      boardName: boardName,
      classId: classId,
      subjectId: subjectId,
    ).snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) => LibraryDocument.fromMap(
              id: doc.id,
              boardName: boardName,
              classId: classId,
              subjectId: subjectId,
              data: doc.data(),
            ),
          )
          .toList(),
    );
  }

  Future<void> upsertDocument(LibraryDocument document) async {
    await _db
        .doc(document.firestorePath)
        .set(document.toMap(), SetOptions(merge: true));
  }
}
