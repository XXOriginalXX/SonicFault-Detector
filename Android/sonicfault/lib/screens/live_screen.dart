import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/detection_result.dart';
import '../services/ml_service.dart';
import '../theme/app_theme.dart';
import 'widgets/diy_sheet.dart';
import 'widgets/result_card.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});
  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  DetectionResult? _result;
  String? _error;
  late AnimationController _pulseCtrl;
  Timer? _scanTimer;
  String _statusMsg = 'Tap the mic to begin';
  String _mode = '';   // 'backend' or 'offline'

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
        lowerBound: 0.9,
        upperBound: 1.1)
      ..repeat(reverse: true);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) { await _stopRecording(); return; }
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      setState(() => _error = 'Microphone permission denied.');
      return;
    }
    await _startRecording();
  }

  Future<void> _startRecording() async {
    final dir     = await getApplicationDocumentsDirectory();
    final tmpPath = '${dir.path}/sf_live.wav';

    setState(() {
      _isRecording = true;
      _statusMsg   = 'Listening...';
      _result      = null;
      _error       = null;
      _mode        = '';
    });

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: tmpPath,
    );

    // Every 6 seconds: stop → send to backend → restart
    _scanTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (!_isRecording) return;

      final path = await _recorder.stop();
      if (path != null) {
        try {
          final bytes  = await File(path).readAsBytes();
          if (bytes.length > 1000) {  // skip empty/tiny clips
            final result = await MlService.instance
                .predictFromBytes(bytes, 'live_clip.wav');
            if (mounted) {
              setState(() {
                _result    = result;
                _statusMsg = 'Scanning...';
                _mode      = MlService.instance.backendOnline
                    ? 'backend' : 'offline';
              });
            }
          }
        } catch (e) {
          if (mounted) setState(() => _error = e.toString());
        }
      }

      // Restart next clip
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 22050,
          numChannels: 1,
        ),
        path: tmpPath,
      );
    });
  }

  Future<void> _stopRecording() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    await _recorder.stop();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _statusMsg   = 'Tap the mic to begin';
      });
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _recorder.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LIVE DETECTION'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(children: [
              Icon(
                MlService.instance.backendOnline
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                color: MlService.instance.backendOnline
                    ? AppTheme.green : AppTheme.textSec,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                MlService.instance.backendOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: MlService.instance.backendOnline
                      ? AppTheme.green : AppTheme.textSec,
                  fontSize: 11,
                ),
              ),
            ]),
          ),
        ],
      ),
      body: Column(
        children: [
          const Spacer(),

          // Mode badge
          if (_mode.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _mode == 'backend'
                    ? AppTheme.green.withValues(alpha: 0.12)
                    : AppTheme.border,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _mode == 'backend'
                      ? AppTheme.green.withValues(alpha: 0.4)
                      : AppTheme.border,
                ),
              ),
              child: Text(
                _mode == 'backend'
                    ? '🟢  Using Python backend'
                    : '🟡  Using offline model',
                style: TextStyle(
                  color: _mode == 'backend' ? AppTheme.green : AppTheme.textSec,
                  fontSize: 12,
                ),
              ),
            ),

          // Pulsing mic button
          GestureDetector(
            onTap: _toggleRecording,
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, child) => Transform.scale(
                scale: _isRecording ? _pulseCtrl.value : 1.0,
                child: child,
              ),
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isRecording
                      ? AppTheme.red.withValues(alpha: 0.15)
                      : AppTheme.accentDim,
                  border: Border.all(
                    color: _isRecording ? AppTheme.red : AppTheme.accent,
                    width: 2,
                  ),
                ),
                child: Icon(
                  _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                  size: 52,
                  color: _isRecording ? AppTheme.red : AppTheme.accent,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Text(_statusMsg,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: _isRecording ? AppTheme.red : AppTheme.textSec)),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: const TextStyle(color: AppTheme.red, fontSize: 13)),
          ],

          const Spacer(),
          if (_result != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                ResultCard(result: _result!).animate().fadeIn(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => showDiySheet(context, _result!.labelKey),
                    icon: const Icon(Icons.build_rounded,
                        size: 16, color: AppTheme.accent),
                    label: const Text('VIEW DIY SOLUTION',
                        style: TextStyle(color: AppTheme.accent)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.accent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}