class ChapterScore {
  final String subject;
  final String chapterName;
  final double score;
  final int totalQuestions;
  final int correctAnswers;
  final List<String> incorrectTopics;

  ChapterScore({
    required this.subject,
    required this.chapterName,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    this.incorrectTopics = const [],
  });

  double get percentage => totalQuestions > 0 ? (correctAnswers / totalQuestions) * 100 : 0;

  String get statusLabel {
    if (percentage >= 80) return 'Mastered';
    if (percentage >= 50) return 'Review Needed';
    return 'Critical';
  }
}

class SubjectSummary {
  final String subject;
  final List<ChapterScore> chapters;
  final double overallPercentage;

  SubjectSummary({
    required this.subject,
    required this.chapters,
    required this.overallPercentage,
  });
}
