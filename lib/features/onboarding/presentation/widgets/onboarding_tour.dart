import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'is_first_launch';

Future<bool> isFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_prefKey) ?? true;
}

Future<void> markTourComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_prefKey, false);
}

class OnboardingTourStep {
  final String title;
  final String description;
  final Rect Function(Size screenSize) targetRect;

  const OnboardingTourStep({
    required this.title,
    required this.description,
    required this.targetRect,
  });
}

class OnboardingTour extends StatefulWidget {
  final Widget child;
  final List<OnboardingTourStep> steps;

  const OnboardingTour({
    super.key,
    required this.child,
    required this.steps,
  });

  @override
  State<OnboardingTour> createState() => _OnboardingTourState();
}

class _OnboardingTourState extends State<OnboardingTour>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeIn,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.fastOutSlowIn,
    ));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
      _animCtrl.forward(from: 0);
    } else {
      _dismiss();
    }
  }

  void _dismiss() async {
    await markTourComplete();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        widget.child,
        // Dark backdrop with cutout
        ClipPath(
          clipper: _TourCutoutClipper(
            holeRect: widget.steps[_currentStep].targetRect(
              MediaQuery.of(context).size,
            ),
          ),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
            child: GestureDetector(
              onTap: _next,
              child: Stack(
                children: [
                  // Tooltip card
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.of(context).size.height * 0.12,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Step indicator
                              Row(
                                children: [
                                  for (int i = 0;
                                      i < widget.steps.length;
                                      i++)
                                    Container(
                                      width: i == _currentStep ? 24 : 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: i == _currentStep
                                            ? cs.primary
                                            : cs.onSurfaceVariant
                                                .withValues(alpha: 0.3),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: _dismiss,
                                    child: Text(
                                      'Skip Tour',
                                      style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.steps[_currentStep].title,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.steps[_currentStep].description,
                                style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _next,
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _currentStep < widget.steps.length - 1
                                        ? 'Next'
                                        : 'Get Started',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TourCutoutClipper extends CustomClipper<Path> {
  final Rect holeRect;

  const _TourCutoutClipper({required this.holeRect});

  @override
  Path getClip(Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          holeRect,
          const Radius.circular(20),
        ),
      );
    return Path.combine(PathOperation.reverseDifference, path, path);
  }

  @override
  bool shouldReclip(_TourCutoutClipper old) => old.holeRect != holeRect;
}
