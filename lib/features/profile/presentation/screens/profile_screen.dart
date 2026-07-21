import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/student_profile.dart';
import '../../../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  int _selectedClass = 9;
  StudentBoard _selectedBoard = StudentBoard.bsek;
  StudentLevel _selectedLevel = StudentLevel.average;

  bool _isEditing = false;
  bool _isSaving = false;
  String? _loadedSignature;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromProvider();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncFromProvider() {
    final profile = context.read<AuthProvider>().profile;
    if (profile == null) return;
    final signature = '${profile.name}|${profile.studentClass}|${profile.board.name}|${profile.level.name}';
    if (_loadedSignature == signature) return;
    _loadedSignature = signature;
    if (!_isEditing) {
      _nameController.text = profile.name;
      _selectedClass = profile.studentClass;
      _selectedBoard = profile.board;
      _selectedLevel = profile.level;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await context.read<AuthProvider>().updateProfile(
            name: _nameController.text.trim(),
            studentClass: _selectedClass,
            board: _selectedBoard,
            level: _selectedLevel,
          );
      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.profile;
    final user = authProvider.user;

    if (profile == null || user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Form(
        key: _formKey,
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
                  onPressed: () => context.pop(),
                ),
              ),
            ),
            _buildHeader(profile, user.email ?? ''),
            const SizedBox(height: 20),
            _buildSummaryChips(profile),
            const SizedBox(height: 20),
            _buildProfileCard(profile),
            const SizedBox(height: 20),
            _buildSubscriptionCard(),
            const SizedBox(height: 20),
            _buildAppInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(StudentProfile profile, String email) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF0F172A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32, backgroundColor: Colors.white.withValues(alpha: 0.15),
                child: Text(profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'S',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(email, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.78))),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _isEditing = !_isEditing),
                style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white.withValues(alpha: 0.12)),
                child: Text(_isEditing ? 'Close' : 'Edit'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('This profile powers the IlmAI tutor, exam generator, and notes builder.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildSummaryChips(StudentProfile profile) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: [
        _chip('Class ${profile.studentClass}'),
        _chip(profile.boardName),
        _chip(profile.levelName),
        _chip(profile.boardDescription),
      ],
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(color: AppColors.onSurfaceOf(context), fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _buildProfileCard(StudentProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Profile Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.onSurfaceOf(context))),
              if (_isSaving)
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              else if (_isEditing)
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.check_circle_rounded, color: Colors.green), onPressed: _saveProfile),
                    IconButton(
                      icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                      onPressed: () {
                        setState(() {
                          _isEditing = false;
                          final profile = context.read<AuthProvider>().profile;
                          if (profile != null) {
                            _nameController.text = profile.name;
                            _selectedClass = profile.studentClass;
                            _selectedBoard = profile.board;
                            _selectedLevel = profile.level;
                          }
                        });
                      },
                    ),
                  ],
                ),
            ],
          ),
          const Divider(height: 28),
          _buildFieldLabel('Full Name'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            enabled: _isEditing,
            style: TextStyle(color: AppColors.onSurfaceOf(context)),
            decoration: _inputDecoration('Enter full name'),
            validator: (value) => value == null || value.trim().isEmpty ? 'Name cannot be empty' : null,
          ),
          const SizedBox(height: 16),
          _buildFieldLabel('Class'),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _selectedClass,
            items: [9, 10, 11, 12].map((c) => DropdownMenuItem(value: c, child: Text('Class $c'))).toList(),
            onChanged: _isEditing ? (value) { if (value != null) setState(() => _selectedClass = value); } : null,
            dropdownColor: AppColors.surfaceAltOf(context),
            decoration: _inputDecoration('Select class'),
          ),
          const SizedBox(height: 16),
          _buildFieldLabel('Board'),
          const SizedBox(height: 8),
          DropdownButtonFormField<StudentBoard>(
            initialValue: _selectedBoard,
            items: const [
              DropdownMenuItem(value: StudentBoard.bsek, child: Text('BSEK')),
              DropdownMenuItem(value: StudentBoard.biek, child: Text('BIEK')),
            ],
            onChanged: _isEditing ? (value) { if (value != null) setState(() => _selectedBoard = value); } : null,
            dropdownColor: AppColors.surfaceAltOf(context),
            decoration: _inputDecoration('Select board'),
          ),
          const SizedBox(height: 16),
          _buildFieldLabel('Student Level'),
          const SizedBox(height: 8),
          DropdownButtonFormField<StudentLevel>(
            initialValue: _selectedLevel,
            items: const [
              DropdownMenuItem(value: StudentLevel.developing, child: Text('Weak')),
              DropdownMenuItem(value: StudentLevel.average, child: Text('Average')),
              DropdownMenuItem(value: StudentLevel.advanced, child: Text('Intelligent')),
            ],
            onChanged: _isEditing ? (value) { if (value != null) setState(() => _selectedLevel = value); } : null,
            dropdownColor: AppColors.surfaceAltOf(context),
            decoration: _inputDecoration('Select level'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    final tier = context.read<AuthProvider>().subscriptionTier;
    final isFree = tier.toLowerCase() == 'free';
    final isBasic = tier.toLowerCase() == 'basic';
    final tierColor = isFree ? AppColors.onSurfaceMutedOf(context) : (isBasic ? const Color(0xFF0F766E) : AppColors.primary);
    final tierIcon = isFree ? Icons.person_outline_rounded : (isBasic ? Icons.star_outline_rounded : Icons.auto_awesome_rounded);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: tierColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(tierIcon, color: tierColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tier == 'Pending' ? 'Plan Pending' : tier, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: tierColor)),
                const SizedBox(height: 3),
                Text(isFree ? 'Free tier — upgrade for more features' : '${tier} plan active', style: TextStyle(fontSize: 12, color: AppColors.onSurfaceMutedOf(context))),
              ],
            ),
          ),
          if (isFree)
            TextButton(
              onPressed: () => context.push('/subscription'),
              child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceAltOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('App Version', style: TextStyle(color: AppColors.onSurfaceOf(context), fontWeight: FontWeight.w700)),
            trailing: const Text('1.2.7', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('About App', style: TextStyle(color: AppColors.onSurfaceOf(context), fontWeight: FontWeight.w700)),
            subtitle: Text('Who made it and what it does', style: TextStyle(color: AppColors.onSurfaceMutedOf(context))),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: AppColors.onSurfaceMutedOf(context)));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceAltOf(context),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.4))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.4))),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.4))),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
