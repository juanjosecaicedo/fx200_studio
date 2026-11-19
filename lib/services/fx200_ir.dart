import 'dart:async';
import 'dart:typed_data';

import 'fx200_backup.dart';
import 'fx200_protocol.dart';

/// User impulse responses (CAB models 31-80), decoded from
/// `import-IRs.pcapng` (official editor loading two WAV files) and checked
/// sample by sample against the source WAVs:
///
/// * slot record, 0xC0F (3087) bytes: 1024 samples at 44.1 kHz, 24-bit
///   signed, stored in two blocks of 512 samples, each block as three
///   512-byte planes (high, middle, low byte), then a 15-byte ASCII name;
/// * the editor resamples to 44.1 kHz (linear interpolation matches within
///   about -55 dB) and truncates to 1024 points, with no normalization;
/// * upload: `0xE1 [slot 0..49, chunk 1..7, data]` (six 512-byte chunks and a
///   15-byte last one); the pedal acknowledges each with `0xE1 [chunk]`;
/// * delete: zero record named `Empty` + `0xE4 [slot]` (see [fx200DeleteIr]);
/// * names of the 50 slots come in `0x85` (50 × 15 bytes, unused slots read
///   `"EMPTY"` padded with spaces).
class Fx200Ir {
  Fx200Ir._();

  static const int slotCount = 50;
  static const int firstCabModel = 31;
  static const int points = 1024;
  static const int sampleRate = 44100;
  static const int nameLength = 15;
  static const int recordSize = points * 3 + nameLength;
  static const int opUpload = 0xe1;
  static const int opNames = 0x85;
  static const int opDelete = 0xe4;
  static const int _block = 512;

  /// Resamples [samples] (-1..1, mono) from [sourceRate] to 44.1 kHz and
  /// builds the 3087-byte slot record.
  static Uint8List encodeRecord(
    List<double> samples,
    int sourceRate,
    String name,
  ) {
    final ratio = sourceRate / sampleRate;
    final ints = List<int>.filled(points, 0);
    for (var i = 0; i < points; i++) {
      final t = i * ratio;
      final k = t.floor();
      final f = t - k;
      final a = k < samples.length ? samples[k] : 0.0;
      final b = k + 1 < samples.length ? samples[k + 1] : 0.0;
      final v = ((a + (b - a) * f) * 8388608.0).truncate();
      ints[i] = v.clamp(-8388608, 8388607);
    }
    final out = Uint8List(recordSize);
    for (var blk = 0; blk < 2; blk++) {
      final base = blk * _block * 3;
      for (var j = 0; j < _block; j++) {
        final v = ints[blk * _block + j] & 0xffffff;
        out[base + j] = (v >> 16) & 0xff;
        out[base + _block + j] = (v >> 8) & 0xff;
        out[base + 2 * _block + j] = v & 0xff;
      }
    }
    final ascii = sanitizeName(name).codeUnits;
    out.setRange(points * 3, points * 3 + ascii.length, ascii);
    return out;
  }

  /// Decodes the 1024 samples of a slot record (-1..1).
  static List<double> decodeSamples(Uint8List record) {
    final out = <double>[];
    for (var blk = 0; blk < 2; blk++) {
      final base = blk * _block * 3;
      for (var j = 0; j < _block; j++) {
        var v =
            record[base + j] << 16 |
            record[base + _block + j] << 8 |
            record[base + 2 * _block + j];
        if (v >= 0x800000) v -= 0x1000000;
        out.add(v / 8388608.0);
      }
    }
    return out;
  }

  /// Printable ASCII, at most 15 characters (the official editor keeps the
  /// first 15 characters of the file name, e.g. `Disturbed_Stric`).
  static String sanitizeName(String name) {
    final clean = name
        .replaceAll(RegExp(r'\.wav$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^\x20-\x7e]'), '_');
    return clean.length > nameLength ? clean.substring(0, nameLength) : clean;
  }

