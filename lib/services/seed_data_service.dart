import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SeedDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _librarySeedKey = 'library_seeded_v4';
  static const String _newsSeedKey = 'news_seeded_v2';

  /// Seeds all data only if it hasn't been seeded before.
  Future<void> seedAll() async {
    final prefs = await SharedPreferences.getInstance();

    final librarySeeded = prefs.getBool(_librarySeedKey) ?? false;
    final newsSeeded = prefs.getBool(_newsSeedKey) ?? false;

    if (!librarySeeded) {
      await _seedLibrary();
      await prefs.setBool(_librarySeedKey, true);
    }

    if (!newsSeeded) {
      await _seedNewsFeed();
      await prefs.setBool(_newsSeedKey, true);
    }
  }

  /// Force re-seed (useful for debugging/admin)
  Future<void> forceReseedAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_librarySeedKey);
    await prefs.remove(_newsSeedKey);
    await seedAll();
  }

  Future<void> _seedLibrary() async {
    final batch = _db.batch();
    final samplePdf = 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf';

    void addBook(String board, String cls, String subject, String title) {
      final id = '${board}_${cls}_${subject.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      final ref = _db.doc('boards/$board/classes/$cls/subjects/$subject/books/$id');
      batch.set(ref, {'title': title, 'pdfUrl': samplePdf, 'pageCount': 0});
    }

    // ── BSEK (SSC) — Class 9 ──
    addBook('BSEK', '9', 'English', 'Secondary Stage English Book One');
    addBook('BSEK', '9', 'Islamiat', 'Islamic Studies (Ethics for non-Muslim students)');
    addBook('BSEK', '9', 'Mathematics', 'Mathematics Book One (Science Group)');
    addBook('BSEK', '9', 'Physics', 'Physics Book One');
    addBook('BSEK', '9', 'Chemistry', 'Chemistry Book One');
    addBook('BSEK', '9', 'Biology', 'Biology Book One');
    addBook('BSEK', '9', 'Computer Science', 'Computer Science Book One');

    // ── BSEK (SSC) — Class 10 ──
    addBook('BSEK', '10', 'English', 'Secondary Stage English Book Two');
    addBook('BSEK', '10', 'Pakistan Studies', 'Pakistan Studies');
    addBook('BSEK', '10', 'Sindhi', 'Sindhi Salees / Asan Sindhi');
    addBook('BSEK', '10', 'Mathematics', 'Mathematics Book Two (Science Group)');
    addBook('BSEK', '10', 'Physics', 'Physics Book Two');
    addBook('BSEK', '10', 'Chemistry', 'Chemistry Book Two');
    addBook('BSEK', '10', 'Biology', 'Biology Book Two');
    addBook('BSEK', '10', 'Computer Science', 'Computer Science Book Two');

    // ── BIEK (HSC) — Class 11 ──
    addBook('BIEK', '11', 'English', 'Intermediate English Book I');
    addBook('BIEK', '11', 'Islamiat', 'Islamic Studies (Ethics for non-Muslim students)');
    addBook('BIEK', '11', 'Physics', 'Fundamentals of Physics for Class XI');
    addBook('BIEK', '11', 'Chemistry', 'Chemistry for Class XI');
    addBook('BIEK', '11', 'Mathematics', 'Mathematics for Class XI');
    addBook('BIEK', '11', 'Biology', 'Biology for Class XI');

    // ── BIEK (HSC) — Class 12 ──
    addBook('BIEK', '12', 'English', 'Comprehensive English Book Two');
    addBook('BIEK', '12', 'Pakistan Studies', 'Pakistan Studies for Class XI / XII');
    addBook('BIEK', '12', 'Physics', 'Physics for Class XII');
    addBook('BIEK', '12', 'Chemistry', 'Chemistry for Class XII');
    addBook('BIEK', '12', 'Mathematics', 'Mathematics for Class XII');
    addBook('BIEK', '12', 'Computer Science', 'Computer Science for Class XII');
    addBook('BIEK', '12', 'Biology', 'Biology for Class XII (Botany & Zoology)');

    await batch.commit();
  }

  Future<void> _seedNewsFeed() async {
    final batch = _db.batch();
    final newsRef = _db.collection('news_feed');

    // Clean up existing news_feed collection to avoid duplicate/stale documents
    final existingDocs = await newsRef.get();
    for (final doc in existingDocs.docs) {
      batch.delete(doc.reference);
    }

    final sampleDocs = [
      {
        'title': 'BSEK Class 9 & 10 Annual Date Sheet 2026',
        'content': 'The Board of Secondary Education Karachi (BSEK) has officially released the exam schedule for SSC Part I & II (Class 9 & 10) Annual Examinations. Exams are scheduled to begin on May 5th, 2026. Theory papers will run in double shifts: Science group in morning and General group in evening shifts.',
        'timestamp': FieldValue.serverTimestamp(),
        'category': 'BSEK Matric',
      },
      {
        'title': 'BIEK Intermediate Roll Number Slips Out',
        'content': 'The Board of Intermediate Education Karachi (BIEK) has uploaded private and regular candidates\' roll number slips for HSC Part I & II (Class 11 & 12) Annual Exams. Regular students can collect their slips from their respective colleges, while private candidates can download them online.',
        'timestamp': FieldValue.serverTimestamp(),
        'category': 'BIEK Inter',
      },
      {
        'title': 'BSEK SSC Part II (Class 10) General Result 2025 Announced',
        'content': 'BSEK has officially announced the Matriculation General Group results for the session 2025. The overall passing rate is 68.4%. Top three positions were secured by female candidates of private educational networks. Result books are available on the BSEK online portal.',
        'timestamp': FieldValue.serverTimestamp(),
        'category': 'BSEK Results',
      },
      {
        'title': 'Sindh Board Announces Uniform Grading System for 2026',
        'content': 'The Sindh Education & Literacy Department has mandated a transition to a standardized 10-point GPA-based grading system for Matric and Intermediate Boards, completely phasing out individual marks sheets beginning in the 2026 annual examination session.',
        'timestamp': FieldValue.serverTimestamp(),
        'category': 'Policy Update',
      },
    ];

    for (final doc in sampleDocs) {
      final docRef = newsRef.doc();
      batch.set(docRef, doc);
    }

    await batch.commit();
  }
}