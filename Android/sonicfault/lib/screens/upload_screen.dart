import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/detection_result.dart';
import '../services/ml_service.dart';
import '../theme/app_theme.dart';
import 'widgets/result_card.dart';
import 'widgets/diy_sheet.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  String?          _fileName;
  bool             _analyzing = false;
  DetectionResult? _result;
  String?          _error;

  Future<void> _pickAndAnalyze() async {
    final res = await FilePicker.platform.pickFiles(
        type: FileType.audio, allowMultiple: false, withData: true);
    if (res == null || res.files.single.bytes == null) return;

    setState(() {
      _fileName  = res.files.single.name;
      _analyzing = true;
      _result    = null;
      _error     = null;
    });

    try {
      final bytes  = res.files.single.bytes!;
      final result = await MlService.instance
          .predictFromBytes(bytes, _fileName!);
      if (mounted) setState(() { _result = result; _analyzing = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _analyzing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UPLOAD AUDIO'),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [

          // Connection banner
          if (!MlService.instance.backendOnline)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.textSec, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Backend not connected. Start your FastAPI server and '
                        'set your PC IP in ml_service.dart.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ]),
            ),

          // Drop zone
          GestureDetector(
            onTap: _analyzing ? null : _pickAndAnalyze,
            child: AnimatedContainer(
              duration: 300.ms,
              height: 180,
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _fileName != null ? AppTheme.accent : AppTheme.border,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _fileName != null
                          ? Icons.audio_file_rounded : Icons.upload_rounded,
                      color: _fileName != null
                          ? AppTheme.accent : AppTheme.textSec,
                      size: 44,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _fileName ?? 'Tap to select audio file',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: _fileName != null
                              ? AppTheme.textPri : AppTheme.textSec),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text('WAV • MP3 • OGG',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _analyzing ? null : _pickAndAnalyze,
              icon: _analyzing
                  ? const SizedBox(
                  height: 16, width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded, size: 18),
              label: Text(_analyzing ? 'ANALYZING...' : 'ANALYZE'),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.red.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.red, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: const TextStyle(color: AppTheme.red, fontSize: 13))),
              ]),
            ),
          ],

          if (_result != null) ...[
            const SizedBox(height: 24),
            ResultCard(result: _result!)
                .animate().fadeIn().slideY(begin: 0.15, end: 0),
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
          ],
        ]),
      ),
    );
  }
}