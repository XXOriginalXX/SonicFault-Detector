// ════════════════════════════════════════════════════════════════════════════
// home_screen.dart
// ════════════════════════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';
import 'upload_screen.dart';
import 'live_screen.dart';
import 'roadside_screen.dart';
import 'admin_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const _DashboardPage(),
      const UploadScreen(),
      const LiveScreen(),
      const RoadsideScreen(),
      if (widget.user.isAdmin) AdminScreen(adminUser: widget.user),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const BottomNavigationBarItem(
          icon: Icon(Icons.speed_rounded), label: 'Dashboard'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.upload_file_rounded), label: 'Upload'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.mic_rounded), label: 'Live'),
      const BottomNavigationBarItem(
          icon: Icon(Icons.local_phone_rounded), label: 'Assist'),
      if (widget.user.isAdmin)
        const BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_rounded), label: 'Admin'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('SONIC FAULT'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.accentDim,
                child: Text(
                  widget.user.name[0].toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
              if (widget.user.isAdmin) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accentDim,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.accent.withOpacity(0.5)),
                  ),
                  child: const Text('ADMIN',
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 10,
                          letterSpacing: 1)),
                ),
              ],
            ]),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: BottomNavigationBar(items: tabs,
          currentIndex: _tab,
          onTap: (i) => setState(() => _tab = i)),
    );
  }
}

// ── Dashboard home page ───────────────────────────────────────────────────────

class _DashboardPage extends StatelessWidget {
  const _DashboardPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Diagnostics', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Choose a scan mode below',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),

          // Feature grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.1,
            children: [
              _FeatureCard(
                icon: Icons.upload_file_rounded,
                label: 'Upload Audio',
                sub: 'Analyse a recorded file',
                color: AppTheme.accent,
                onTap: () => DefaultTabController.of(context),
              ),
              _FeatureCard(
                icon: Icons.mic_rounded,
                label: 'Live Detect',
                sub: 'Real-time microphone scan',
                color: AppTheme.green,
                onTap: () {},
              ),
              _FeatureCard(
                icon: Icons.build_circle_rounded,
                label: 'DIY Guide',
                sub: 'Fix it yourself steps',
                color: const Color(0xFF4FC3F7),
                onTap: () {},
              ),
              _FeatureCard(
                icon: Icons.local_phone_rounded,
                label: 'Roadside Assist',
                sub: 'Emergency helplines',
                color: AppTheme.red,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 28),
          _StatusBar(),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const Spacer(),
            Text(label, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(sub, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        const Icon(Icons.circle, color: AppTheme.green, size: 10),
        const SizedBox(width: 10),
        Text('ML model loaded — offline ready',
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: AppTheme.green)),
        const Spacer(),
        Text('v1.0', style: Theme.of(context).textTheme.bodyMedium),
      ]),
    );
  }
}