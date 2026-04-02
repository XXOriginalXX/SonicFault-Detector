import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ml_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _gaugeCtrl;
  double _progress = 0;
  String _status = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _gaugeCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _boot();
  }

  Future<void> _boot() async {
    _setStatus('Loading model...', 0.3);
    try {
      await MlService.instance.init();
    } catch (e) {
      debugPrint('MlService init error: $e');
      // Continue anyway — predict() will return a safe fallback
    }
    _setStatus('Calibrating sensors...', 0.7);
    await Future.delayed(600.ms);
    _setStatus('Ready.', 1.0);
    await Future.delayed(800.ms);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: 600.ms,
          pageBuilder: (_, a, __) => const LoginScreen(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
    }
  }

  void _setStatus(String msg, double p) {
    if (!mounted) return;
    setState(() {
      _status = msg;
      _progress = p;
    });
    _gaugeCtrl.animateTo(p, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _gaugeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Grid overlay texture
          CustomPaint(painter: _GridPainter()),

          // Center content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Speedometer logo
              _SpeedometerWidget(controller: _gaugeCtrl)
                  .animate()
                  .fadeIn(duration: 600.ms),
              const SizedBox(height: 32),

              // App name
              Text('SONIC FAULT',
                  style: Theme.of(context).textTheme.headlineLarge)
                  .animate()
                  .fadeIn(delay: 300.ms, duration: 600.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 8),
              Text('Vehicle Diagnostics',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: AppTheme.accent, letterSpacing: 4))
                  .animate()
                  .fadeIn(delay: 500.ms),

              const SizedBox(height: 48),

              // Progress bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: AnimatedBuilder(
                  animation: _gaugeCtrl,
                  builder: (_, __) => Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _gaugeCtrl.value,
                          backgroundColor: AppTheme.border,
                          color: AppTheme.accent,
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(_status,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium!
                              .copyWith(letterSpacing: 1.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Bottom credits
          Positioned(
            bottom: 32,
            left: 0, right: 0,
            child: Text('Powered by SCTCE',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(letterSpacing: 2))
                .animate()
                .fadeIn(delay: 800.ms),
          ),
        ],
      ),
    );
  }
}

// ── Animated speedometer SVG ──────────────────────────────────────────────────

class _SpeedometerWidget extends StatelessWidget {
  final AnimationController controller;
  const _SpeedometerWidget({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        size: const Size(160, 160),
        painter: _SpeedometerPainter(controller.value),
      ),
    );
  }
}

class _SpeedometerPainter extends CustomPainter {
  final double progress;
  _SpeedometerPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.42;

    // Background arc
    final bgPaint = Paint()
      ..color = AppTheme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        _deg(150), _deg(240), false, bgPaint);

    // Foreground arc
    final fgPaint = Paint()
      ..color = AppTheme.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        _deg(150), _deg(240 * progress), false, fgPaint);

    // Needle
    final angle = _toRad(150 + 240 * progress);
    final needleEnd = Offset(
      cx + (r - 16) * math.cos(angle),
      cy + (r - 16) * math.sin(angle),
    );
    canvas.drawLine(
      Offset(cx, cy),
      needleEnd,
      Paint()
        ..color = AppTheme.accent
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Center dot
    canvas.drawCircle(
        Offset(cx, cy), 6,
        Paint()..color = AppTheme.accent);

    // Inner ring
    canvas.drawCircle(
        Offset(cx, cy), r * 0.7,
        Paint()
          ..color = AppTheme.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5);
  }

  double _deg(double d) => d * math.pi / 180;
  double _toRad(double d) => d * math.pi / 180;

  @override
  bool shouldRepaint(_SpeedometerPainter old) => old.progress != progress;
}



class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppTheme.border.withOpacity(0.3)
      ..strokeWidth = 0.5;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter _) => false;
}