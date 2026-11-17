import 'dart:math' as math;
import 'dart:typed_data';

/// Parsed RIFF/WAVE Impulse Response (IR) file for FX200 (`44.1 kHz / 24-bit / 1024 pts`).
class IrWavFile {
  const IrWavFile({
    required this.sampleRate,
    required this.channels,
    required this.bitsPerSample,
    required this.audioFormat,
    required this.sampleCount,
    required this.samples,
  });

  final int sampleRate;
  final int channels;
  final int bitsPerSample;
  final int audioFormat;
  final int sampleCount;
  final List<double> samples;

  bool get isFx200NativeFormat =>
      audioFormat == 1 &&
      sampleRate == 44100 &&
      bitsPerSample == 24 &&
      channels == 1;

  bool get needsConversion => !isFx200NativeFormat || sampleCount != 1024;

  /// Parses a RIFF/WAVE binary into an [IrWavFile].
  /// Throws [FormatException] on invalid headers or unsupported bit depth.
  factory IrWavFile.fromBytes(Uint8List bytes) {
    if (bytes.length < 44) {
      throw const FormatException('WAV file too short.');
    }
    final bd = ByteData.sublistView(bytes);
    if (_ascii(bytes, 0, 4) != 'RIFF' || _ascii(bytes, 8, 12) != 'WAVE') {
      throw const FormatException('Not a valid RIFF/WAVE file.');
    }

    int? audioFormat;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? dataOffset;
    int? dataSize;

    var offset = 12;
    while (offset + 8 <= bytes.length) {
      final chunkId = _ascii(bytes, offset, offset + 4);
      final chunkSize = bd.getUint32(offset + 4, Endian.little);
      final bodyStart = offset + 8;
      if (bodyStart + chunkSize > bytes.length) break;

      if (chunkId == 'fmt ' && chunkSize >= 16) {
        audioFormat = bd.getUint16(bodyStart, Endian.little);
        channels = bd.getUint16(bodyStart + 2, Endian.little);
        sampleRate = bd.getUint32(bodyStart + 4, Endian.little);
        bitsPerSample = bd.getUint16(bodyStart + 14, Endian.little);
      } else if (chunkId == 'data') {
        dataOffset = bodyStart;
        dataSize = chunkSize;
      }

      offset = bodyStart + chunkSize + (chunkSize.isOdd ? 1 : 0);
    }

    if (audioFormat == null ||
        channels == null ||
        sampleRate == null ||
        bitsPerSample == null ||
        dataOffset == null ||
        dataSize == null) {
      throw const FormatException('Missing fmt or data chunk in WAV.');
    }

    if (channels < 1) {
      throw const FormatException('Invalid channel count.');
    }

    final bytesPerSample = bitsPerSample ~/ 8;
    if (bytesPerSample <= 0) {
      throw const FormatException('Unsupported bitsPerSample.');
    }
    final frameBytes = bytesPerSample * channels;
    final totalFrames = dataSize ~/ frameBytes;
    final samples = <double>[];

    for (var i = 0; i < totalFrames; i++) {
      final pos = dataOffset + i * frameBytes;
      if (bitsPerSample == 16 && audioFormat == 1) {
        samples.add(bd.getInt16(pos, Endian.little) / 32768.0);
      } else if (bitsPerSample == 24 && audioFormat == 1) {
        var v = bytes[pos] | (bytes[pos + 1] << 8) | (bytes[pos + 2] << 16);
        if ((v & 0x800000) != 0) v |= ~0xFFFFFF;
        samples.add(v / 8388608.0);
      } else if (bitsPerSample == 32 && audioFormat == 3) {
        samples.add(bd.getFloat32(pos, Endian.little));
      } else {
        throw FormatException(
          'Unsupported WAV format: fmt=$audioFormat, bits=$bitsPerSample.',
        );
      }
    }

    return IrWavFile(
      sampleRate: sampleRate,
      channels: channels,
      bitsPerSample: bitsPerSample,
      audioFormat: audioFormat,
      sampleCount: totalFrames,
      samples: samples,
    );
  }

  static String _ascii(Uint8List b, int start, int end) =>
      String.fromCharCodes(b.sublist(start, end));

  /// Converts this IR to a `44.1 kHz / 24-bit / 1024-point` mono RIFF/WAVE
  /// ready for the Flamma FX200.
  Uint8List toFx200WavBytes() {
    const targetRate = 44100;
    const targetPoints = 1024;

    final ratio = sampleRate / targetRate;
    final resampled = List<double>.filled(targetPoints, 0.0);
    for (var i = 0; i < targetPoints; i++) {
      final srcPos = i * ratio;
      final idx0 = srcPos.floor();
      if (idx0 >= samples.length) break;
      final idx1 = idx0 + 1 < samples.length ? idx0 + 1 : idx0;
      final frac = srcPos - idx0;
      resampled[i] = samples[idx0] * (1.0 - frac) + samples[idx1] * frac;
    }

    // Apply a 64-sample cosine fade-out if the original IR was longer than 1024 pts.
    if ((samples.length / ratio) > targetPoints) {
      const fadeLen = 64;
      for (var i = 0; i < fadeLen; i++) {
        final idx = targetPoints - fadeLen + i;
        final gain = 0.5 * (1.0 + math.cos(math.pi * (i + 1) / fadeLen));
        resampled[idx] *= gain;
      }
    }

    const dataBytes = targetPoints * 3;
    const totalBytes = 44 + dataBytes;
    final out = Uint8List(totalBytes);
    final bd = ByteData.sublistView(out);

    out.setRange(0, 4, 'RIFF'.codeUnits);
    bd.setUint32(4, totalBytes - 8, Endian.little);
    out.setRange(8, 12, 'WAVE'.codeUnits);
    out.setRange(12, 16, 'fmt '.codeUnits);
    bd.setUint32(16, 16, Endian.little);
    bd.setUint16(20, 1, Endian.little);
    bd.setUint16(22, 1, Endian.little);
    bd.setUint32(24, targetRate, Endian.little);
    bd.setUint32(28, targetRate * 3, Endian.little);
    bd.setUint16(32, 3, Endian.little);
    bd.setUint16(34, 24, Endian.little);
    out.setRange(36, 40, 'data'.codeUnits);
    bd.setUint32(40, dataBytes, Endian.little);

    for (var i = 0; i < targetPoints; i++) {
      final clamped = resampled[i].clamp(-1.0, 0.99999988);
      var q = (clamped * 8388608.0).round();
      if (q > 0x7FFFFF) q = 0x7FFFFF;
      if (q < -0x800000) q = -0x800000;
      final pos = 44 + i * 3;
      out[pos] = q & 0xff;
      out[pos + 1] = (q >> 8) & 0xff;
      out[pos + 2] = (q >> 16) & 0xff;
    }
    return out;
  }
}
