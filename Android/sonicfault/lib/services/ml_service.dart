import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../models/detection_result.dart';
import 'server_config.dart';

class MlService {
  static final MlService instance = MlService._();
  MlService._();

  List<String> _classes = [];
  List<_Tree>  _trees   = [];
  int          _nClass  = 0;
  bool         _ready   = false;
  bool         _backendOnline = false;
  bool get backendOnline => _backendOnline;

  Future<void> init() async {
    await ServerConfig.instance.load();

    // Load offline RF model
    try {
      final raw  = await rootBundle.loadString('assets/rf_model.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _classes = List<String>.from(data['classes'] as List);
      _nClass  = data['n_classes'] as int;
      _trees   = (data['trees'] as List)
          .map((t) => _Tree(_buildNode(t as Map<String, dynamic>)))
          .toList();
      _ready = true;
    } catch (_) {
      _ready = false;
    }

    await _checkBackend();
  }

  Future<void> _checkBackend() async {
    try {
      final res = await http.get(
        Uri.parse('${ServerConfig.instance.url}/'),
      ).timeout(const Duration(seconds: 3));
      _backendOnline = res.statusCode == 200;
    } catch (_) {
      _backendOnline = false;
    }
  }

  // ── Main entry point — used by both upload and live screens ───────────────
  Future<DetectionResult> predictFromBytes(Uint8List wavBytes, String fileName) async {
    // Always try backend first
    try {
      await _checkBackend();
      if (_backendOnline) {
        final result = await _predictBackend(wavBytes, fileName);
        if (result != null) return result;
      }
    } catch (_) {
      _backendOnline = false;
    }

    // Fall back to offline RF
    if (_ready) {
      final pcm      = WavDecoder.decode(wavBytes);
      final features = MfccExtractor.extract(pcm);
      return predict(features.toList());
    }

    return DetectionResult(
      label:      'Backend Offline',
      labelKey:   'offline',
      confidence: 0,
      allScores:  [],
    );
  }

  // ── Backend prediction ────────────────────────────────────────────────────
  Future<DetectionResult?> _predictBackend(Uint8List bytes, String fileName) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ServerConfig.instance.url}/upload-audio'),
    );
    request.files.add(http.MultipartFile.fromBytes(
        'file', bytes, filename: fileName));

    final streamed = await request.send()
        .timeout(const Duration(seconds: 15));
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode != 200) return null;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (body['status'] != 'success') return null;

    final result = body['result'] as Map<String, dynamic>;
    final label  = result['detected_issue'] as String;
    final key    = result['detected_issue_key'] as String;

    if (key == 'unknown') return null;

    final allScores = _classes.isNotEmpty
        ? _classes.map((c) =>
        LabelScore(_fmt(c), c.toLowerCase() == key ? 1.0 : 0.0)).toList()
        : [LabelScore(label, 1.0)];

    return DetectionResult(
      label:      label,
      labelKey:   key,
      confidence: 1.0,
      allScores:  allScores,
    );
  }

  // ── Offline RF predict (features already extracted) ───────────────────────
  DetectionResult predict(List<double> features) {
    if (!_ready || _trees.isEmpty) {
      return DetectionResult(
          label: 'Not Ready', labelKey: 'unknown', confidence: 0, allScores: []);
    }
    final votes = List<double>.filled(_nClass, 0.0);
    for (final tree in _trees) {
      final p = tree.predict(features);
      for (int c = 0; c < _nClass; c++) votes[c] += p[c];
    }
    final n     = _trees.length.toDouble();
    final probs = votes.map((v) => v / n).toList();
    int best = 0;
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > probs[best]) best = i;
    }
    final allScores = [
      for (int i = 0; i < _classes.length; i++)
        LabelScore(_fmt(_classes[i]), probs[i])
    ]..sort((a, b) => b.score.compareTo(a.score));
    return DetectionResult(
      label:      _fmt(_classes[best]),
      labelKey:   _classes[best].toLowerCase(),
      confidence: probs[best],
      allScores:  allScores.take(5).toList(),
    );
  }

  static _Node _buildNode(Map<String, dynamic> j) {
    if (j['l'] == true) {
      return _Node.leaf(
          (j['p'] as List).map((v) => (v as num).toDouble()).toList());
    }
    return _Node.split(
      feat:   j['f'] as int,
      thresh: (j['t'] as num).toDouble(),
      left:   _buildNode(j['L'] as Map<String, dynamic>),
      right:  _buildNode(j['R'] as Map<String, dynamic>),
    );
  }

  String _fmt(String s) => s.replaceAll('_', ' ').split(' ')
      .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

// ── Tree structures ───────────────────────────────────────────────────────────
class _Tree {
  final _Node root;
  _Tree(this.root);
  List<double> predict(List<double> f) => root.predict(f);
}

class _Node {
  final bool isLeaf;
  final List<double>? proba;
  final int? feat;
  final double? thresh;
  final _Node? left, right;

  const _Node._({required this.isLeaf,
    this.proba, this.feat, this.thresh, this.left, this.right});

