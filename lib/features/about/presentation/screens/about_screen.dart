import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceOf(context),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: const Icon(Icons.auto_awesome, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'IlmAI',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Version 1.2.7', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ── Mission ──
                  _section(
                    context,
                    icon: Icons.lightbulb_outline_rounded,
                    iconColor: AppColors.primary,
                    label: 'MISSION',
                    title: 'Education for Every\nKarachi Student',
                    body: 'IlmAI delivers personalised, board-aligned academic support to every '
                        'Matric and Intermediate student in Karachi. Our AI adapts to the exact '
                        'BSEK and BIEK syllabus so every note, test, and answer fits your class.',
                  ),
                  const SizedBox(height: 16),

                  // ── Features ──
                  _featureCard(
                    context,
                    icon: Icons.psychology_rounded,
                    color: AppColors.primary,
                    title: 'AI Tutor',
                    desc: 'Chat with Gemini 2.5 Flash, tuned to your board syllabus and learning level.',
                  ),
                  const SizedBox(height: 10),
                  _featureCard(
                    context,
                    icon: Icons.auto_stories_rounded,
                    color: const Color(0xFFD97706),
                    title: 'Smart Notes',
                    desc: 'Generate syllabus-aligned revision notes with headings, definitions, and exam tips. Export to PDF.',
                  ),
                  const SizedBox(height: 10),
                  _featureCard(
                    context,
                    icon: Icons.assignment_turned_in_rounded,
                    color: const Color(0xFF7C3AED),
                    title: 'Exam Generator',
                    desc: 'Create board-pattern mock papers with MCQs, short questions, and long questions per chapter.',
                  ),
                  const SizedBox(height: 10),
                  _featureCard(
                    context,
                    icon: Icons.library_books_rounded,
                    color: const Color(0xFF059669),
                    title: 'PDF Library',
                    desc: 'Browse and download Sindh Board textbooks organised by board, class, and subject.',
                  ),
                  const SizedBox(height: 10),
                  _featureCard(
                    context,
                    icon: Icons.camera_alt_rounded,
                    color: const Color(0xFFDC2626),
                    title: 'Snap & Solve',
                    desc: 'Scan a question with your camera and get an instant step-by-step solution.',
                  ),
                  const SizedBox(height: 10),
                  _featureCard(
                    context,
                    icon: Icons.leaderboard_rounded,
                    color: const Color(0xFF0891B2),
                    title: 'Leaderboard',
                    desc: 'Compete with peers and track your weekly progress across exams and quizzes.',
                  ),
                  const SizedBox(height: 10),
                  _featureCard(
                    context,
                    icon: Icons.notifications_active_rounded,
                    color: const Color(0xFFEA580C),
                    title: 'Board Alerts',
                    desc: 'Get real-time BSEK and BIEK announcements, result dates, and schedule updates.',
                  ),
                  const SizedBox(height: 10),
                  _featureCard(
                    context,
                    icon: Icons.quiz_rounded,
                    color: const Color(0xFF6366F1),
                    title: 'Mock Quiz',
                    desc: 'Test your knowledge with timed quizzes that match your syllabus chapters.',
                  ),

                  const SizedBox(height: 16),

                  // ── Developer ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAltOf(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.borderOf(context)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, Color(0xFF0F2460)],
                                ),
                              ),
                              child: const Center(
                                child: Text('H', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Habban Madani', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context))),
                                  SizedBox(height: 3),
                                  Text('Lead Developer', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMutedOf(context))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: iconColor)),
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context), height: 1.2)),
          const SizedBox(height: 10),
          Text(body, style: TextStyle(fontSize: 14, color: AppColors.onSurfaceMutedOf(context), height: 1.6)),
        ],
      ),
    );
  }

  Widget _featureCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context))),
                const SizedBox(height: 3),
                Text(desc, style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMutedOf(context), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
