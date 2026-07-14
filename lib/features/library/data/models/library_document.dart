class LibraryDocument {
  final String id;
  final String boardName;
  final String classId;
  final String subjectId;
  final String title;
  final String type;
  final String fileUrl;
  final String group;

  LibraryDocument({
    required this.id,
    required this.boardName,
    required this.classId,
    required this.subjectId,
    required this.title,
    required this.type,
    required this.fileUrl,
    required this.group,
  });

  factory LibraryDocument.fromMap({
    required String id,
    required String boardName,
    required String classId,
    required String subjectId,
    required Map<String, dynamic> data,
  }) {
    return LibraryDocument(
      id: id,
      boardName: boardName,
      classId: classId,
      subjectId: subjectId,
      title: data['title'] ?? '',
      type: data['type'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      group: data['group'] ?? '',
    );
  }

  String get firestorePath =>
      'boards/$boardName/classes/$classId/subjects/$subjectId/documents/$id';

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'fileUrl': fileUrl,
      'group': group,
    };
  }
}
