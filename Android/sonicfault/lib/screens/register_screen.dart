// register_screen.dart  (append to same file or separate — your choice)
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart' show AppBar, BuildContext, CircularProgressIndicator, Colors, Column, EdgeInsets, ElevatedButton, Form, FormState, GlobalKey, InputDecoration, Navigator, Scaffold, ScaffoldMessenger, SingleChildScrollView, SizedBox, SnackBar, State, StatefulWidget, Text, TextEditingController, TextFormField, TextInputType, TextStyle, Widget;

import '../db/database_helper.dart';
import '../theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form    = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final ok = await DatabaseHelper.instance
        .register(_emailCtrl.text, _passCtrl.text, _nameCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) {
      setState(() => _error = 'Email already registered.');
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created — please sign in.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CREATE ACCOUNT')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _form,
          child: Column(children: [
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppTheme.textPri),
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppTheme.textPri),
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) =>
              (v == null || !v.contains('@')) ? 'Valid email required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passCtrl,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPri),
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) =>
              (v == null || v.length < 4) ? 'Min 4 characters' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.red)),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('CREATE ACCOUNT'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}