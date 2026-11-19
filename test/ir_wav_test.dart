import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/models/ir_wav.dart';

Uint8List _buildTestWav24({required int sampleRate, required int sampleCount}) {
  final dataBytes = sampleCount * 3;
  final totalBytes = 44 + dataBytes;
  final buf = Uint8List(totalBytes);
  final bd = ByteData.sublistView(buf);

  buf.setRange(0, 4, 'RIFF'.codeUnits);
  bd.setUint32(4, totalBytes - 8, Endian.little);
  buf.setRange(8, 12, 'WAVE'.codeUnits);
  buf.setRange(12, 16, 'fmt '.codeUnits);
  bd.setUint32(16, 16, Endian.little);
  bd.setUint16(20, 1, Endian.little); // PCM
  bd.setUint16(22, 1, Endian.little); // Mono
  bd.setUint32(24, sampleRate, Endian.little);
  bd.setUint32(28, sampleRate * 3, Endian.little);
  bd.setUint16(32, 3, Endian.little);
  bd.setUint16(34, 24, Endian.little);
  buf.setRange(36, 40, 'data'.codeUnits);
  bd.setUint32(40, dataBytes, Endian.little);

  // Write a unit impulse at sample 0 (0x400000 = +0.5)
  buf[44] = 0x00;
  buf[45] = 0x00;
  buf[46] = 0x40;
  return buf;
}

void main() {
  test('parses 44.1 kHz 24-bit 1024-pt mono IR WAV', () {
    final wavBytes = _buildTestWav24(sampleRate: 44100, sampleCount: 1024);
    final ir = IrWavFile.fromBytes(wavBytes);

    expect(ir.sampleRate, 44100);
    expect(ir.bitsPerSample, 24);
    expect(ir.channels, 1);
    expect(ir.sampleCount, 1024);
    expect(ir.isFx200NativeFormat, isTrue);
    expect(ir.needsConversion, isFalse);
    expect(ir.samples.first, closeTo(0.5, 1e-5));
  });

  test('throws FormatException on invalid WAV header', () {
    expect(
      () => IrWavFile.fromBytes(Uint8List.fromList(List<int>.filled(44, 0))),
      throwsFormatException,
    );
  });

  test('resamples 48 kHz 2048-pt IR to FX200 44.1 kHz 24-bit 1024-pt WAV', () {
    final src = _buildTestWav24(sampleRate: 48000, sampleCount: 2048);
    final parsedSrc = IrWavFile.fromBytes(src);
    expect(parsedSrc.needsConversion, isTrue);

    final convertedBytes = parsedSrc.toFx200WavBytes();
    expect(convertedBytes.length, 44 + 1024 * 3);

    final parsedDst = IrWavFile.fromBytes(convertedBytes);
    expect(parsedDst.isFx200NativeFormat, isTrue);
    expect(parsedDst.needsConversion, isFalse);
    expect(parsedDst.sampleCount, 1024);
  });
}
