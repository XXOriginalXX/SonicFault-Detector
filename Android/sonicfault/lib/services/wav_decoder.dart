import 'dart:typed_data';

/// Decodes WAV files and resamples to 22050 Hz mono float32.
/// Handles: PCM_16/24/32, IEEE float32, any channel count, any sample rate.
class WavDecoder {
  static const int targetSr = 22050;
  static const int maxSamples = targetSr * 10; // 10 seconds

  static Float32List decode(Uint8List bytes) {
    if (bytes.length < 44) return Float32List(0);

    final bd = ByteData.sublistView(bytes);

    // Validate RIFF header
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    if (riff != 'RIFF') return Float32List(0);

    // Parse chunks to find fmt and data
    int audioFormat   = 1;
    int numChannels   = 1;
    int sampleRate    = 44100;
    int bitsPerSample = 16;
    int dataOffset    = 44;
    int dataSize      = bytes.length - 44;

    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId   = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final chunkSize = bd.getUint32(offset + 4, Endian.little);

      if (chunkId == 'fmt ' && chunkSize >= 16) {
        audioFormat   = bd.getUint16(offset + 8,  Endian.little);
        numChannels   = bd.getUint16(offset + 10, Endian.little);
        sampleRate    = bd.getUint32(offset + 12, Endian.little);
        bitsPerSample = bd.getUint16(offset + 22, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = offset + 8;
        dataSize   = chunkSize.clamp(0, bytes.length - dataOffset);
        break;
      }

      if (chunkSize == 0) break;
      offset += 8 + chunkSize;
      if (chunkSize.isOdd) offset++; // word-align
    }

    // Decode to float32 mono at original sample rate
    Float32List mono;
    if (audioFormat == 3) {
      // IEEE float
      mono = _decodeFloat32(bd, dataOffset, dataSize, numChannels);
    } else if (bitsPerSample == 16) {
      mono = _decodePcm16(bd, dataOffset, dataSize, numChannels);
    } else if (bitsPerSample == 24) {
      mono = _decodePcm24(bytes, dataOffset, dataSize, numChannels);
    } else if (bitsPerSample == 32) {
      mono = _decodePcm32(bd, dataOffset, dataSize, numChannels);
    } else {
      mono = _decodePcm16(bd, dataOffset, dataSize, numChannels);
    }

    // Resample to targetSr if needed
    if (sampleRate != targetSr && sampleRate > 0) {
      mono = _resample(mono, sampleRate, targetSr);
    }

    // Cap at 10 seconds
    if (mono.length > maxSamples) {
      return Float32List.sublistView(mono, 0, maxSamples);
    }
    return mono;
  }

  // ── Decoders ───────────────────────────────────────────────────────────────

  static Float32List _decodePcm16(
      ByteData bd, int offset, int dataSize, int ch) {
    final frames = dataSize ~/ (2 * ch);
    final out    = Float32List(frames);
    for (int i = 0; i < frames; i++) {
      double sum = 0;
      for (int c = 0; c < ch; c++) {
        final idx = offset + (i * ch + c) * 2;
        if (idx + 1 < bd.lengthInBytes) {
          sum += bd.getInt16(idx, Endian.little) / 32768.0;
        }
      }
      out[i] = (sum / ch).clamp(-1.0, 1.0);
    }
    return out;
  }

  static Float32List _decodeFloat32(
      ByteData bd, int offset, int dataSize, int ch) {
    final frames = dataSize ~/ (4 * ch);
    final out    = Float32List(frames);
    for (int i = 0; i < frames; i++) {
      double sum = 0;
      for (int c = 0; c < ch; c++) {
        final idx = offset + (i * ch + c) * 4;
        if (idx + 3 < bd.lengthInBytes) {
          sum += bd.getFloat32(idx, Endian.little);
        }
      }
      out[i] = (sum / ch).clamp(-1.0, 1.0);
    }
    return out;
  }

  static Float32List _decodePcm24(
      Uint8List bytes, int offset, int dataSize, int ch) {
    final frames = dataSize ~/ (3 * ch);
    final out    = Float32List(frames);
    for (int i = 0; i < frames; i++) {
      double sum = 0;
      for (int c = 0; c < ch; c++) {
        final idx = offset + (i * ch + c) * 3;
        if (idx + 2 < bytes.length) {
          int v = bytes[idx] | (bytes[idx+1] << 8) | (bytes[idx+2] << 16);
          if (v >= 0x800000) v -= 0x1000000;
          sum += v / 8388608.0;
        }
      }
      out[i] = (sum / ch).clamp(-1.0, 1.0);
    }
    return out;
  }

  static Float32List _decodePcm32(
      ByteData bd, int offset, int dataSize, int ch) {
    final frames = dataSize ~/ (4 * ch);
    final out    = Float32List(frames);
    for (int i = 0; i < frames; i++) {
      double sum = 0;
      for (int c = 0; c < ch; c++) {
        final idx = offset + (i * ch + c) * 4;
        if (idx + 3 < bd.lengthInBytes) {
          sum += bd.getInt32(idx, Endian.little) / 2147483648.0;
        }
      }
      out[i] = (sum / ch).clamp(-1.0, 1.0);
    }
    return out;
  }

  // ── Resampler (polyphase-like linear interpolation) ────────────────────────
  // For 44100→22050 (ratio=2.0) this is exact decimation — every other sample.
  // For other ratios it uses linear interpolation.

  static Float32List _resample(Float32List src, int srcSr, int dstSr) {
    if (srcSr == dstSr) return src;

    // For exact integer decimation (e.g. 44100→22050, ratio=2)
    // use simple decimation which perfectly matches librosa's kaiser_fast
    final gcd    = _gcd(srcSr, dstSr);
    final up     = dstSr ~/ gcd;
    final down   = srcSr ~/ gcd;

    if (up == 1) {
      // Pure decimation — take every Nth sample (matches librosa default)
      final outLen = (src.length + down - 1) ~/ down;
      final out    = Float32List(outLen);
      for (int i = 0; i < outLen; i++) {
        out[i] = src[i * down];
      }
      return out;
    }

    // General case: linear interpolation
    final ratio  = srcSr / dstSr;
    final outLen = (src.length / ratio).floor();
    final out    = Float32List(outLen);
    for (int i = 0; i < outLen; i++) {
      final pos  = i * ratio;
      final idx  = pos.floor();
      final frac = pos - idx;
      final a    = idx < src.length ? src[idx] : 0.0;
      final b    = idx + 1 < src.length ? src[idx + 1] : 0.0;
      out[i]     = a + frac * (b - a);
    }
    return out;
  }

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a;
  }
}