  /// Slot names from a `0x85` body (index 0 = CAB model 31). Unused slots
  /// (`EMPTY`) are returned as empty strings.
  static List<String> decodeNames(List<int> body) {
    final names = <String>[];
    for (var i = 0; i < slotCount; i++) {
      final start = i * nameLength;
      if (start + nameLength > body.length) {
        names.add('');
        continue;
      }
      final chars = <int>[];
      for (final b in body.sublist(start, start + nameLength)) {
        if (b == 0) break;
        chars.add(b >= 0x20 && b < 0x7f ? b : 0x5f);
      }
      final n = String.fromCharCodes(chars).trim();
      names.add(n.toUpperCase() == 'EMPTY' ? '' : n);
    }
    return names;
  }

  /// `0xE1` body for [chunk] (1..7) of [record] into [slot] (0..49).
  static Uint8List chunkBody(int slot, int chunk, Uint8List record) {
    final start = (chunk - 1) * _block;
    final end = chunk == 7 ? recordSize : start + _block;
    return Uint8List.fromList(<int>[
      slot,
      chunk,
      ...record.sublist(start, end),
    ]);
  }
}

/// Uploads [record] into user IR [slot] (0..49 = CAB 31..80), waiting for
/// the pedal's acknowledgement of each chunk like the official editor.
Future<void> fx200UploadIr(
  Fx200DeviceLink link,
  int slot,
  Uint8List record, {
  Duration ackTimeout = const Duration(seconds: 2),
  void Function(double fraction)? onProgress,
}) async {
  if (slot < 0 || slot >= Fx200Ir.slotCount) {
    throw RangeError.range(slot, 0, Fx200Ir.slotCount - 1, 'slot');
  }
  if (record.length != Fx200Ir.recordSize) {
    throw ArgumentError('IR record must be ${Fx200Ir.recordSize} bytes.');
  }
  if (!link.isConnected) throw StateError('FX200 is not connected.');
  await link.waitUntilReady();
  var waitingFor = 0;
  Completer<void>? pending;
  final sub = link.frames.listen((f) {
    if (f.opcode != Fx200Ir.opUpload || f.body.isEmpty) return;
    if ((f.body[0] & 0xff) == waitingFor && !(pending?.isCompleted ?? true)) {
      pending!.complete();
    }
  });
  try {
    for (var chunk = 1; chunk <= 7; chunk++) {
      waitingFor = chunk;
      pending = Completer<void>();
      link.sendPacket(
        Fx200Protocol.buildRawPacket(
          Fx200Ir.opUpload,
          Fx200Ir.chunkBody(slot, chunk, record),
        ),
      );
      await pending.future.timeout(
        ackTimeout,
        onTimeout: () => throw TimeoutException(
          'The FX200 did not confirm IR chunk $chunk/7.',
        ),
      );
      onProgress?.call(chunk / 7);
    }
  } finally {
    await sub.cancel();
  }
}

/// Clears user IR [slot] like the official editor (`borrar-IRs.pcapng`):
/// a zero record named `Empty` sent with `0xE1`, then `0xE4 [slot]` (the
/// pedal does not answer `0xE4`).
Future<void> fx200DeleteIr(
  Fx200DeviceLink link,
  int slot, {
  Duration ackTimeout = const Duration(seconds: 2),
  void Function(double fraction)? onProgress,
}) async {
  final record = Uint8List(Fx200Ir.recordSize)
    ..setRange(Fx200Ir.points * 3, Fx200Ir.points * 3 + 5, 'Empty'.codeUnits);
  await fx200UploadIr(
    link,
    slot,
    record,
    ackTimeout: ackTimeout,
    onProgress: onProgress,
  );
  link.sendPacket(Fx200Protocol.buildRawPacket(Fx200Ir.opDelete, <int>[slot]));
  await Future<void>.delayed(const Duration(milliseconds: 50));
}
