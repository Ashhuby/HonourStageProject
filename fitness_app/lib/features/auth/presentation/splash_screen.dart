import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;
  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _plate1Controller;
  late AnimationController _plate2Controller;
  late AnimationController _plate3Controller;
  late AnimationController _bumpController;
  late AnimationController _textController;

  late Animation<double> _plate1Anim;
  late Animation<double> _plate2Anim;
  late Animation<double> _plate3Anim;
  late Animation<double> _bumpAnim;
  late Animation<double> _textFadeAnim;
  late Animation<Offset> _textSlideAnim;

  bool _done = false;

  @override
  void initState() {
    super.initState();

    _plate1Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _plate2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _plate3Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _plate1Anim = CurvedAnimation(
      parent: _plate1Controller,
      curve: Curves.easeOut,
    );
    _plate2Anim = CurvedAnimation(
      parent: _plate2Controller,
      curve: Curves.easeOut,
    );
    _plate3Anim = CurvedAnimation(
      parent: _plate3Controller,
      curve: Curves.easeOut,
    );
    _bumpAnim = Tween<double>(begin: 0, end: 4).animate(
      CurvedAnimation(parent: _bumpController, curve: Curves.easeInOut),
    );
    _textFadeAnim = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );
    _textSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Pair 1
    _plate1Controller.forward();
    await Future.delayed(const Duration(milliseconds: 280));
    _bumpController.forward().then((_) => _bumpController.reverse());

    await Future.delayed(const Duration(milliseconds: 320));

    // Pair 2
    _plate2Controller.forward();
    await Future.delayed(const Duration(milliseconds: 280));
    _bumpController.forward().then((_) => _bumpController.reverse());

    await Future.delayed(const Duration(milliseconds: 320));

    // Pair 3
    _plate3Controller.forward();
    await Future.delayed(const Duration(milliseconds: 280));
    _bumpController.forward().then((_) => _bumpController.reverse());

    await Future.delayed(const Duration(milliseconds: 300));

    // Text fade in
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 900));

    // Transition to app
    if (mounted) setState(() => _done = true);
  }

  @override
  void dispose() {
    _plate1Controller.dispose();
    _plate2Controller.dispose();
    _plate3Controller.dispose();
    _bumpController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;

    return Scaffold(
      backgroundColor: OneRepColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _bumpAnim,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _bumpAnim.value),
                child: child,
              ),
              child: SizedBox(
                width: 280,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Bar
                    Center(
                      child: Container(
                        width: 200,
                        height: 10,
                        decoration: BoxDecoration(
                          color: OneRepColors.gold,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    // Left collar
                    Positioned(left: 28, child: _collar()),
                    // Right collar
                    Positioned(right: 28, child: _collar()),
                    // Plate pair 1 — largest
                    _animatedPlate(
                      _plate1Anim,
                      left: 10,
                      width: 18,
                      height: 64,
                      fromLeft: true,
                    ),
                    _animatedPlate(
                      _plate1Anim,
                      right: 10,
                      width: 18,
                      height: 64,
                      fromLeft: false,
                    ),
                    // Plate pair 2
                    _animatedPlate(
                      _plate2Anim,
                      left: 3,
                      width: 14,
                      height: 52,
                      fromLeft: true,
                    ),
                    _animatedPlate(
                      _plate2Anim,
                      right: 3,
                      width: 14,
                      height: 52,
                      fromLeft: false,
                    ),
                    // Plate pair 3 — smallest
                    _animatedPlate(
                      _plate3Anim,
                      left: -5,
                      width: 10,
                      height: 40,
                      fromLeft: true,
                    ),
                    _animatedPlate(
                      _plate3Anim,
                      right: -5,
                      width: 10,
                      height: 40,
                      fromLeft: false,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            SlideTransition(
              position: _textSlideAnim,
              child: FadeTransition(
                opacity: _textFadeAnim,
                child: const Column(
                  children: [
                    Text(
                      'ONE REP',
                      style: TextStyle(
                        color: OneRepColors.gold,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'STRENGTH TRACKER',
                      style: TextStyle(
                        color: OneRepColors.textDisabled,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collar() {
    return Container(
      width: 12,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFFB8962E),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _animatedPlate(
    Animation<double> anim, {
    double? left,
    double? right,
    required double width,
    required double height,
    required bool fromLeft,
  }) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) => Positioned(
        left: left,
        right: right,
        child: Opacity(
          opacity: anim.value,
          child: Transform.translate(
            offset: Offset((1 - anim.value) * (fromLeft ? -30 : 30), 0),
            child: child,
          ),
        ),
      ),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: OneRepColors.gold,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
