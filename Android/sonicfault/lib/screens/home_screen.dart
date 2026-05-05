import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/ml_service.dart';
import '../services/server_config.dart';
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

  void _goTo(int tab) => setState(() => _tab = tab);

  void _showServerDialog(BuildContext context) {
    final ctrl = TextEditingController(text: ServerConfig.instance.url);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Server URL',
            style: TextStyle(color: AppTheme.textPri, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Paste your ngrok URL or local IP.',
              style: TextStyle(color: AppTheme.textSec, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            style: const TextStyle(color: AppTheme.textPri, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'https://abc.ngrok-free.app',
              hintStyle: const TextStyle(color: AppTheme.textSec),
              filled: true,
              fillColor: AppTheme.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              await ServerConfig.instance.reset();
              await MlService.instance.init();
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Reset',
                style: TextStyle(color: AppTheme.textSec)),
          ),
          ElevatedButton(
            onPressed: () async {
              await ServerConfig.instance.save(ctrl.text);
              await MlService.instance.init();
              if (context.mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardPage(onNavigate: _goTo),
      const UploadScreen(),
      const LiveScreen(),
      const RoadsideScreen(),
      if (widget.user.isAdmin) AdminScreen(adminUser: widget.user),
    ];

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
          // Server connection indicator + config
          IconButton(
            icon: Icon(
              MlService.instance.backendOnline
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_off_rounded,
              color: MlService.instance.backendOnline
                  ? AppTheme.green : AppTheme.textSec,
              size: 20,
            ),
            onPressed: () => _showServerDialog(context),
          ),
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
                        color: AppTheme.accent.withValues(alpha: 0.5)),
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
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: BottomNavigationBar(
          items: tabs,
          currentIndex: _tab,
          onTap: _goTo),
    );
  }
}

// ── Dashboard ─────────────────────────────────────────────────────────────────

class _DashboardPage extends StatelessWidget {
  final void Function(int) onNavigate;
  const _DashboardPage({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Diagnostics',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Choose a scan mode below',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),

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
                onTap: () => onNavigate(1),
              ),
              _FeatureCard(
                icon: Icons.mic_rounded,
                label: 'Live Detect',
                sub: 'Real-time microphone scan',
                color: AppTheme.green,
                onTap: () => onNavigate(2),
              ),
              _FeatureCard(
                icon: Icons.build_circle_rounded,
                label: 'DIY Guide',
                sub: 'Fix it yourself steps',
                color: const Color(0xFF4FC3F7),
                onTap: () => onNavigate(1),
              ),
              _FeatureCard(
                icon: Icons.local_phone_rounded,
                label: 'Roadside Assist',
                sub: 'Emergency helplines',
                color: AppTheme.red,
                onTap: () => onNavigate(3),
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

// ── Feature card ──────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label, sub;
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
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: color.withValues(alpha: 0.15),
        highlightColor: color.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
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
      ),
    );
  }
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final online = MlService.instance.backendOnline;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        Icon(Icons.circle,
            color: online ? AppTheme.green : AppTheme.textSec, size: 10),
        const SizedBox(width: 10),
        Text(
          online ? 'Backend connected' : 'Offline mode — RF model ready',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: online ? AppTheme.green : AppTheme.textSec),
        ),
        const Spacer(),
        Text('v1.0', style: Theme.of(context).textTheme.bodyMedium),
      ]),
    );
  }
}