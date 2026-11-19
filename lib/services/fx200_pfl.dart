import 'dart:async';
import 'dart:typed_data';

import '../core/l10n/l10n.dart';
import 'fx200_backup.dart';
import 'fx200_protocol.dart';

/// Preset file of the official FX200 editor (`.pfl`) and the `0x83` preset
/// upload it uses. Reverse-engineered from `FX200.exe`:
///
/// * writer `0x420b81`: 0x80-byte header — `"FX200"` at 0x00 and the editor
///   version (`"V1.1.8"`) at 0x20, zero padded — followed by the editor's
///   `PresetPara_TypeDef` (0x840 bytes);
/// * `PresetPara_TypeDef` is byte-for-byte the first 0x840 bytes of the
///   pedal's 4096-byte preset record, i.e. of the `0xA5` / `0x86` dump
///   (handler `0x42b460` copies chunks 0-3 and 64 bytes of chunk 4);
/// * the reader accepts the current 0x8C0-byte file; older editor versions
///   wrote other sizes (0x840 / 0xA20 / 0x660) — a bare 0x840 record is
///   accepted too, the others are rejected.
class Fx200Pfl {
  Fx200Pfl._();

  static const int headerSize = 0x80;
  static const int structSize = 0x840;
  static const int fileSize = headerSize + structSize;
  static const String magic = 'FX200';
  static const String editorVersion = 'V1.1.8';
  static const String fileExtension = 'pfl';

  /// Builds a `.pfl` file from a preset record (only its first 0x840 bytes
  /// are used).
  static Uint8List encode(Uint8List record) {
    if (record.length < structSize) {
      throw ArgumentError('Preset record too short (${record.length} B).');
    }
    final out = Uint8List(fileSize);
    out.setRange(0, magic.length, magic.codeUnits);
    out.setRange(0x20, 0x20 + editorVersion.length, editorVersion.codeUnits);
    out.setRange(headerSize, fileSize, record);
    return out;
  }

  /// Returns the 0x840-byte preset struct of a `.pfl` file.
  static Uint8List decode(Uint8List file) {
    if (file.length == structSize) return Uint8List.fromList(file);
    if (file.length != fileSize) {
      throw FormatException(
        'Unsupported .pfl size ${file.length} B (expected $fileSize).',
      );
    }
    final head = String.fromCharCodes(file.sublist(0, magic.length));
    if (head != magic) {
      throw const FormatException('Not an FX200 preset file.');
    }
    return Uint8List.fromList(file.sublist(headerSize, fileSize));
  }

  /// Preset name stored in the first 16 bytes of the struct.
  static String nameOf(Uint8List struct) {
    final chars = <int>[];
    for (var i = 0; i < 16 && i < struct.length; i++) {
      final b = struct[i];
      if (b == 0) break;
      if (b >= 32 && b < 127) chars.add(b);
    }
    return String.fromCharCodes(chars).trim();
  }

  /// File name in the official editor's style: bank (1-100) + A/B + name,
  /// e.g. `03A DR Z.pfl`.
  static String fileNameFor(int index, String name) {
    final bank = (index ~/ 2 + 1).toString().padLeft(2, '0');
    final side = index.isEven ? 'A' : 'B';
    final safe = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return '$bank$side ${safe.isEmpty ? 'Preset' : safe}.$fileExtension';
  }

  /// `0x83` upload body for [chunk] of [struct] into preset [index]:
  /// `[0x01, idxHi, idxLo, chunk, 512 data bytes]` (zero padded past 0x840).
  static Uint8List uploadBody(int index, int chunk, Uint8List struct) {
    final body = Uint8List(4 + Fx200Protocol.presetDumpChunkBytes);
    body[0] = 0x01;
    body[1] = (index >> 8) & 0xff;
    body[2] = index & 0xff;
    body[3] = chunk & 0xff;
    final start = chunk * Fx200Protocol.presetDumpChunkBytes;
    for (var i = 0; i < Fx200Protocol.presetDumpChunkBytes; i++) {
      final src = start + i;
      if (src >= structSize || src >= struct.length) break;
      body[4 + i] = struct[src];
    }
    return body;
  }
}

/// Writes a preset struct into slot [index] the way `FX200.exe` does
/// (`0x4175a0` + `0x42c450`): the PC sends chunk 0, then the pedal asks for
/// each following chunk with an `0x83` frame whose `body[3]` is `n` and the
/// PC answers with chunk `n + 1` (the official editor answers `n` up to 6).
///
/// Completes when the pedal stops asking ([quiet] after its last request).
/// Throws if the pedal never asks for a chunk, since then nothing was
/// written.
Future<void> fx200UploadPresetStruct(
  Fx200DeviceLink link,
  int index,
  Uint8List struct, {
  Duration firstRequestTimeout = const Duration(seconds: 3),
  Duration quiet = const Duration(milliseconds: 800),
}) async {
  if (!link.isConnected) throw StateError('FX200 is not connected.');
  await link.waitUntilReady();
  var requests = 0;
  Timer? quietTimer;
  final done = Completer<void>();
  void armQuiet() {
    quietTimer?.cancel();
    quietTimer = Timer(quiet, () {
      if (!done.isCompleted) done.complete();
    });
  }

  final sub = link.frames.listen((f) {
    if (f.opcode != Fx200Protocol.opCmd83 || f.body.length < 4) return;
    final n = f.body[3] & 0xff;
    if (n > 6) return;
    requests++;
    link.sendPacket(
      Fx200Protocol.buildRawPacket(
        Fx200Protocol.opCmd83,
        Fx200Pfl.uploadBody(index, n + 1, struct),
      ),
    );
    if (n == 6) {
      quietTimer?.cancel();
      if (!done.isCompleted) done.complete();
    } else {
      armQuiet();
    }
  });
  try {
    link.sendPacket(
      Fx200Protocol.buildRawPacket(
        Fx200Protocol.opCmd83,
        Fx200Pfl.uploadBody(index, 0, struct),
      ),
    );
    await done.future.timeout(
      firstRequestTimeout,
      onTimeout: () {
        if (requests == 0) {
          throw TimeoutException(
            tr(
              'The FX200 did not request the preset data (0x83); nothing was written.',
            ),
          );
        }
      },
    );
    if (!done.isCompleted) await done.future;
  } finally {
    quietTimer?.cancel();
    await sub.cancel();
  }
}
