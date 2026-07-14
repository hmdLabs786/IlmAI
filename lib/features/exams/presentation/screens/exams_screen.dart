import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/config.dart';
import '../../../../core/constants/syllabus_data.dart';
import '../../../../core/subscription/subscription_gate_manager.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/student_profile.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _savedExams = [];
  List<Map<String, dynamic>> _filteredSavedExams = [];
  bool _isLoadingSaved = true;
  final TextEditingController _searchController = TextEditingController();

  int _currentStep = 1;
  SyllabusSubject? _selectedSubject;
  final List<String> _selectedChapters = [];
  String _paperType = 'Test';
  double _mcqCount = 10;
  double _shortCount = 5;
  double _longCount = 2;
  bool _isGenerating = false;
  String _generatedPaperText = "";

  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  String get _geminiApiKey {
    if (AppConfig.geminiApiKey.isNotEmpty && AppConfig.geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE') {
      return AppConfig.geminiApiKey;
    }
    return _envApiKey;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedExams();
    _searchController.addListener(_filterSavedExams);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedExams() async {
    setState(() => _isLoadingSaved = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) { setState(() => _isLoadingSaved = false); return; }
      final snapshot = await FirebaseFirestore.instance
          .collection('exams').where('userId', isEqualTo: uid).get();
      final loaded = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id, 'title': data['title'] ?? 'Exam Paper', 'content': data['content'] ?? '',
          'date': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ?? DateTime.now().toIso8601String(),
          'board': data['board'] ?? '', 'class': data['class'] ?? 9, 'subject': data['subject'] ?? '', 'paperType': data['paperType'] ?? 'Test',
        };
      }).toList();
      loaded.sort((a, b) => b['date'].compareTo(a['date']));
      setState(() { _savedExams = loaded; _filteredSavedExams = loaded; _isLoadingSaved = false; });
    } catch (e) {
      debugPrint("Error loading saved exams: $e");
      setState(() => _isLoadingSaved = false);
    }
  }

  void _filterSavedExams() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) { _filteredSavedExams = _savedExams; }
      else { _filteredSavedExams = _savedExams.where((exam) => (exam['title'] ?? '').toString().toLowerCase().contains(query) || (exam['content'] ?? '').toString().toLowerCase().contains(query)).toList(); }
    });
  }

  void _generatePaper(StudentProfile profile) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final tier = authProvider.subscriptionTier;

    // Gate: free tier cannot generate full exam (short + long)
    if (SubscriptionGateManager.isFree(tier) && _paperType == 'Exam') {
      SubscriptionGateManager.showFullExamGatedDialog(context);
      return;
    }

    // Gate: daily exam limit
    if (!await SubscriptionGateManager.canGenerateExam(uid, tier)) {
      final max = SubscriptionGateManager.dailyExamLimit(tier);
      if (mounted) SubscriptionGateManager.showLimitDialog(context, tier, 'Exam Generation', max);
      return;
    }

    setState(() { _isGenerating = true; _currentStep = 3; });

    final chaptersList = _selectedChapters.join(', ');
    String prompt = _paperType == 'Test'
        ? "You are a senior board examiner for ${profile.boardName}. Generate a physics/chemistry/biology/math Test Paper for Class ${profile.studentClass} under the ${profile.boardName} board syllabus, specifically for the chapters: $chaptersList. The test must contain exactly:\n- ${_mcqCount.toInt()} Multiple Choice Questions (with options A, B, C, D)\n- ${_shortCount.toInt()} Short Answer Questions\n- ${_longCount.toInt()} Detailed Long Questions\n\nProvide the paper in a professional, well-formatted structured textbook layout. Include a clean header with 'Marks', 'Time Allowed: 1 Hour', and clear sections: Section A (MCQs), Section B (Short Questions), and Section C (Long Questions)."
        : "You are a senior board examiner for ${profile.boardName}. Generate a full-length, board pattern based Board Style Exam Paper for Class ${profile.studentClass} under the ${profile.boardName} board syllabus for the chapters: $chaptersList. It must strictly follow the official ${profile.boardName} marking scheme structure, sections, and distribution. Provide standard instructions and clear Section A (MCQs), Section B (Short Qs), and Section C (Detailed Qs) with appropriate marks distribution.";

    try {
      if (_geminiApiKey.isEmpty) {
        await Future.delayed(const Duration(seconds: 3));
        _generatedPaperText = "==================================================\n                 ILMVERSE MOCK CENTRE\n  ${profile.boardName} BOARD EXAMINATION - CLASS ${profile.studentClass}\n  SUBJECT: ${_selectedSubject?.name} | TIME: 2.5 HOURS\n==================================================\n\nSECTION A: MULTIPLE CHOICE QUESTIONS (MCQs)\n--------------------------------------------------\nQ1. Which of the following defines a fundamental quantity?\n   A) Velocity    B) Mass    C) Force    D) Acceleration\n\nQ2. The rate of change of momentum is equal to:\n   A) Power    B) Work    C) Force    D) Energy\n\nSECTION B: SHORT QUESTIONS\n--------------------------------------------------\nQ1. Differentiate between Scalar and Vector quantities.\nQ2. State Newton's First Law of Motion and give one example.\n\nSECTION C: DETAILED QUESTIONS\n--------------------------------------------------\nQ1. Derive the equations of motion for a body moving with uniform acceleration.\nQ2. Explain the construction and working of a hydraulic lift based on Pascal's Principle.";
      } else {
        final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiApiKey);
        final response = await model.generateContent([Content.text(prompt)]);
        _generatedPaperText = response.text ?? "Failed to generate exam paper content.";
      }
      await _savePaper(profile);
      await SubscriptionGateManager.incrementDailyUsage(uid, 'examsGeneratedCount');
      setState(() => _currentStep = 4);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating paper: $e')));
    } finally { if (mounted) setState(() => _isGenerating = false); }
  }

  Future<void> _savePaper(StudentProfile profile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('exams').add({
      'userId': uid, 'title': '${_selectedSubject?.name ?? 'Subject'} - ${_paperType == 'Test' ? 'Test' : 'Exam'}',
      'content': _generatedPaperText, 'createdAt': FieldValue.serverTimestamp(),
      'board': profile.boardName, 'class': profile.studentClass, 'subject': _selectedSubject?.name ?? '', 'paperType': _paperType,
    });
    await _loadSavedExams();
  }

  Future<void> _downloadPdf() async {
    final pdf = pw.Document();
    try {
      final font = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      final italicFont = await PdfGoogleFonts.robotoItalic();
      pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, theme: pw.ThemeData.withFont(base: font, bold: boldFont, italic: italicFont), build: (pw.Context context) {
        return [
          pw.Text("Generated by IlmAI Tutor", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
          pw.SizedBox(height: 8), pw.Divider(), pw.SizedBox(height: 12),
          ..._generatedPaperText.split('\n').map((line) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) return pw.SizedBox(height: 6);
            if (trimmed.startsWith('==') || trimmed.startsWith('--')) return pw.Divider();
            if (trimmed.startsWith('SECTION') || trimmed.startsWith('Q')) return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Text(trimmed, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));
            return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text(trimmed, style: const pw.TextStyle(fontSize: 11)));
          }),
        ];
      }));
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.profile;
    if (profile == null) return const Center(child: CircularProgressIndicator());
    final subjects = SyllabusData.getSubjects(profile.boardName, profile.studentClass.toString());

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false,
          bottom: TabBar(controller: _tabController, indicatorColor: AppColors.primary, labelColor: AppColors.primary, unselectedLabelColor: AppColors.onSurfaceMuted, tabs: const [Tab(text: "Generate Papers"), Tab(text: "Saved Papers")]),
        ),
      ),
      body: TabBarView(controller: _tabController, children: [
        _buildGeneratorTab(subjects, profile),
        _buildSavedTab(),
      ]),
    );
  }

  Widget _buildGeneratorTab(List<SyllabusSubject> subjects, StudentProfile profile) {
    return Column(
      children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AppColors.primary.withValues(alpha: 0.08),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Exams & Tests Builder", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
              Text("Step $_currentStep of 4", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
        ),
        Expanded(child: _buildCurrentStepContent(subjects, profile)),
      ],
    );
  }

  Widget _buildSavedTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: const InputDecoration(
                hintText: "Search saved exam papers...", prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingSaved
              ? const Center(child: CircularProgressIndicator())
              : _filteredSavedExams.isEmpty
                  ? const Center(child: Text("No saved exam papers", style: TextStyle(color: AppColors.onSurfaceMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSavedExams.length,
                      itemBuilder: (context, index) {
                        final exam = _filteredSavedExams[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                          child: ListTile(
                            title: Text(exam['title'] ?? 'Exam Paper', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                            subtitle: Text(exam['date'] != null ? DateFormat('MMM d, yyyy').format(DateTime.parse(exam['date'])) : ''),
                            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
                            onTap: () {
                              showModalBottomSheet(
                                context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                                builder: (context) => Container(
                                  height: MediaQuery.of(context).size.height * 0.8,
                                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(exam['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                            Row(children: [
                                              IconButton(icon: const Icon(Icons.download, color: Colors.green), onPressed: () {
                                                _generatedPaperText = exam['content'] ?? '';
                                                _downloadPdf();
                                              }),
                                              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                                            ]),
                                          ],
                                        ),
                                      ),
                                      const Divider(),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(20),
                                          child: SelectableText(exam['content'] ?? '', style: const TextStyle(fontFamily: 'Courier', fontSize: 13, color: AppColors.onSurface, height: 1.5)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent(List<SyllabusSubject> subjects, StudentProfile profile) {
    if (_currentStep == 1) {
      return ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final sub = subjects[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: const Icon(Icons.menu_book_rounded, color: AppColors.primary)),
              title: Text(sub.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
              subtitle: Text("${sub.chapters.length} chapters available"),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () { setState(() { _selectedSubject = sub; _selectedChapters.clear(); _currentStep = 2; }); },
            ),
          );
        },
      );
    } else if (_currentStep == 2) {
      final sub = _selectedSubject!;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _currentStep = 1)),
              Text("Select Chapters (${sub.name})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface)),
            ]),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: sub.chapters.length,
              itemBuilder: (context, index) {
                final ch = sub.chapters[index];
                final isChecked = _selectedChapters.contains(ch);
                return CheckboxListTile(
                  title: Text(ch, style: const TextStyle(color: AppColors.onSurface, fontSize: 14)),
                  value: isChecked,
                  activeColor: AppColors.primary,
                  onChanged: (val) { setState(() { if (val == true) { _selectedChapters.add(ch); } else { _selectedChapters.remove(ch); } }); },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _selectedChapters.isEmpty ? null : () => setState(() => _currentStep = 3),
                child: const Text("Continue to Paper Settings", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      );
    } else if (_currentStep == 3) {
      if (_isGenerating) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 50, height: 50, child: CircularProgressIndicator(color: AppColors.primary)),
              const SizedBox(height: 24),
              const Text("AI is Generating Paper...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.onSurface)),
              const SizedBox(height: 8),
              Text("Formulating syllabus questions according to ${profile.boardName} formats", style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
            ],
          ),
        );
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _currentStep = 2)), const Text("Paper Settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface))]),
            const SizedBox(height: 20),
            const Text("Select Paper Type", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: ChoiceChip(label: const Center(child: Text("Test (Customizable)")), selected: _paperType == 'Test', onSelected: (val) { if (val) setState(() => _paperType = 'Test'); })),
              const SizedBox(width: 12),
              Expanded(child: ChoiceChip(label: const Center(child: Text("Full Exam (Board Pattern)")), selected: _paperType == 'Exam', onSelected: (val) { if (val) setState(() => _paperType = 'Exam'); })),
            ]),
            const SizedBox(height: 25),
            if (_paperType == 'Test') ...[
              Text("MCQs Count: ${_mcqCount.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(value: _mcqCount, min: 0, max: 30, divisions: 30, activeColor: AppColors.primary, onChanged: (val) => setState(() => _mcqCount = val)),
              const SizedBox(height: 15),
              Text("Short Questions Count: ${_shortCount.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(value: _shortCount, min: 0, max: 15, divisions: 15, activeColor: AppColors.primary, onChanged: (val) => setState(() => _shortCount = val)),
              const SizedBox(height: 15),
              Text("Long Questions Count: ${_longCount.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(value: _longCount, min: 0, max: 10, divisions: 10, activeColor: AppColors.primary, onChanged: (val) => setState(() => _longCount = val)),
              const SizedBox(height: 25),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Text("Generates a complete, authentic full-length exam style paper matching ${profile.boardName} standard distributions for Matric / Intermediate classes.", style: const TextStyle(color: AppColors.primary, fontSize: 13, height: 1.4)),
              ),
              const SizedBox(height: 30),
            ],
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => _generatePaper(profile),
              child: const Text("Create Paper with AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ],
        ),
      );
    } else {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _currentStep = 1)), const Text("Paper Preview", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface))]),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _downloadPdf,
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
                  label: const Text("Export PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: SingleChildScrollView(
                child: SelectableText(_generatedPaperText, style: const TextStyle(fontFamily: 'Courier', fontSize: 13, color: AppColors.onSurface)),
              ),
            ),
          ),
        ],
      );
    }
  }
}
