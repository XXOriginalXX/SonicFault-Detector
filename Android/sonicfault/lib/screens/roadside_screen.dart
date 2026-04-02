
// ════════════════════════════════════════════════════════════════════════════
// lib/screens/roadside_screen.dart
// ════════════════════════════════════════════════════════════════════════════

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class RoadsideScreen extends StatelessWidget {
  const RoadsideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ROADSIDE ASSISTANCE')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('National Helplines'),
            const SizedBox(height: 12),
            _HelplineCard(name: 'Emergency Services', number: '112',
                icon: Icons.local_police_rounded, color: AppTheme.red),
            _HelplineCard(name: 'Highway Helpline', number: '1033',
                icon: Icons.add_road_rounded, color: Colors.orange),
            _HelplineCard(name: 'Ambulance', number: '108',
                icon: Icons.local_hospital_rounded, color: const Color(0xFF4FC3F7)),

            const SizedBox(height: 24),
            _SectionLabel('Brand Assistance'),
            const SizedBox(height: 12),
            ...[
              ('Maruti Suzuki', '1800-102-1800'),
              ('Hyundai', '1800-11-4645'),
              ('Tata Motors', '1800-209-7979'),
              ('Honda', '1800-113-121'),
              ('Toyota', '1800-425-0001'),
              ('Kia', '1800-108-5000'),
            ].map((e) => _BrandCard(brand: e.$1, number: e.$2)),

            const SizedBox(height: 24),
            _SectionLabel('Tips While Waiting'),
            const SizedBox(height: 12),
            _TipCard(Icons.warning_amber_rounded,
                'Turn on hazard lights immediately'),
            _TipCard(Icons.directions_walk_rounded,
                'Move to a safe distance from traffic'),
            _TipCard(Icons.phone_rounded,
                'Share your GPS location with the helpline'),
            _TipCard(Icons.water_drop_rounded,
                'Do not open the hood if you smell something burning'),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(
          color: AppTheme.textSec, fontSize: 11, letterSpacing: 2));
}

class _HelplineCard extends StatelessWidget {
  final String name, number;
  final IconData icon;
  final Color color;
  const _HelplineCard({
    required this.name, required this.number,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(
              color: AppTheme.textPri, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(number, style: TextStyle(
              color: color, fontSize: 18, fontFamily: 'Orbitron',
              fontWeight: FontWeight.w700, letterSpacing: 2)),
        ])),
        IconButton(
          onPressed: () => launchUrl(Uri.parse('tel:$number')),
          icon: const Icon(Icons.call_rounded, color: AppTheme.green, size: 22),
        ),
      ]),
    );
  }
}

class _BrandCard extends StatelessWidget {
  final String brand, number;
  const _BrandCard({required this.brand, required this.number});

  @override
  Widget build(BuildContext context) => _HelplineCard(
      name: brand, number: number,
      icon: Icons.directions_car_filled_rounded,
      color: AppTheme.accent);
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipCard(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(children: [
      Icon(icon, color: AppTheme.textSec, size: 16),
      const SizedBox(width: 12),
      Expanded(child: Text(text,
          style: const TextStyle(color: AppTheme.textPri, fontSize: 13))),
    ]),
  );
}
