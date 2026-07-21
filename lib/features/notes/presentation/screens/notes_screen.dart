import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/app_colors.dart';
import '../../../../core/widgets/smart_text.dart';
import '../../../../core/config.dart';
import '../../../../core/subscription/subscription_gate_manager.dart';
import '../../../../core/constants/syllabus_data.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../models/student_profile.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _savedNotes = [];
  List<Map<String, dynamic>> _filteredSavedNotes = [];
  bool _isLoadingSaved = true;
  final TextEditingController _searchController = TextEditingController();

  SyllabusSubject? _selectedSubject;
  String? _selectedChapter;
  bool _isGeneratingNote = false;
  String _generatedNoteText = "";

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
    _loadSavedNotes();
    _searchController.addListener(_filterSavedNotes);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedNotes() async {
    setState(() => _isLoadingSaved = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) { setState(() => _isLoadingSaved = false); return; }
      final snapshot = await FirebaseFirestore.instance.collection('notes').where('userId', isEqualTo: uid).get();
      final loaded = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id, 'title': data['title'] ?? 'Revision Note', 'content': data['content'] ?? '',
          'date': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String() ?? DateTime.now().toIso8601String(),
          'board': data['board'] ?? '', 'class': data['class'] ?? 9, 'subject': data['subject'] ?? '', 'chapter': data['chapter'] ?? '',
        };
      }).toList();
      loaded.sort((a, b) => b['date'].compareTo(a['date']));
      setState(() { _savedNotes = loaded; _filteredSavedNotes = loaded; _isLoadingSaved = false; });
    } catch (e) {
      debugPrint("Error loading saved notes: $e");
      setState(() => _isLoadingSaved = false);
    }
  }

  void _filterSavedNotes() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) { _filteredSavedNotes = _savedNotes; }
      else { _filteredSavedNotes = _savedNotes.where((note) => (note['title'] ?? '').toString().toLowerCase().contains(query) || (note['content'] ?? '').toString().toLowerCase().contains(query)).toList(); }
    });
  }

  Future<void> _generateSyllabusNotes(StudentProfile profile) async {
    if (_selectedChapter == null || _selectedSubject == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final auth = context.read<AuthProvider>();
    final tier = auth.subscriptionTier;

    if (!await SubscriptionGateManager.canGenerateNotes(uid, tier)) {
      final max = SubscriptionGateManager.dailyNotesLimit(tier);
      if (mounted) SubscriptionGateManager.showLimitDialog(context, tier, 'Notes Generation', max);
      return;
    }

    setState(() { _isGeneratingNote = true; _generatedNoteText = ""; });

    final prompt = "You are a senior academic teacher specializing in Pakistani educational boards (${profile.boardName}). Write highly detailed revision notes for Class ${profile.studentClass} under the ${profile.boardName} board syllabus, specifically for the Subject: ${_selectedSubject!.name}, Chapter: $_selectedChapter. Use structured explanations, headings, key terms, definitions, bullet points, exam-focused tips, and neat formatting.";

    try {
      if (_geminiApiKey.isEmpty) {
        await Future.delayed(const Duration(seconds: 3));
        _generatedNoteText = "# Study Notes: $_selectedChapter\n## Subject: ${_selectedSubject!.name} | Class: ${profile.studentClass} | Board: ${profile.boardName}\n\n### 1. Key Definitions & Concepts\nThis is a premium mockup representation of study notes generated by Gemini for $_selectedChapter.\n- **Important Term A**: Standard definition matching textbooks.\n- **Important Term B**: Highly expected term in final boards.\n\n### 2. High-Yield Exam Revision Tips\n- Focus on solving previous 5-year paper numericals.\n- Draw clear diagrams for descriptive items to secure maximum marks.";
      } else {
        final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _geminiApiKey);
        final response = await model.generateContent([Content.text(prompt)]);
        _generatedNoteText = response.text ?? "Failed to generate study notes.";
      }
      await _saveGeneratedNote(profile);
      await SubscriptionGateManager.incrementDailyUsage(uid, 'notesGeneratedCount');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating notes: $e')));
    } finally { if (mounted) setState(() => _isGeneratingNote = false); }
  }

  Future<void> _saveGeneratedNote(StudentProfile profile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('notes').add({
      'userId': uid, 'title': '${_selectedSubject?.name ?? 'Subject'} - $_selectedChapter', 'content': _generatedNoteText,
      'createdAt': FieldValue.serverTimestamp(), 'board': profile.boardName,
      'class': profile.studentClass, 'subject': _selectedSubject?.name ?? '', 'chapter': _selectedChapter ?? '',
    });
    if (mounted) await _loadSavedNotes();
  }

  Future<void> _downloadNoteAsPdf() async {
    final pdf = pw.Document();
    try {
      final font = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      final italicFont = await PdfGoogleFonts.robotoItalic();
      pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4, theme: pw.ThemeData.withFont(base: font, bold: boldFont, italic: italicFont), build: (pw.Context context) {
        return [
          pw.Text("Generated by IlmAI Study Notes", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
          pw.SizedBox(height: 8), pw.Divider(), pw.SizedBox(height: 12),
          ..._generatedNoteText.split('\n').map((line) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) return pw.SizedBox(height: 6);
            if (trimmed.startsWith('###')) return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 6), child: pw.Text(trimmed.replaceFirst('###', '').trim(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
            if (trimmed.startsWith('##')) return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text(trimmed.replaceFirst('##', '').trim(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)));
            if (trimmed.startsWith('#')) return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 10), child: pw.Text(trimmed.replaceFirst('#', '').trim(), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)));
            if (trimmed.startsWith('-')) return pw.Padding(padding: const pw.EdgeInsets.only(left: 12, bottom: 4), child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text("• ", style: const pw.TextStyle(fontSize: 12)), pw.Expanded(child: pw.Text(trimmed.replaceFirst('-', '').trim(), style: const pw.TextStyle(fontSize: 12)))]));
            return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Text(trimmed, style: const pw.TextStyle(fontSize: 12)));
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: AppBar(
          backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceOf(context),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.primary),
                onPressed: () => context.go('/'),
              ),
            ),
          ),
          bottom: TabBar(controller: _tabController, indicatorColor: AppColors.primary, labelColor: AppColors.primary, unselectedLabelColor: AppColors.onSurfaceMuted, tabs: const [Tab(text: "Generate Notes"), Tab(text: "Saved Notes")]),
        ),
      ),
      body: TabBarView(controller: _tabController, children: [
        _buildGeneratorTab(profile),
        _buildSavedTab(),
      ]),
    );
  }

  Widget _buildGeneratorTab(StudentProfile profile) {
    if (_isGeneratingNote) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 70, height: 70, child: CircularProgressIndicator(color: AppColors.primary)),
          const SizedBox(height: 24),
          const Text("AI is Writing Detailed Notes...", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.onSurface)),
          const SizedBox(height: 8),
          Text("Structuring explanations based on Class ${profile.studentClass} ${profile.boardName} textbooks", style: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 12)),
        ],
      ));
    }

    if (_generatedNoteText.isNotEmpty) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => setState(() => _generatedNoteText = ""),
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 16),
                  label: const Text("Back", style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: _downloadNoteAsPdf,
                  icon: const Icon(Icons.download, color: Colors.white, size: 16),
                  label: const Text("Export PDF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surfaceOf(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.4))),
              child: SingleChildScrollView(
                child: SelectableText(_generatedNoteText, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.onSurface)),
              ),
            ),
          ),
        ],
      );
    }

    final subjects = SyllabusData.getSubjects(profile.boardName, profile.studentClass.toString());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("1. Select Subject", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.onSurface)),
          const SizedBox(height: 10),
          DropdownButtonFormField<SyllabusSubject>(
            initialValue: _selectedSubject,
            items: subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name, style: const TextStyle(color: AppColors.onSurface)))).toList(),
            onChanged: (val) { setState(() { _selectedSubject = val; _selectedChapter = null; }); },
            decoration: _inputDecoration("Choose Subject"),
            dropdownColor: Colors.white,
          ),
          const SizedBox(height: 25),
          if (_selectedSubject != null) ...[
            const Text("2. Select Chapter", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.onSurface)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedChapter,
              items: _selectedSubject!.chapters.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: AppColors.onSurface, fontSize: 13)))).toList(),
              onChanged: (val) { setState(() => _selectedChapter = val); },
              decoration: _inputDecoration("Choose Chapter"),
              dropdownColor: Colors.white,
            ),
            const SizedBox(height: 35),
            SizedBox(width: double.infinity, height: 52, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _selectedChapter == null ? null : () => _generateSyllabusNotes(profile),
              child: const Text("Generate Revision Notes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )),
          ]
        ],
      ),
    );
  }

  Widget _buildSavedTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            decoration: BoxDecoration(color: AppColors.surfaceOf(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.4))),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: const InputDecoration(
                hintText: "Search saved chat sheets...", prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingSaved
              ? const Center(child: CircularProgressIndicator())
              : _filteredSavedNotes.isEmpty
                  ? const Center(child: Text("No saved revision sheets", style: TextStyle(color: AppColors.onSurfaceMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredSavedNotes.length,
                      itemBuilder: (context, index) {
                        final note = _filteredSavedNotes[index];
                        return _buildNoteCard(note);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    return Dismissible(
      key: ValueKey(note['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) async {
        final id = note['id'] as String;
        await FirebaseFirestore.instance.collection('notes').doc(id).delete();
        _filteredSavedNotes.removeAt(_filteredSavedNotes.indexWhere((n) => n['id'] == id));
        await _loadSavedNotes();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: AppColors.surfaceOf(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.4))),
        child: Material(type: MaterialType.transparency, child: ListTile(
          title: Text(note['title'] ?? 'Revision Note', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
          subtitle: Text(note['date'] != null ? DateFormat('MMM d, yyyy').format(DateTime.parse(note['date'])) : ''),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
          onTap: () {
            showModalBottomSheet(
              context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
              builder: (context) => Container(
                height: MediaQuery.of(context).size.height * 0.8,
                decoration: BoxDecoration(color: AppColors.surfaceOf(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        SmartText(note['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ]),
                    ),
                    const Divider(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: SmartText(note['content'] ?? '', style: const TextStyle(fontSize: 14, color: AppColors.onSurface, height: 1.5)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint, filled: true, fillColor: AppColors.surfaceOf(context),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.4))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.4))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
