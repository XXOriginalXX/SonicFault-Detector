

// ════════════════════════════════════════════════════════════════════════════
// lib/screens/admin_screen.dart
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../db/database_helper.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

class AdminScreen extends StatefulWidget {
  final User adminUser;
  const AdminScreen({super.key, required this.adminUser});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<User> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await DatabaseHelper.instance.getAllUsers();
    setState(() { _users = u; _loading = false; });
  }

  Future<void> _delete(User u) async {
    if (u.isAdmin) return; // protect admin
    await DatabaseHelper.instance.deleteUser(u.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('USER MANAGEMENT'),
        actions: [
          IconButton(onPressed: _load,
              icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              const Icon(Icons.people_rounded, color: AppTheme.accent, size: 16),
              const SizedBox(width: 8),
              Text('${_users.length} registered users',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: _users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final u = _users[i];
                final date = DateFormat('dd MMM yyyy').format(
                    DateTime.parse(u.createdAt));
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: u.isAdmin
                          ? AppTheme.accent.withOpacity(0.4)
                          : AppTheme.border,
                    ),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: u.isAdmin
                          ? AppTheme.accentDim : AppTheme.border,
                      child: Text(u.name[0].toUpperCase(),
                          style: TextStyle(
                              color: u.isAdmin
                                  ? AppTheme.accent : AppTheme.textSec,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(u.name, style: const TextStyle(
                              color: AppTheme.textPri, fontSize: 14,
                              fontWeight: FontWeight.w500)),
                          if (u.isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.accentDim,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('ADMIN',
                                  style: TextStyle(
                                      color: AppTheme.accent,
                                      fontSize: 9,
                                      letterSpacing: 1)),
                            ),
                          ],
                        ]),
                        Text(u.email, style: const TextStyle(
                            color: AppTheme.textSec, fontSize: 12)),
                        Text('Joined $date', style: const TextStyle(
                            color: AppTheme.textSec, fontSize: 11)),
                      ],
                    )),
                    if (!u.isAdmin)
                      IconButton(
                        onPressed: () => _delete(u),
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.red, size: 20),
                      ),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}