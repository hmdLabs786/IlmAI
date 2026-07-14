class LibraryBook {
  final String id;
  final String boardName;
  final String classId;
  final String subjectId;
  final String title;
  final String pdfUrl;
  final int pageCount;

  const LibraryBook({
    required this.id,
    required this.boardName,
    required this.classId,
    required this.subjectId,
    required this.title,
    required this.pdfUrl,
    this.pageCount = 0,
  });

  factory LibraryBook.fromFirestore({
    required String id,
    required String boardName,
    required String classId,
    required String subjectId,
    required Map<String, dynamic> data,
  }) {
    return LibraryBook(
      id: id,
      boardName: boardName,
      classId: classId,
      subjectId: subjectId,
      title: data['title'] ?? '',
      pdfUrl: data['pdfUrl'] ?? '',
      pageCount: data['pageCount'] ?? 0,
    );
  }

  String get firestorePath =>
      'boards/$boardName/classes/$classId/subjects/$subjectId/books/$id';

  Map<String, dynamic> toMap() => {
    'title': title,
    'pdfUrl': pdfUrl,
    'pageCount': pageCount,
  };
}
