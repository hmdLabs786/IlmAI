import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/config.dart';
import '../models/scanned_solution.dart';

class SnapSolveService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  static const String _modelName = 'gemini-2.5-flash';

  User? get _currentUser => _auth.currentUser;
  String get _uid => _currentUser?.uid ?? '';

  /// Pick an image from camera or gallery
  Future<XFile?> pickImage({ImageSource source = ImageSource.camera}) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      return image;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Save image locally and return the local path
  Future<String> saveImageLocally(File imageFile) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final scansDir = Directory('${dir.path}/scanned_problems');
      if (!await scansDir.exists()) {
        await scansDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final localPath = '${scansDir.path}/$timestamp.jpg';
      await imageFile.copy(localPath);
      return localPath;
    } catch (e) {
      throw Exception('Failed to save image: $e');
    }
  }

  /// Send image to Gemini for OCR and solution
  Future<Map<String, String>> analyzeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();

      final model = GenerativeModel(
        model: _modelName,
        apiKey: _getGeminiApiKey(),
      );

      final prompt = TextPart('''Extract this academic question or formula from the image and provide a clear, step-by-step educational breakdown for a high school student.

Format your response as:
1. **Extracted Question/Formula**: (what you see in the image)
2. **Subject**: (identify the subject - Mathematics, Physics, Chemistry, Biology, etc.)
3. **Step-by-Step Solution**: (clear numbered steps with explanations)
4. **Final Answer**: (the final result)

Be thorough but concise. Use proper mathematical notation where applicable.''');

      final response = await model.generateContent([
        Content.multi([
          prompt,
          DataPart('image/jpeg', bytes),
        ]),
      ]);

      final text = response.text ?? '';

      String extractedText = '';
      String aiSolution = '';
      String subject = 'General';

      if (text.isNotEmpty) {
        final lines = text.split('\n');
        for (final line in lines) {
          if (line.toLowerCase().contains('extracted') || line.toLowerCase().contains('question')) {
            extractedText = line.replaceAll(RegExp(r'[0-9]+\.\s*\*\*.*?\*\*:\s*'), '');
          } else if (line.toLowerCase().contains('subject')) {
            subject = line.replaceAll(RegExp(r'[0-9]+\.\s*\*\*.*?\*\*:\s*'), '');
          } else if (line.toLowerCase().contains('step') || line.toLowerCase().contains('solution')) {
            aiSolution = text;
            break;
          }
        }

        if (extractedText.isEmpty) extractedText = 'Image content analyzed';
        if (aiSolution.isEmpty) aiSolution = text;
      }

      return {
        'extractedText': extractedText,
        'aiSolution': aiSolution,
        'subject': subject,
      };
    } catch (e) {
      throw Exception('Failed to analyze image with AI: $e');
    }
  }

  /// Save scanned solution to Firestore
  Future<ScannedSolution> saveSolution({
    required String imageUrl,
    required String extractedText,
    required String aiSolution,
    required String subject,
  }) async {
    if (_uid.isEmpty) throw Exception('User not authenticated');

    try {
      final solution = ScannedSolution(
        imageUrl: imageUrl,
        extractedText: extractedText,
        aiSolution: aiSolution,
        subject: subject,
        timestamp: Timestamp.now(),
        userId: _uid,
      );

      final docRef = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('scanned_solutions')
          .add(solution.toFirestore());

      return solution.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('Failed to save solution: $e');
    }
  }

  /// Get user's scanned solutions history (one-time fetch)
  Future<List<ScannedSolution>> getHistory() async {
    if (_uid.isEmpty) throw Exception('User not authenticated');

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('scanned_solutions')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ScannedSolution.fromFirestore(doc))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get user's scanned solutions history as a real-time stream
  Stream<List<ScannedSolution>> getScannedSolutionsStream() {
    if (_uid.isEmpty) throw Exception('User not authenticated');

    return _firestore
        .collection('users')
        .doc(_uid)
        .collection('scanned_solutions')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ScannedSolution.fromFirestore(doc))
            .toList());
  }

  Future<int> getScansTodayCount() async {
    if (_uid.isEmpty) return 0;

    try {
      final now = DateTime.now();
      final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
      final endOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));

      final snapshot = await _firestore
          .collection('users')
          .doc(_uid)
          .collection('scanned_solutions')
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('timestamp', isLessThanOrEqualTo: endOfDay)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Delete a scanned solution
  Future<void> deleteSolution(String solutionId) async {
    if (_uid.isEmpty) throw Exception('User not authenticated');

    try {
      await _firestore
          .collection('users')
          .doc(_uid)
          .collection('scanned_solutions')
          .doc(solutionId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete solution: $e');
    }
  }

  String _getGeminiApiKey() {
    final key = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (key.isNotEmpty) return key;
    return AppConfig.geminiApiKey;
  }
}