  factory _Node.leaf(List<double> p) => _Node._(isLeaf: true, proba: p);
  factory _Node.split({required int feat, required double thresh,
    required _Node left, required _Node right}) =>
      _Node._(isLeaf: false, feat: feat, thresh: thresh, left: left, right: right);

  List<double> predict(List<double> f) {
    if (isLeaf) return proba!;
    return (feat! < f.length ? f[feat!] : 0.0) <= thresh!
        ? left!.predict(f)
        : right!.predict(f);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  WAV decoder — PCM16/24/32, float32, stereo→mono, auto resample to 22050
// ═════════════════════════════════════════════════════════════════════════════
class WavDecoder {
  static const int targetSr   = 22050;
  static const int maxSamples = targetSr * 30;

  static Float32List decode(Uint8List bytes) {
    if (bytes.length < 44) return Float32List(0);
    final bd = ByteData.sublistView(bytes);
    int fmt = 1, ch = 1, sr = 44100, bps = 16;
    int dataOff = 44, dataSz = bytes.length - 44;
    int off = 12;
    while (off + 8 <= bytes.length) {
      final id   = String.fromCharCodes(bytes.sublist(off, off + 4));
      final size = bd.getUint32(off + 4, Endian.little);
      if (id == 'fmt ' && size >= 16) {
        fmt = bd.getUint16(off + 8,  Endian.little);
        ch  = bd.getUint16(off + 10, Endian.little);
        sr  = bd.getUint32(off + 12, Endian.little);
        bps = bd.getUint16(off + 22, Endian.little);
      } else if (id == 'data') {
        dataOff = off + 8;
        dataSz  = size.clamp(0, bytes.length - dataOff);
        break;
      }
      if (size == 0) break;
      off += 8 + size + (size.isOdd ? 1 : 0);
    }
    Float32List mono;
    if (fmt == 3)       mono = _f32(bd, dataOff, dataSz, ch);
    else if (bps == 24) mono = _i24(bytes, dataOff, dataSz, ch);
    else if (bps == 32) mono = _i32(bd, dataOff, dataSz, ch);
    else                mono = _i16(bd, dataOff, dataSz, ch);
    if (sr != targetSr) mono = _resample(mono, sr, targetSr);
    if (mono.length > maxSamples) return Float32List.sublistView(mono, 0, maxSamples);
    return mono;
  }

  static Float32List _i16(ByteData bd, int off, int sz, int ch) {
    final n = sz ~/ (2*ch); final o = Float32List(n);
    for (int i = 0; i < n; i++) {
      double s = 0;
      for (int c = 0; c < ch; c++) {
        final idx = off+(i*ch+c)*2;
        if (idx+1 < bd.lengthInBytes) s += bd.getInt16(idx, Endian.little)/32768.0;
      }
      o[i] = (s/ch).clamp(-1.0, 1.0);
    }
    return o;
  }

  static Float32List _i24(Uint8List b, int off, int sz, int ch) {
    final n = sz ~/ (3*ch); final o = Float32List(n);
    for (int i = 0; i < n; i++) {
      double s = 0;
      for (int c = 0; c < ch; c++) {
        final idx = off+(i*ch+c)*3;
        if (idx+2 < b.length) {
          int v = b[idx]|(b[idx+1]<<8)|(b[idx+2]<<16);
          if (v >= 0x800000) v -= 0x1000000;
          s += v/8388608.0;
        }
      }
      o[i] = (s/ch).clamp(-1.0, 1.0);
    }
    return o;
  }

  static Float32List _i32(ByteData bd, int off, int sz, int ch) {
    final n = sz ~/ (4*ch); final o = Float32List(n);
    for (int i = 0; i < n; i++) {
      double s = 0;
      for (int c = 0; c < ch; c++) {
        final idx = off+(i*ch+c)*4;
        if (idx+3 < bd.lengthInBytes) s += bd.getInt32(idx, Endian.little)/2147483648.0;
      }
      o[i] = (s/ch).clamp(-1.0, 1.0);
    }
    return o;
  }

  static Float32List _f32(ByteData bd, int off, int sz, int ch) {
    final n = sz ~/ (4*ch); final o = Float32List(n);
    for (int i = 0; i < n; i++) {
      double s = 0;
      for (int c = 0; c < ch; c++) {
        final idx = off+(i*ch+c)*4;
        if (idx+3 < bd.lengthInBytes) s += bd.getFloat32(idx, Endian.little);
      }
      o[i] = (s/ch).clamp(-1.0, 1.0);
    }
    return o;
  }

  static Float32List _resample(Float32List src, int srcSr, int dstSr) {
    final g = _gcd(srcSr, dstSr);
    final down = srcSr ~/ g; final up = dstSr ~/ g;
    if (up == 1) {
      final out = Float32List((src.length + down - 1) ~/ down);
      for (int i = 0; i < out.length; i++) out[i] = src[i * down];
      return out;
    }
    final ratio = srcSr / dstSr;
    final out   = Float32List((src.length / ratio).floor());
    for (int i = 0; i < out.length; i++) {
      final pos = i * ratio; final idx = pos.floor(); final frac = pos - idx;
      final a  = idx < src.length ? src[idx] : 0.0;
      final bv = idx+1 < src.length ? src[idx+1] : 0.0;
      out[i]   = a + frac*(bv-a);
    }
    return out;
  }

  static int _gcd(int a, int b) {
    while (b != 0) { final t = b; b = a % b; a = t; } return a;
  }
}

// ═════════════════════════════════════════════════════════════════════════════
//  MFCC extractor (offline fallback only)
// ═════════════════════════════════════════════════════════════════════════════
class MfccExtractor {
  static const int _nMfcc=40, _maxLen=300, _nMels=128, _nFft=2048,
      _hopLen=512, _sr=22050, _nFreq=_nFft~/2+1;

  static Float32List? _hann;
  static Float32List? _fb;
  static List<Float32List>? _dct;

  static Float32List extract(Float32List audio) {
    _hann ??= _makeHann();
    _fb   ??= _makeMelFb();
    _dct  ??= _makeDct();

    const pad = _nFft ~/ 2;
    final padded = Float32List(audio.length + 2*pad);
    for (int i = 0; i < pad; i++) {
      final s = pad - i;
      padded[i] = s < audio.length ? audio[s] : 0.0;
    }
    for (int i = 0; i < audio.length; i++) padded[pad+i] = audio[i];
    for (int i = 0; i < pad; i++) {
      final s = audio.length - 2 - i;
      padded[pad+audio.length+i] = s >= 0 ? audio[s] : 0.0;
    }

    final result = Float32List(_nMfcc * _maxLen);
    int fi = 0;
    for (int start = 0; start+_nFft <= padded.length && fi < _maxLen; start += _hopLen) {
      final power = Float32List(_nFreq);
      for (int k = 0; k < _nFreq; k++) {
        double re = 0, im = 0;
        final f = 2*math.pi*k/_nFft;
        for (int n = 0; n < _nFft; n++) {
          final w = padded[start+n]*_hann![n];
          re += w*math.cos(f*n); im -= w*math.sin(f*n);
        }
        power[k] = re*re + im*im;
      }
      final logMel = Float32List(_nMels);
      for (int m = 0; m < _nMels; m++) {
        double s = 0;
        for (int k = 0; k < _nFreq; k++) s += _fb![m*_nFreq+k]*power[k];
        logMel[m] = math.log(s < 1e-10 ? 1e-10 : s);
      }
      for (int c = 0; c < _nMfcc; c++) {
        double s = 0;
        final row = _dct![c];
        for (int m = 0; m < _nMels; m++) s += logMel[m]*row[m];
        result[c*_maxLen+fi] = s.isFinite ? s : 0.0;
      }
      fi++;
    }
    return result;
  }

  static Float32List _makeHann() {
    final w = Float32List(_nFft);
    for (int i = 0; i < _nFft; i++) w[i] = 0.5*(1-math.cos(2*math.pi*i/_nFft));
    return w;
  }

  static Float32List _makeMelFb() {
    const fSp=200.0/3, minLogHz=1000.0, minLogMel=minLogHz/fSp;
    final logStep = math.ln2/6.0;
    double hzToMel(double hz) => hz >= minLogHz
        ? minLogMel + math.log(hz/minLogHz)/logStep : hz/fSp;
    double melToHz(double mel) => mel >= minLogMel
        ? minLogHz*math.exp(logStep*(mel-minLogMel)) : fSp*mel;
    final melMin=hzToMel(0), melMax=hzToMel(_sr/2.0);
    final melPts=List<double>.generate(
        _nMels+2, (i)=>melMin+(melMax-melMin)*i/(_nMels+1));
    final hzPts=melPts.map(melToHz).toList();
    final bins=hzPts.map((h)=>((_nFft+1)*h/_sr).floor().clamp(0,_nFreq-1)).toList();
    final fb=Float32List(_nMels*_nFreq);
    for (int m=0; m<_nMels; m++) {
      final fL=bins[m], fC=bins[m+1], fR=bins[m+2];
      if (fC>fL) for (int k=fL; k<fC&&k<_nFreq; k++) fb[m*_nFreq+k]=(k-fL)/(fC-fL);
      if (fR>fC) for (int k=fC; k<=fR&&k<_nFreq; k++) fb[m*_nFreq+k]=(fR-k)/(fR-fC);
      final enorm=2.0/(hzPts[m+2]-hzPts[m]);
      for (int k=fL; k<=fR&&k<_nFreq; k++) fb[m*_nFreq+k]*=enorm;
    }
    return fb;
  }

  static List<Float32List> _makeDct() => List.generate(_nMfcc, (c) {
    final norm = c==0 ? math.sqrt(1.0/(4*_nMels)) : math.sqrt(1.0/(2*_nMels));
    return Float32List.fromList(List.generate(_nMels,
            (m) => norm*2*math.cos(math.pi*c*(2*m+1)/(2*_nMels))));
  });
}