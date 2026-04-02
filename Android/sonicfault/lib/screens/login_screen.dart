import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../db/database_helper.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _form      = GlobalKey<FormState>();
  bool _obscure    = true;
  bool _loading    = false;
  String? _error;

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final user = await DatabaseHelper.instance
        .login(_emailCtrl.text, _passCtrl.text);

    if (!mounted) return;
    setState(() => _loading = false);

    if (user == null) {
      setState(() => _error = 'Invalid email or password.');
      return;
    }

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => HomeScreen(user: user),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _DiagPainter()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  // Logo
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accentDim,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.accent, width: 1.5),
                      ),
                      child: const Icon(Icons.graphic_eq_rounded,
                          color: AppTheme.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text('SONIC FAULT',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ]).animate().fadeIn(duration: 500.ms).slideX(begin: -0.1),

                  const SizedBox(height: 48),
                  Text('Welcome back',
                      style: Theme.of(context).textTheme.headlineLarge)
                      .animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 6),
                  Text('Sign in to continue',
                      style: Theme.of(context).textTheme.bodyMedium)
                      .animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 36),

                  Form(
                    key: _form,
                    child: Column(
                      children: [
                        _FieldLabel('Email'),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: AppTheme.textPri),
                          decoration: const InputDecoration(
                            hintText: 'your@email.com',
                            prefixIcon: Icon(Icons.alternate_email_rounded,
                                color: AppTheme.textSec, size: 18),
                          ),
                          validator: (v) =>
                          (v == null || !v.contains('@'))
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        _FieldLabel('Password'),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          style: const TextStyle(color: AppTheme.textPri),
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                color: AppTheme.textSec, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscure ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  color: AppTheme.textSec, size: 18),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) =>
                          (v == null || v.isEmpty) ? 'Enter password' : null,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.red.withOpacity(0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded,
                            color: AppTheme.red, size: 16),
                        const SizedBox(width: 8),
                        Text(_error!,
                            style: const TextStyle(
                                color: AppTheme.red, fontSize: 13)),
                      ]),
                    ).animate().fadeIn().shakeX(),
                  ],

                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                          : const Text('SIGN IN'),
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account? ",
                          style: Theme.of(context).textTheme.bodyMedium),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen())),
                        child: const Text('Register',
                            style: TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ).animate().fadeIn(delay: 350.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(
            color: AppTheme.textSec, fontSize: 12, letterSpacing: 1.2)),
  );
}

class _DiagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppTheme.accent.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.6, 0)
      ..lineTo(0, size.height * 0.4)
      ..close();
    canvas.drawPath(path, p);

    final p2 = Paint()
      ..color = AppTheme.accent.withOpacity(0.03)
      ..style = PaintingStyle.fill;
    final path2 = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..lineTo(size.width, size.height * 0.6)
      ..close();
    canvas.drawPath(path2, p2);
  }

  @override
  bool shouldRepaint(_DiagPainter _) => false;
}