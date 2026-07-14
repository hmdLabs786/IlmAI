import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import 'package:ilmai/models/user_model.dart';
import '../services/auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final AuthService _auth = AuthService();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _pass = TextEditingController();

  String? _board;
  String? _class;
  String? _level;
  bool _loading = false;
  bool _obscurePass = true;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  static const _boards = ['BSEK (Matric)', 'BIEK (Intermediate)'];
  static const Map<String, List<String>> _classesByBoard = {
    'BSEK (Matric)': ['9', '10'],
    'BIEK (Intermediate)': ['11', '12'],
  };
  static const _levels = ['Weak', 'Average', 'Smart'];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _pulseAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.025), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.025, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _pass.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (_board == null || _class == null || _level == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required fields'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    _pulseCtrl.forward(from: 0);

    final user = UserModel(
      uid: '',
      fullName: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      board: _board!,
      className: _class!,
      learningLevel: _level!,
    );

    final err = await _auth.signUp(user, _pass.text);
    if (!mounted) return;
    setState(() => _loading = false);

    if (err == null) {
      context.push('/tier-selection');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 24),

                Image.asset(
                  'assets/logo.png',
                  width: 56,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: Icon(Icons.auto_awesome, size: 30, color: AppColors.primary),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Create Account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Join the learning community',
                  style: TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
                ),

                const SizedBox(height: 24),

                // Form card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // ── Personal info fields ──
                      _field(_name, 'Full Name', Icons.person_outline,
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Enter your name' : null),
                      const SizedBox(height: 14),

                      _field(_email, 'Email', Icons.email_outlined,
                          type: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter email';
                            if (!v.contains('@') || !v.contains('.')) {
                              return 'Invalid email format';
                            }
                            return null;
                          }),
                      const SizedBox(height: 14),

                      _field(_phone, 'Phone (11 digits)', Icons.phone_outlined,
                          type: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.length != 11) {
                              return 'Must be exactly 11 digits';
                            }
                            return null;
                          }),
                      const SizedBox(height: 14),

                      // ── Board selector ──
                      _sectionLabel('Education Board'),
                      const SizedBox(height: 8),
                      _dropdown(
                        value: _board,
                        hint: 'Select Board',
                        items: _boards,
                        icon: Icons.account_balance_outlined,
                        onChanged: (v) => setState(() {
                          _board = v;
                          _class = null;
                        }),
                      ),

                      // ── Class selector — AnimatedSize reveal ──
                      AnimatedSize(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.fastOutSlowIn,
                        alignment: Alignment.topCenter,
                        child: _board != null
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sectionLabel('Class'),
                                    const SizedBox(height: 8),
                                    _dropdown(
                                      value: _class,
                                      hint: 'Select Class',
                                      items: _classesByBoard[_board] ?? [],
                                      icon: Icons.school_outlined,
                                      onChanged: (v) =>
                                          setState(() => _class = v),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 14),

                      // ── Learning level ──
                      _sectionLabel('Learning Level'),
                      const SizedBox(height: 8),
                      _dropdown(
                        value: _level,
                        hint: 'Select Level',
                        items: _levels,
                        icon: Icons.trending_up_outlined,
                        onChanged: (v) => setState(() => _level = v),
                      ),

                      const SizedBox(height: 14),

                      // ── Password ──
                      _field(
                        _pass,
                        'Password',
                        Icons.lock_outline,
                        obscure: _obscurePass,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: AppColors.onSurfaceMuted,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                        validator: (v) {
                          final hasUpper = RegExp(r'[A-Z]').hasMatch(v ?? '');
                          final hasLower = RegExp(r'[a-z]').hasMatch(v ?? '');
                          final hasDigit = RegExp(r'[0-9]').hasMatch(v ?? '');
                          final hasSpecial =
                              RegExp(r'[!@#\$&*~]').hasMatch(v ?? '');
                          if ((v?.length ?? 0) < 8 ||
                              !hasUpper ||
                              !hasLower ||
                              !hasDigit ||
                              !hasSpecial) {
                            return '8+ chars, upper, lower, number & special';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 22),

                      // ── Submit button ──
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) => Transform.scale(
                          scale: _pulseAnim.value,
                          child: child,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _handleSignUp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.primary.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5, color: Colors.white),
                                  )
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    'Already have an account? Sign In',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: AppColors.onSurfaceMuted,
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool obscure = false,
    Widget? suffix,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      validator: validator,
      style: const TextStyle(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.onSurfaceMuted),
        prefixIcon: Icon(icon, color: AppColors.onSurfaceMuted, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.onSurfaceMuted),
        prefixIcon: Icon(icon, color: AppColors.onSurfaceMuted, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      dropdownColor: Colors.white,
      style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
      icon: Icon(Icons.expand_more_rounded, color: AppColors.onSurfaceMuted),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Required' : null,
    );
  }
}
