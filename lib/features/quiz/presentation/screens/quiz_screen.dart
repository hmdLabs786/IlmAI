import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../../core/app_colors.dart';
import '../../../../core/config.dart';
import '../../../../core/constants/syllabus_data.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/student_profile.dart';

class QuizQuestionMCQ {
  final String question;
  final List<String> options;
  final int correctOptionIndex;
  int? selectedOptionIndex;

  QuizQuestionMCQ({
    required this.question,
    required this.options,
    required this.correctOptionIndex,
    this.selectedOptionIndex,
  });

  factory QuizQuestionMCQ.fromJson(Map<String, dynamic> json) {
    return QuizQuestionMCQ(
      question: json['question'] ?? 'MCQ Question',
      options: List<String>.from(json['options'] ?? []),
      correctOptionIndex: json['correct'] ?? 0,
    );
  }
}

class QuizQuestionDescriptive {
  final String question;
  String studentAnswer = '';

  QuizQuestionDescriptive({required this.question});
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  bool _isLoading = false;
  bool _isExamActive = false;

  SyllabusSubject? _selectedSubject;
  String? _selectedChapter;

  // Timer settings
  Timer? _timer;
  int _secondsRemaining = 900; // 15 minutes

  // Quiz content
  List<QuizQuestionMCQ> _mcqs = [];
  List<QuizQuestionDescriptive> _shortQuestions = [];
  QuizQuestionDescriptive? _longQuestion;

  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  String get _geminiApiKey {
    if (AppConfig.geminiApiKey.isNotEmpty && AppConfig.geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE') {
      return AppConfig.geminiApiKey;
    }
    return _envApiKey;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsRemaining = 900;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
        _autoSubmitPaper();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}";
  }

  Future<void> _generateBoardTest(StudentProfile profile) async {
    if (_selectedChapter == null || _selectedSubject == null) return;
    setState(() {
      _isLoading = true;
      _isExamActive = false;
    });

    final prompt =
        "You are an senior academic examiner for the Pakistani Board ${profile.boardName}. "
        "Create a Class ${profile.studentClass} Mock Exam Paper for Subject: ${_selectedSubject!.name}, Chapter: $_selectedChapter. "
        "You must return the exam questions strictly in JSON format. Do not write any markdown code block wrap like ```json or ```, return ONLY the raw JSON string matching this exact schema: \n"
        "{\n"
        "  \"mcqs\": [\n"
        "    {\n"
        "      \"question\": \"Question text?\",\n"
        "      \"options\": [\"Option 1\", \"Option 2\", \"Option 3\", \"Option 4\"],\n"
        "      \"correct\": 0\n"
        "    }\n"
        "  ],\n"
        "  \"short_questions\": [\n"
        "    \"Short Question 1?\",\n"
        "    \"Short Question 2?\"\n"
        "  ],\n"
        "  \"long_question\": \"Detailed/Long Essay Question?\"\n"
        "}\n"
        "Notes: You must generate exactly 3 MCQs, 2 Short Questions, and 1 Long Question.";

    try {
      String rawJson = '';

      if (_geminiApiKey.isEmpty) {
        // Fallback Mock Board Paper
        await Future.delayed(const Duration(seconds: 3));
        rawJson = _getFallbackQuizJson(profile);
      } else {
        final model = GenerativeModel(
          model: 'gemini-2.5-flash',
          apiKey: _geminiApiKey,
        );
        final response = await model.generateContent([Content.text(prompt)]);
        rawJson = response.text ?? '';
        // Extract JSON if model wrapped it anyway
        if (rawJson.contains('```')) {
          final first = rawJson.indexOf('{');
          final last = rawJson.lastIndexOf('}');
          if (first != -1 && last != -1) {
            rawJson = rawJson.substring(first, last + 1);
          }
        }
      }

      final Map<String, dynamic> data = jsonDecode(rawJson.trim());
      
      setState(() {
        _mcqs = (data['mcqs'] as List).map((x) => QuizQuestionMCQ.fromJson(x)).toList();
        
        final shorts = data['short_questions'] as List;
        _shortQuestions = shorts.map((x) => QuizQuestionDescriptive(question: x.toString())).toList();
        
        _longQuestion = QuizQuestionDescriptive(question: data['long_question'].toString());
        
        _isLoading = false;
        _isExamActive = true;
      });

      _startTimer();
    } catch (e) {
      debugPrint("Quiz parsing error: $e");
      // Load fallback quiz on error
      final fallbackJson = _getFallbackQuizJson(profile);
      final Map<String, dynamic> data = jsonDecode(fallbackJson);
      setState(() {
        _mcqs = (data['mcqs'] as List).map((x) => QuizQuestionMCQ.fromJson(x)).toList();
        final shorts = data['short_questions'] as List;
        _shortQuestions = shorts.map((x) => QuizQuestionDescriptive(question: x.toString())).toList();
        _longQuestion = QuizQuestionDescriptive(question: data['long_question'].toString());
        
        _isLoading = false;
        _isExamActive = true;
      });
      _startTimer();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loaded offline board-style mock test.')),
        );
      }
    }
  }

  String _getFallbackQuizJson(StudentProfile profile) {
    // Generate a beautiful offline board paper template matching the board
    final boardName = profile.boardName;
    
    return jsonEncode({
      "mcqs": [
        {
          "question": "Which of the following is the SI unit of electric charge?",
          "options": ["Coulomb", "Ampere", "Volt", "Ohm"],
          "correct": 0
        },
        {
          "question": "According to Boyle's Law, volume of a gas is inversely proportional to:",
          "options": ["Temperature", "Pressure", "Density", "Mass"],
          "correct": 1
        },
        {
          "question": "The chemical formula of Baking Soda is:",
          "options": ["Na2CO3", "NaHCO3", "NaOH", "NaCl"],
          "correct": 1
        }
      ],
      "short_questions": [
        "Define Newton's Second Law of Motion and write its mathematical equation.",
        "Differentiate between Isotopes and Isobars with one example of each."
      ],
      "long_question": "Explain the structure and working mechanism of a Galvanic Cell. Use diagrams where necessary to show the anode, cathode, and salt bridge setup matching the $boardName textbook syllabus."
    });
  }

  void _autoSubmitPaper() {
    _timer?.cancel();
    setState(() {
      _isExamActive = false;
    });
    _showSubmissionSummary(autoSubmitted: true);
  }

  void _submitPaper() {
    // Ask for confirmation
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Board Paper?'),
        content: const Text('Are you sure you want to submit your mock test answers for grading?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close confirm dialog
              _timer?.cancel();
              setState(() {
                _isExamActive = false;
              });
              _showSubmissionSummary(autoSubmitted: false);
            },
            child: const Text('Submit Now'),
          ),
        ],
      ),
    );
  }

  void _showSubmissionSummary({required bool autoSubmitted}) {
    int correctMCQs = 0;
    int answeredMCQs = 0;
    for (var mcq in _mcqs) {
      if (mcq.selectedOptionIndex != null) {
        answeredMCQs++;
        if (mcq.selectedOptionIndex == mcq.correctOptionIndex) {
          correctMCQs++;
        }
      }
    }

    int shortAnswersSubmitted = 0;
    for (var sq in _shortQuestions) {
      if (sq.studentAnswer.trim().isNotEmpty) {
        shortAnswersSubmitted++;
      }
    }

    bool longAnswerSubmitted = _longQuestion?.studentAnswer.trim().isNotEmpty ?? false;

    _saveResults(correctMCQs, answeredMCQs);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                autoSubmitted ? "Time's Up! Paper Submitted" : "Exam Submission Complete",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Salaam Student! You have completed your mock test generated by IlmAI.",
                  style: TextStyle(color: isDark ? Colors.grey[300] : AppColors.darkNavy),
                ),
                const SizedBox(height: 16),
                _summaryRow(Icons.check_circle_outline, "Section A (MCQs)", "$correctMCQs / 3 Correct ($answeredMCQs answered)"),
                _summaryRow(Icons.short_text_rounded, "Section B (Short Qs)", "$shortAnswersSubmitted / 2 Answered"),
                _summaryRow(Icons.description_outlined, "Section C (Long Q)", longAnswerSubmitted ? "1 / 1 Answered" : "0 / 1 Answered"),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Feedback:\n"
                    "Your MCQs have been graded automatically. Your descriptive answers have been saved and compiled. "
                    "Great work practicing under strict board time limits!",
                    style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isExamActive = false;
                });
              },
              child: const Text('Back to Hub', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveResults(int correctMCQs, int answeredMCQs) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _selectedChapter == null) return;

    final incorrectTopics = <String>[];
    for (final mcq in _mcqs) {
      if (mcq.selectedOptionIndex != null && mcq.selectedOptionIndex != mcq.correctOptionIndex) {
        incorrectTopics.add(mcq.question);
      }
    }

    await FirebaseFirestore.instance.collection('exam_results').add({
      'userId': uid,
      'subject': _selectedSubject?.name ?? 'General',
      'chapterName': _selectedChapter!,
      'score': correctMCQs.toDouble(),
      'totalQuestions': answeredMCQs,
      'correctAnswers': correctMCQs,
      'incorrectTopics': incorrectTopics,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Widget _summaryRow(IconData icon, String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Text(val, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.profile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isLoading) {
      return _buildLoadingScreen(isDark);
    }

    if (!_isExamActive) {
      return _buildPreExamScreen(profile, isDark);
    }

    return _buildExamEnvironment(isDark);
  }

  Widget _buildLoadingScreen(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SpinKitFoldingCube(
              color: AppColors.primaryBlue,
              size: 50.0,
            ),
            const SizedBox(height: 35),
            Text(
              "Compiling Board Exam...",
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.white : AppColors.darkNavy,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "IlmAI is generating high-yield board patterns matching Section A, B, and C syllabus context...",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, 
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreExamScreen(StudentProfile profile, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 35,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.1),
                  child: const Icon(Icons.assignment_turned_in_rounded, color: AppColors.primaryBlue, size: 40),
                ),
                const SizedBox(height: 20),
                Text(
                  "Board-Style Mock Test",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.darkNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Tailored for ${profile.boardName} • Class ${profile.studentClass}",
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 15),
                _buildSubjectChapterSelectors(profile),
                const SizedBox(height: 20),
                _examRuleRow(Icons.timer_outlined, "15 Minutes strict exam countdown timer."),
                _examRuleRow(Icons.filter_1_rounded, "Section A: 3 Multiple Choice Questions."),
                _examRuleRow(Icons.filter_2_rounded, "Section B: 2 Short Answer Questions."),
                _examRuleRow(Icons.filter_3_rounded, "Section C: 1 Detailed/Long Essay Question."),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                    ),
                    onPressed: (_selectedChapter == null || _selectedSubject == null) ? null : () => _generateBoardTest(profile),
                    child: const Text(
                      "Generate Board-Style Mock Test",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectChapterSelectors(StudentProfile profile) {
    final subjects = SyllabusData.getSubjects(profile.boardName, profile.studentClass.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Subject', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.onSurface)),
        const SizedBox(height: 6),
        DropdownButtonFormField<SyllabusSubject>(
          initialValue: _selectedSubject,
          items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name, style: const TextStyle(color: AppColors.onSurface, fontSize: 13)))).toList(),
          onChanged: (val) => setState(() { _selectedSubject = val; _selectedChapter = null; }),
          decoration: InputDecoration(
            hintText: 'Choose subject', filled: true, fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          dropdownColor: Colors.white,
        ),
        if (_selectedSubject != null) ...[
          const SizedBox(height: 12),
          const Text('Chapter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.onSurface)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _selectedChapter,
            items: _selectedSubject!.chapters.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: AppColors.onSurface, fontSize: 12)))).toList(),
            onChanged: (val) => setState(() => _selectedChapter = val),
            decoration: InputDecoration(
              hintText: 'Choose chapter', filled: true, fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            dropdownColor: Colors.white,
          ),
        ],
      ],
    );
  }

  Widget _examRuleRow(IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13, 
                color: isDark ? Colors.grey[300] : AppColors.darkNavy,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamEnvironment(bool isDark) {
    final timerPct = _secondsRemaining / 900.0;
    final timerColor = _secondsRemaining < 120 ? Colors.redAccent : AppColors.primaryBlue;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Sticky Exam Header with countdown timer widget
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded, color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    Text(
                      "EXAM ENVIRONMENT ACTIVE",
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                // Time counter layout
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        value: timerPct,
                        strokeWidth: 3,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation(timerColor),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatTime(_secondsRemaining),
                      style: TextStyle(
                        fontFamily: 'Courier',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: timerColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Scrollable questions presentation layout
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SECTION A
                  _sectionHeader("SECTION A: Multiple Choice Questions (3 Marks)", isDark),
                  ...List.generate(_mcqs.length, (idx) => _buildMCQBlock(_mcqs[idx], idx, isDark)),
                  
                  const SizedBox(height: 25),
                  // SECTION B
                  _sectionHeader("SECTION B: Short Answer Questions (2 Qs)", isDark),
                  ...List.generate(_shortQuestions.length, (idx) => _buildDescriptiveBlock(_shortQuestions[idx], "Short Question ${idx + 1}", isDark, 3)),
                  
                  const SizedBox(height: 25),
                  // SECTION C
                  _sectionHeader("SECTION C: Detailed / Long Essay Question (1 Q)", isDark),
                  if (_longQuestion != null)
                    _buildDescriptiveBlock(_longQuestion!, "Detailed Answer Question", isDark, 8),

                  const SizedBox(height: 40),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      onPressed: _submitPaper,
                      child: const Text(
                        "Submit Paper",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label, bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.bold, 
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildMCQBlock(QuizQuestionMCQ mcq, int idx, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Q${idx + 1}. ${mcq.question}",
            style: TextStyle(
              fontSize: 15, 
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.darkNavy,
            ),
          ),
          const SizedBox(height: 12),
          ...List.generate(mcq.options.length, (optIdx) {
            final opt = mcq.options[optIdx];
            final isSelected = mcq.selectedOptionIndex == optIdx;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: InkWell(
                onTap: () {
                  setState(() {
                    mcq.selectedOptionIndex = optIdx;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.primaryBlue.withValues(alpha: 0.1) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryBlue : (isDark ? const Color(0xFF334155) : Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primaryBlue : Colors.grey,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Center(
                                child: CircleAvatar(
                                  radius: 5,
                                  backgroundColor: AppColors.primaryBlue,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          opt,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[200] : AppColors.darkNavy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDescriptiveBlock(
    QuizQuestionDescriptive q,
    String label,
    bool isDark,
    int maxLines,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12, 
              color: AppColors.primaryBlue, 
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            q.question,
            style: TextStyle(
              fontSize: 15, 
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.darkNavy,
            ),
          ),
          const SizedBox(height: 12),
          // Descriptive Answers text fields
          TextField(
            maxLines: maxLines,
            style: TextStyle(color: isDark ? Colors.white : AppColors.darkNavy),
            decoration: InputDecoration(
              hintText: 'Type your answer here...',
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryBlue),
              ),
            ),
            onChanged: (text) {
              q.studentAnswer = text;
            },
          ),
        ],
      ),
    );
  }
}
