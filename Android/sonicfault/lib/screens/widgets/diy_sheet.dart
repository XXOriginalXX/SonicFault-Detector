import 'package:flutter/material.dart';
import '../../models/detection_result.dart';
import '../../theme/app_theme.dart';

void showDiySheet(BuildContext context, String issueKey) {
  final sol = _getDiySolution(issueKey);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          Row(children: [
            const Icon(Icons.build_circle_rounded, color: AppTheme.accent, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(sol.issue,
                  style: const TextStyle(
                      color: AppTheme.textPri,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _severityBg(sol.severity),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(sol.severity.toUpperCase(),
                  style: TextStyle(
                      color: _severityFg(sol.severity),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1)),
            ),
          ]),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.red.withValues(alpha: 0.3)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_rounded, color: AppTheme.red, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(sol.warning,
                  style: const TextStyle(color: AppTheme.red, fontSize: 12))),
            ]),
          ),

          const SizedBox(height: 20),
          _SheetSection(label: 'Tools needed',  icon: Icons.handyman_rounded, value: sol.tools.join(' • ')),
          _SheetSection(label: 'Estimated time', icon: Icons.timer_rounded,   value: sol.estimatedTime),

          const SizedBox(height: 20),
          const Text('STEPS', style: TextStyle(
              color: AppTheme.textSec, fontSize: 11, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          ...sol.steps.asMap().entries.map((e) => _StepTile(num: e.key + 1, text: e.value)),
        ]),
      ),
    ),
  );
}

// ── _SheetSection ─────────────────────────────────────────────────────────────

class _SheetSection extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;

  const _SheetSection({
    required this.label,
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, color: AppTheme.accent, size: 16),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(color: AppTheme.textSec, fontSize: 13)),
      Expanded(
        child: Text(value,
            style: const TextStyle(color: AppTheme.textPri, fontSize: 13)),
      ),
    ]),
  );
}

// ── _StepTile ─────────────────────────────────────────────────────────────────

class _StepTile extends StatelessWidget {
  final int num;
  final String text;
  const _StepTile({required this.num, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: AppTheme.accentDim,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.accent),
        ),
        child: Center(child: Text('$num',
            style: const TextStyle(
                color: AppTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700))),
      ),
      const SizedBox(width: 12),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(text,
            style: const TextStyle(
                color: AppTheme.textPri, fontSize: 14, height: 1.5)),
      )),
    ]),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _severityBg(String s) {
  if (s == 'high') return AppTheme.red.withValues(alpha: 0.15);
  if (s == 'low')  return AppTheme.green.withValues(alpha: 0.15);
  return Colors.orange.withValues(alpha: 0.15);
}

Color _severityFg(String s) {
  if (s == 'high') return AppTheme.red;
  if (s == 'low')  return AppTheme.green;
  return Colors.orange;
}

// ── DIY data keyed to your 5 model classes ────────────────────────────────────

DiySolution _getDiySolution(String key) {
  const solutions = <String, DiySolution>{
    'injector_issue': DiySolution(
      issue: 'Injector Issue',
      severity: 'high',
      diyPossible: false,
      steps: [
        'Do not continue driving — rough idle can cause misfires.',
        'Check engine light codes with an OBD-II scanner.',
        'Inspect fuel injector connectors for corrosion or looseness.',
        'Try a bottle of fuel injector cleaner added to the tank.',
        'If misfire persists, have injectors professionally cleaned or replaced.',
      ],
      tools: ['OBD-II scanner', 'Fuel injector cleaner', 'Multimeter'],
      estimatedTime: '30 mins (inspection) / 2–3 hrs (replacement)',
      warning: 'A faulty injector can cause unburnt fuel to wash cylinder walls — prolonged use damages the engine.',
    ),
    'timing_belt_issue': DiySolution(
      issue: 'Timing Belt Issue',
      severity: 'high',
      diyPossible: false,
      steps: [
        'Stop the vehicle immediately if you hear rattling or slapping.',
        'Do NOT restart the engine — a snapped timing belt destroys valves.',
        'Have the vehicle towed to a workshop.',
        'Request inspection of the timing belt, tensioner, and water pump.',
        'Replace all three components together — they share the same service interval.',
      ],
      tools: ['Tow truck', 'Workshop tools (professional job)'],
      estimatedTime: '3–5 hrs (workshop)',
      warning: 'This is NOT a DIY job. A broken timing belt causes catastrophic engine failure instantly.',
    ),
    'oil_coolant_mixing': DiySolution(
      issue: 'Oil & Coolant Mixing',
      severity: 'high',
      diyPossible: false,
      steps: [
        'Stop driving immediately — this indicates a blown head gasket.',
        'Check the oil dipstick for a milky/frothy appearance.',
        'Check the coolant reservoir for an oily film on top.',
        'Do not top up either fluid — mixing accelerates engine damage.',
        'Have the vehicle towed to a workshop for head gasket inspection.',
      ],
      tools: ['Dipstick (inspection only)', 'Tow truck'],
      estimatedTime: '6–10 hrs (workshop)',
      warning: 'Continuing to drive will seize the engine. Coolant in oil destroys bearing surfaces within minutes.',
    ),
    'general_complaint': DiySolution(
      issue: 'General Complaint',
      severity: 'medium',
      diyPossible: true,
      steps: [
        'Park on level ground and switch off the engine.',
        'Perform a visual inspection — look for leaks, loose parts, or smoke.',
        'Check all fluid levels: engine oil, coolant, brake fluid, power steering.',
        'Listen for the noise at idle vs under load to narrow down the source.',
        'Tighten any visibly loose bolts or clamps.',
        'If the issue persists after basic checks, visit a mechanic.',
      ],
      tools: ['Wrench set', 'Screwdriver set', 'Torch / flashlight', 'Microfiber cloth'],
      estimatedTime: '20–40 mins',
      warning: 'Ensure the engine is fully cool before opening the radiator cap or touching exhaust components.',
    ),
    'no_complaint': DiySolution(
      issue: 'No Complaint Detected',
      severity: 'low',
      diyPossible: true,
      steps: [
        'No abnormal sounds detected in this recording.',
        'Continue routine maintenance as per manufacturer schedule.',
        'Check engine oil every 5,000 km.',
        'Inspect tyre pressure monthly.',
        'Re-scan if you notice any new sounds or performance changes.',
      ],
      tools: ['Tyre pressure gauge', 'Oil dipstick'],
      estimatedTime: '5–10 mins',
      warning: 'Regular preventive maintenance keeps your vehicle reliable and safe.',
    ),
  };

  return solutions[key] ??
      const DiySolution(
        issue: 'Vehicle Issue',
        severity: 'medium',
        diyPossible: true,
        steps: [
          'Park on level ground and turn off the engine.',
          'Perform a visual inspection around the affected area.',
          'Check relevant fluid levels (oil, coolant, brake fluid).',
          'Tighten any visibly loose components.',
          'Restart engine and observe — visit a mechanic if issue persists.',
        ],
        tools: ['Wrench set', 'Screwdriver set', 'Microfiber cloth'],
        estimatedTime: '20–40 mins',
        warning: 'Ensure the vehicle is on level ground and the engine is fully cool.',
      );
}