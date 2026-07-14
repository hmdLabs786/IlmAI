import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../analytics/data/models/chapter_score.dart';
import '../../../../core/config.dart';

class AnalyticsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Reads from the `exam_results` collection and aggregates scores
  /// grouped by subject → chapter.
  Future<List<SubjectSummary>> getSubjectSummaries(String userId) async {
    final snapshot = await _db
        .collection('exam_results')
        .where('userId', isEqualTo: userId)
        .get();

    final Map<String, Map<String, List<ChapterScore>>> grouped = {};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final subject = data['subject'] as String? ?? 'General';
      final chapter = data['chapterName'] as String? ?? 'Unknown';
      final total = (data['totalQuestions'] as num?)?.toInt() ?? 0;
      final correct = (data['correctAnswers'] as num?)?.toInt() ?? 0;
      final score = (data['score'] as num?)?.toDouble() ?? 0.0;
      final topics = (data['incorrectTopics'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      grouped.putIfAbsent(subject, () => {});
      grouped[subject]!.putIfAbsent(chapter, () => []);
      grouped[subject]![chapter]!.add(ChapterScore(
        subject: subject,
        chapterName: chapter,
        score: score,
        totalQuestions: total,
        correctAnswers: correct,
        incorrectTopics: topics,
      ));
    }

    final summaries = <SubjectSummary>[];
    for (final subEntry in grouped.entries) {
      final chapterSummaries = <ChapterScore>[];
      double totalWeighted = 0;
      int totalQ = 0;

      for (final chEntry in subEntry.value.entries) {
        final scores = chEntry.value;
        final sumCorrect = scores.fold<int>(0, (a, b) => a + b.correctAnswers);
        final sumTotal = scores.fold<int>(0, (a, b) => a + b.totalQuestions);
        final allTopics = scores.expand((s) => s.incorrectTopics).toList();
        final avgScore = sumTotal > 0 ? (sumCorrect / sumTotal) * 100 : 0.0;

        chapterSummaries.add(ChapterScore(
          subject: subEntry.key,
          chapterName: chEntry.key,
          score: avgScore,
          totalQuestions: sumTotal,
          correctAnswers: sumCorrect,
          incorrectTopics: allTopics,
        ));
        totalWeighted += avgScore * sumTotal;
        totalQ += sumTotal;
      }

      summaries.add(SubjectSummary(
        subject: subEntry.key,
        chapters: chapterSummaries,
        overallPercentage: totalQ > 0 ? totalWeighted / totalQ : 0,
      ));
    }

    summaries.sort((a, b) => b.overallPercentage.compareTo(a.overallPercentage));
    return summaries;
  }

  // ── Gemini recommendation ───────────────────────────────────────

  String get _geminiApiKey {
    if (AppConfig.geminiApiKey.isNotEmpty && AppConfig.geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE') {
      return AppConfig.geminiApiKey;
    }
    return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  }

  Future<String> getRecommendation(List<SubjectSummary> summaries) async {
    final weakChapters = summaries
        .expand((s) => s.chapters)
        .where((c) => c.percentage < 80)
        .map((c) => '${c.subject} - ${c.chapterName} (${c.percentage.toStringAsFixed(0)}%)')
        .toList();

    if (weakChapters.isEmpty) {
      return 'Great work! You are performing well across all chapters. Keep revising regularly.';
    }

    final weakText = weakChapters.join('\n');

    if (_geminiApiKey.isEmpty) {
      return _mockRecommendation(weakChapters);
    }

    final prompt = '''
You are an academic coach for Pakistani board students.

The student has weak performance in the following chapters/topics:
$weakText

Give exactly 3 bullet points of personalized study recommendations.
- Each bullet must be actionable and specific (mention the chapter name).
- Keep each bullet under 2 lines.
- Format as plain bullet points starting with "• ".
- No markdown, no headings, no extra text.
''';

    try {
      final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiApiKey);
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? _mockRecommendation(weakChapters);
    } catch (_) {
      return _mockRecommendation(weakChapters);
    }
  }

  String _mockRecommendation(List<String> weakChapters) {
    final sb = StringBuffer();
    for (int i = 0; i < weakChapters.length && i < 3; i++) {
      final parts = weakChapters[i].split(' - ');
      sb.writeln('• Focus on ${parts.length > 1 ? parts[1] : weakChapters[i]} — review key definitions and practice past paper questions.');
    }
    if (sb.isEmpty) {
      sb.writeln('• Review your weak areas and practice past paper questions daily.');
    }
    return sb.toString().trim();
  }
}
