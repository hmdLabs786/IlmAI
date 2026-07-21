import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/auth_provider.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  String _formType = 'Suggestion';
  bool _isSubmitting = false;

  static const _faqs = [
    _FAQ(
      question: 'How does the AI Tutor help with Pakistani syllabus?',
      answer:
          'The AI Tutor is powered by Gemini 2.5 Flash with localized board specifications '
          '(BSEK & BIEK), aligning directly with textbook concepts and board marking schemes. '
          'It automatically adapts explanation depth based on your registered class and level.',
    ),
    _FAQ(
      question: 'Can I download my notes and test papers as PDFs?',
      answer:
          'Yes — both AI-generated revision notes and dynamically built mock papers can be '
          'exported to PDF and saved onto your device for offline revision.',
    ),
    _FAQ(
      question: 'How do I change my class or board?',
      answer:
          'Navigate to the Profile tab in the bottom bar, tap Edit, update your class or '
          'board details, and save. The AI immediately re-calibrates all future responses to '
          'your new academic profile.',
    ),
    _FAQ(
      question: 'What is the difference between Test and Exam mode?',
      answer:
          'Test mode lets you customize the number of MCQs, short questions, and long '
          'questions for a focused chapter practice. Exam mode generates a full-length '
          'board-pattern paper matching official BSEK or BIEK distributions.',
    ),
    _FAQ(
      question: 'Why does the News Feed show only BSEK or BIEK news?',
      answer:
          'The news scraper is specifically designed to pull official announcements from the '
          'Board of Secondary Education Karachi (BSEK) and the Board of Intermediate '
          'Education Karachi (BIEK). Only authenticated board-origin content appears.',
    ),
    _FAQ(
      question: 'How do I upgrade my subscription?',
      answer:
          'Tap the menu drawer (top-left) and select Subscription, or go to your Profile '
          'screen and tap Change Plan. Each tier unlocks additional AI features.',
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm(String userName, String userEmail) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance.collection('support').add({
        'userName': userName,
        'userEmail': userEmail,
        'type': _formType,
        'message': _messageController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _messageController.clear();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 24),
                SizedBox(width: 10),
                Text('Submitted!'),
              ],
            ),
            content: Text(
              'JazakAllah! We have received your $_formType. '
              'Our team will review it and respond at $userEmail if needed.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final profile = authProvider.profile;
    final userName = profile?.name ?? 'Student';
    final userEmail = user?.email ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceAltOf(context),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.primary),
                onPressed: () => context.go('/'),
              ),
            ),
          ),
          // ── FAQ section header ──
          _sectionHeader('Frequently Asked Questions', Icons.quiz_outlined),
          const SizedBox(height: 14),

          // ── Styled FAQ tiles ──
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: _faqs.asMap().entries.map((entry) {
                final i = entry.key;
                final faq = entry.value;
                return Column(
                  children: [
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 4),
                        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              'Q${i + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          faq.question,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.onSurface,
                          ),
                        ),
                        iconColor: AppColors.primary,
                        collapsedIconColor: AppColors.onSurfaceMuted,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              faq.answer,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.onSurfaceMuted,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 32),

          // ── Contact form header ──
          _sectionHeader('Contact & Support', Icons.support_agent_rounded),
          const SizedBox(height: 14),

          // ── Support form card ──
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surfaceAltOf(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What is this about?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurfaceMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Form type selector
                  Row(
                    children: [
                      Expanded(child: _typeOption('Suggestion', Icons.lightbulb_outline)),
                      const SizedBox(width: 12),
                      Expanded(child: _typeOption('Complaint', Icons.flag_outlined)),
                      const SizedBox(width: 12),
                      Expanded(child: _typeOption('Bug Report', Icons.bug_report_outlined)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Your Message',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurfaceMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: _messageController,
                    maxLines: 5,
                    style: const TextStyle(color: AppColors.onSurface),
                    decoration: InputDecoration(
                      hintText:
                          'Describe your feedback or issue in detail...',
                      hintStyle:
                          const TextStyle(color: AppColors.onSurfaceMuted),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty
                            ? 'Please enter a message'
                            : null,
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => _submitForm(userName, userEmail),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white),
                            )
                          : const Text(
                              'Submit to Support Team',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _typeOption(String type, IconData icon) {
    final isSelected = _formType == type;
    return InkWell(
      onTap: () => setState(() => _formType = type),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.onSurfaceMuted,
            ),
            const SizedBox(height: 4),
            Text(
              type,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.onSurface,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FAQ {
  final String question;
  final String answer;
  const _FAQ({required this.question, required this.answer});
}
