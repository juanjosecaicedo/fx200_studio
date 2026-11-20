import 'dart:typed_data';

import '../core/fx200_constants.dart';
import 'fx200_device_settings.dart';

export 'fx200_device_settings.dart';

/// Decoded state of one FX200 effect module (`0x91`..`0x9A`).
class Fx200ModuleState {
  const Fx200ModuleState({
    required this.opcode,
    required this.slotIndex,
    required this.name,
    required this.enabled,
    required this.modelId,
    required this.params,
  });

  final int opcode;
  final int slotIndex;
  final String name;
  final bool enabled;
  final int modelId;
  final List<int> params;

  Fx200ModuleState copyWith({bool? enabled, int? modelId, List<int>? params}) {
    return Fx200ModuleState(
      opcode: opcode,
      slotIndex: slotIndex,
      name: name,
      enabled: enabled ?? this.enabled,
      modelId: modelId ?? this.modelId,
      params: params ?? this.params,
    );
  }
}

/// Reassembles single- or multi-packet HID responses (`[chunkLen, ...]`)
/// into verified `(opcode, body)` frames.
class Fx200FrameAssembler {
  final List<int> _buffer = <int>[];
  int _expectedFrameLength = 0;

  /// Feeds one raw 64-byte HID IN packet (`[chunkLen, ...data...]`).
  /// Returns a list of complete, CRC-verified `(opcode, body)` frames.
  List<({int opcode, Uint8List body})> feedPacket(List<int> rawPacket) {
    if (rawPacket.isEmpty) return const <({int opcode, Uint8List body})>[];
    final chunkLen = rawPacket[0] & 0xff;
    if (chunkLen <= 0 || chunkLen > rawPacket.length - 1) {
      return const <({int opcode, Uint8List body})>[];
    }

    final chunk = rawPacket.sublist(1, 1 + chunkLen);
    if (_buffer.isEmpty) {
      if (chunk.length >= 4 && chunk[0] == 0xaa && chunk[1] == 0x55) {
        final plen = (chunk[2] & 0xff) | ((chunk[3] & 0xff) << 8);
        _expectedFrameLength = plen + 6;
        _buffer.addAll(chunk);
      } else {
        return const <({int opcode, Uint8List body})>[];
      }
    } else {
      // If a new frame header arrives unexpectedly, restart cleanly.
      if (chunk.length >= 4 &&
          chunk[0] == 0xaa &&
          chunk[1] == 0x55 &&
          _buffer.length < _expectedFrameLength) {
        _buffer.clear();
        final plen = (chunk[2] & 0xff) | ((chunk[3] & 0xff) << 8);
        _expectedFrameLength = plen + 6;
      }
      _buffer.addAll(chunk);
    }

    if (_expectedFrameLength > 0 && _buffer.length >= _expectedFrameLength) {
      final frame = Uint8List.fromList(
        _buffer.sublist(0, _expectedFrameLength),
      );
      _buffer.clear();
      _expectedFrameLength = 0;

      if (!Fx200Protocol.verifyFrame(frame)) {
        return const <({int opcode, Uint8List body})>[];
      }
      final plen = (frame[2] & 0xff) | ((frame[3] & 0xff) << 8);
      if (plen < 1) return const <({int opcode, Uint8List body})>[];
      final opcode = frame[4] & 0xff;
      final body = Uint8List.fromList(frame.sublist(5, 4 + plen));
      return <({int opcode, Uint8List body})>[(opcode: opcode, body: body)];
    }

    return const <({int opcode, Uint8List body})>[];
  }

  void reset() {
    _buffer.clear();
    _expectedFrameLength = 0;
  }
}

/// Packet framing and CRC-16/CCITT codec derived from `FX200.exe` (`sub_42a6a0`).
class Fx200Protocol {
  Fx200Protocol._();

  /// Command opcodes observed in `FX200.exe` and `captura.pcapng`.
  static const int opProbe00 = 0x00; // 07 aa 55 01 00 00 c8 cf
  static const int opHandshake =
      0x84; // payload: [0x84, 0x00, 0x00] -> CRC 0xF6 0xB7
  static const int opCmd83 = 0x83; // preset upload chunk (see Fx200Pfl)
  static const int opCmdA0 = 0xa0; // len 0x15
  static const int opCmdA1 = 0xa1; // len 0x2f: global SYSTEM settings (46 B)
  static const int opCmdA3 = 0xa3; // len 0x0b: per-preset EXP pedal assignment
  static const int opCmdA4 = 0xa4; // len 0x06
  static const int opPresetList = 0xa5; // multi-packet preset/IR list
  static const int opPresetDump86 =
      0x86; // single-preset dump (same layout as 0xA5)
  static const int opPresetRead = 0xa6; // len 0x11
  static const int opPresetSave = 0xa8; // len 0x12 (index + 16-byte ASCII name)
  static const int opCmdAd = 0xad; // len 0x0b: drum machine / metronome
  static const int opCmdAe = 0xae; // len 0x05: VOLUME pedal range
  static const int opCmdBb =
      0xbb; // len 0x03: "MERGE_STATUS"; last frame after 0xA6
  static const int opCmdE0 = 0xe0; // 07 aa 55 01 00 e0 35 e1

  static const List<String> moduleNames = <String>[
    'FX',
    'DS / OD',
    'AMP',
    'CAB',
    'FX LOOP',
    'NS',
    'EQ',
    'MOD',
    'DLY',
    'REV',
  ];

  /// Decodes a `0x91`..`0x9A` module state frame (`[enabled(u16BE), model(u16BE), ...params(u16BE)]`).
  static Fx200ModuleState? decodeModuleFrame(int opcode, List<int> body) {
    if (opcode < 0x91 || opcode > 0x9a || body.length < 4) {
      return null;
    }
    final slotIndex = opcode - 0x91;
    final words = <int>[];
    for (var i = 0; i + 1 < body.length; i += 2) {
      words.add(((body[i] & 0xff) << 8) | (body[i + 1] & 0xff));
    }
    return Fx200ModuleState(
      opcode: opcode,
      slotIndex: slotIndex,
      name: moduleNames[slotIndex],
      enabled: words[0] != 0,
      modelId: words[1],
      params: words.length > 2 ? words.sublist(2) : const <int>[],
    );
  }

  /// Encodes an [Fx200ModuleState] back into a `0x91`..`0x9A` HID packet.
  static Uint8List encodeModuleFrame(Fx200ModuleState state) {
    final words = <int>[state.enabled ? 1 : 0, state.modelId, ...state.params];
    final payload = <int>[state.opcode];
    for (final w in words) {
      payload.add((w >> 8) & 0xff);
      payload.add(w & 0xff);
    }
    return buildHidPacket(payload: payload);
  }

  /// Builds the `0x84` device-info request (`FX200.exe` sub_402520 sends the
  /// same payload); the pedal answers `0x10 [0x84, 16-byte device string]`.
  static Uint8List buildHandshakePacket() =>
      buildHidPacket(payload: const <int>[opHandshake, 0x00, 0x00]);

  /// Builds a `0xA6` preset-read HID packet for `presetIndex` (`0..199`).
  static Uint8List buildPresetReadPacket(int presetIndex) {
    final clamped = presetIndex.clamp(0, Fx200Constants.presetPatchCount - 1);
    return buildHidPacket(
      payload: <int>[opPresetRead, clamped, ...List<int>.filled(15, 0)],
    );
  }

  /// Decodes a `0xA5` multi-packet preset dump (`body[0] == 0x80`,
  /// `body[2] == presetIndex`, `body[3] == 0x00` chunk header,
  /// `body[4..20]` null-terminated ASCII name).
  static ({int index, String name})? decodePresetDumpFrame(
    int opcode,
    List<int> body,
  ) {
    if ((opcode != opPresetList && opcode != opPresetDump86) ||
        body.length < 20 ||
        body[0] != 0x80 ||
        body[3] != 0x00) {
      return null;
    }
    final index = body[2] & 0xff;
    final nameBytes = <int>[];
    for (var i = 4; i < 20 && i < body.length; i++) {
      final b = body[i] & 0xff;
      if (b == 0) break;
      if (b >= 32 && b < 127) nameBytes.add(b);
    }
    return (index: index, name: String.fromCharCodes(nameBytes).trim());
  }

  /// Fast-path decoder that extracts the preset index and 16-byte ASCII name
  /// directly from the first 64-byte USB HID packet of a `0xA5`/`0x86` chunk-0
  /// frame (`[len, 0xAA, 0x55, 0x05, 0x02, 0xA5/0x86, 0x80, 0x00, idx, 0x00, ...name]`),
  /// so preset names are never lost even if a later packet in the 523-byte frame drops.
  static ({int index, String name})? decodePresetDumpPacketHeader(
    List<int> rawPacket,
  ) {
    if (rawPacket.length < 26) return null;
    final chunkLen = rawPacket[0] & 0xff;
    if (chunkLen < 25) return null;
    final op = rawPacket[5] & 0xff;
    if (rawPacket[1] != 0xaa ||
        rawPacket[2] != 0x55 ||
        (op != opPresetList && op != opPresetDump86) ||
        rawPacket[6] != 0x80 ||
        rawPacket[9] != 0x00) {
      return null;
    }
    final index = rawPacket[8] & 0xff;
    if (index < 0 || index >= Fx200Constants.presetPatchCount) return null;
    final nameBytes = <int>[];
    for (var i = 10; i < 26 && i <= chunkLen; i++) {
      final b = rawPacket[i] & 0xff;
      if (b == 0) break;
      if (b >= 32 && b < 127) nameBytes.add(b);
    }
    final name = String.fromCharCodes(nameBytes).trim();
    if (name.isEmpty) return null;
    return (index: index, name: name);
  }

  /// Builds a `0xA8` preset save/rename HID packet (`[0xA8, presetIndex, ...16-byte ASCII name]`).
  static Uint8List buildPresetSavePacket(int presetIndex, String name) {
    final clamped = presetIndex.clamp(0, Fx200Constants.presetPatchCount - 1);
    final sanitized = name.trim();
    final nameBytes = List<int>.filled(16, 0);
    final limit = sanitized.length < 15 ? sanitized.length : 15;
    for (var i = 0; i < limit; i++) {
      final code = sanitized.codeUnitAt(i);
      nameBytes[i] = (code >= 32 && code < 127) ? code : 0x20;
    }
    return buildHidPacket(payload: <int>[opPresetSave, clamped, ...nameBytes]);
  }

  /// Decodes a `0xA8` preset save/rename frame (`body[0] == index`, `body[1..16]` ASCII name).
  static ({int index, String name})? decodePresetSaveFrame(
    int opcode,
    List<int> body,
  ) {
    if (opcode != opPresetSave || body.length < 2) {
      return null;
    }
    final index = body[0] & 0xff;
    final nameBytes = <int>[];
    for (var i = 1; i < 17 && i < body.length; i++) {
      final b = body[i] & 0xff;
      if (b == 0) break;
      if (b >= 32 && b < 127) nameBytes.add(b);
    }
    return (index: index, name: String.fromCharCodes(nameBytes).trim());
  }

  /// Builds a `0xA0` signal-chain order + bypass packet (`[0xA0, ...10 module IDs 1..10, ...10 enabled bytes]`).
  static Uint8List buildChainOrderPacket(
    List<int> moduleOrder1Based,
    List<bool> enabledStates,
  ) {
    final order = List<int>.generate(10, (i) => i + 1);
    for (var i = 0; i < 10 && i < moduleOrder1Based.length; i++) {
      order[i] = moduleOrder1Based[i].clamp(1, 10);
    }
    final enabled = List<int>.filled(10, 1);
    for (var i = 0; i < 10 && i < enabledStates.length; i++) {
      enabled[i] = enabledStates[i] ? 1 : 0;
    }
    return buildHidPacket(payload: <int>[opCmdA0, ...order, ...enabled]);
  }

  /// Decodes a `0xA4` footswitch/tap-tempo frame (`body[0] == fsMode`, `body[1..2] == ctrlMask`, `body[3..4] == bpm` u16BE `40..260`).
  static ({int fsMode, int ctrlMask, int bpm})? decodeTapTempoFrame(
    int opcode,
    List<int> body,
  ) {
    if (opcode != opCmdA4 || body.length < 5) {
      return null;
    }
    final fsMode = body[0] & 0xff;
    final ctrlMask = ((body[1] & 0xff) << 8) | (body[2] & 0xff);
    final bpm = (((body[3] & 0xff) << 8) | (body[4] & 0xff)).clamp(40, 260);
    return (fsMode: fsMode, ctrlMask: ctrlMask, bpm: bpm);
  }

  /// Builds a `0xA4` footswitch/tap-tempo HID packet (`40..260 BPM`).
  static Uint8List buildTapTempoPacket({
    required int bpm,
    int fsMode = 0x02,
    int ctrlMask = 0x0002,
  }) {
    final clampedBpm = bpm.clamp(40, 260);
    return buildHidPacket(
      payload: <int>[
        opCmdA4,
        fsMode & 0xff,
        (ctrlMask >> 8) & 0xff,
        ctrlMask & 0xff,
        (clampedBpm >> 8) & 0xff,
        clampedBpm & 0xff,
      ],
    );
  }

  /// Builds a `0xA3` expression-pedal assignment packet.
  static Uint8List buildExpPacket(Fx200ExpFrame frame) {
    return buildRawPacket(opCmdA3, frame.encode());
  }

  /// Builds a `0xAD` drum machine packet.
  static Uint8List buildDrumPacket(Fx200DrumSettings drum) {
    return buildRawPacket(opCmdAd, drum.encode());
  }

  /// Builds a `0xAE` VOLUME-pedal range packet.
  ///
  /// Earlier versions of this app took `0xAE` for a global output level and
  /// wrote `[0, dB, 0, 0]`, which actually set the volume pedal's toe/heel
  /// range (see [Fx200VolumePedalRange]).
  static Uint8List buildVolumePedalRangePacket(Fx200VolumePedalRange range) {
    return buildRawPacket(opCmdAe, range.encode());
  }

  /// Decodes a `0xA0` signal-chain order frame (`body[0..9]` 1-based module IDs, `body[10..19]` enabled flags).
  static ({List<int> order1Based, List<bool> enabledStates})?
  decodeChainOrderFrame(int opcode, List<int> body) {
    if (opcode != opCmdA0 || body.length < 20) {
      return null;
    }
    final order = body.sublist(0, 10).map((b) => b & 0xff).toList();
    if (order.any((id) => id < 1 || id > 10)) {
      return null;
    }
    final enabled = body.sublist(10, 20).map((b) => (b & 0xff) != 0).toList();
    return (order1Based: order, enabledStates: enabled);
  }

  /// Builds an HID packet for an arbitrary `opcode` + raw `body` (used to
  /// replay captured module/footswitch frames during a backup restore).
  static Uint8List buildRawPacket(int opcode, List<int> body) {
    return buildHidPacket(payload: <int>[opcode & 0xff, ...body]);
  }

  /// Decodes a `0xA1` global SYSTEM settings frame (46-byte body).
  static Fx200GlobalSettings? decodeGlobalSettingsFrame(
    int opcode,
    List<int> body,
  ) {
    if (opcode != opCmdA1 || body.length < Fx200GlobalSettings.length) {
      return null;
    }
    return Fx200GlobalSettings.fromBody(body);
  }

  /// Builds a `0xA1` packet that writes the whole global settings block.
  static Uint8List buildGlobalSettingsPacket(Fx200GlobalSettings settings) {
    return buildRawPacket(opCmdA1, settings.raw);
  }

  /// Builds a `0xA4` footswitch assignment packet.
  static Uint8List buildFootswitchPacket(Fx200FootswitchConfig config) {
    return buildTapTempoPacket(
      bpm: config.bpm,
      fsMode: config.mode,
      ctrlMask: config.ctrlMask,
    );
  }

  /// Size of one `0xA5`/`0x86` preset dump chunk and chunks per preset
  /// (8 × 512 B = the 4096-byte preset record in firmware section 3).
  static const int presetDumpChunkBytes = 512;
  static const int presetDumpChunkCount = 8;
  static const int presetDumpBytes =
      presetDumpChunkBytes * presetDumpChunkCount;

  /// Decodes any chunk of a `0xA5`/`0x86` preset dump:
  /// `body = [0x80, idxHi, idxLo, chunk, ...512 data bytes]`
  /// (`FX200.exe` reads the index as u16 big-endian at `0x42b469`).
  static ({int index, int chunk, Uint8List data})? decodePresetDumpChunk(
    int opcode,
    List<int> body,
  ) {
    if ((opcode != opPresetList && opcode != opPresetDump86) ||
        body.length < 4 + presetDumpChunkBytes ||
        body[0] != 0x80) {
      return null;
    }
    final index = ((body[1] & 0xff) << 8) | (body[2] & 0xff);
    final chunk = body[3] & 0xff;
    if (index >= Fx200Constants.presetPatchCount ||
        chunk >= presetDumpChunkCount) {
      return null;
    }
    return (
      index: index,
      chunk: chunk,
      data: Uint8List.fromList(body.sublist(4, 4 + presetDumpChunkBytes)),
    );
  }

  /// Offset of the 20-byte chain block (10 module IDs + 10 flags, the same
  /// layout as the `0xA0` body) inside a 4096-byte preset dump: chunk 4,
  /// data offset 40. Verified on all 200 presets in `captura.pcapng`.
  static const int presetDumpChainOffset = 4 * presetDumpChunkBytes + 40;

  /// Extracts the `0xA0`-compatible chain block from a full preset dump, or
  /// `null` when the module IDs are not a permutation of `1..10`.
  static Uint8List? chainBlockFromPresetDump(List<int> dump) {
    if (dump.length < presetDumpChainOffset + 20) return null;
    final block = Uint8List.fromList(
      dump.sublist(presetDumpChainOffset, presetDumpChainOffset + 20),
    );
    final ids = block.sublist(0, 10).toList()..sort();
    for (var i = 0; i < 10; i++) {
      if (ids[i] != i + 1) return null;
    }
    return block;
  }

  /// Computes the FX200 CRC-16/CCITT (`poly = 0x1021`, `init = 0x0000`, `xorOut = 0xffff`)
  /// matching the table at `0x474360` and bitwise NOT finalization in `sub_42a6a0`.
  static int crc16(List<int> bytes, [int start = 0, int? end]) {
    final limit = end ?? bytes.length;
    var crc = 0x0000;
    for (var i = start; i < limit; i++) {
      final b = bytes[i] & 0xff;
      crc ^= b << 8;
      for (var bit = 0; bit < 8; bit++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xffff;
        } else {
          crc = (crc << 1) & 0xffff;
        }
      }
    }
    return (~crc) & 0xffff;
  }

  /// Builds a framed FX200 USB interrupt packet:
  /// `[header0, header1, lenLo, lenHi, ...payload..., crcHi, crcLo]`.
  static Uint8List buildFrame({
    required int header0,
    required int header1,
    required List<int> payload,
  }) {
    final len = payload.length;
    final frame = Uint8List(len + 6);
    frame[0] = header0 & 0xff;
    frame[1] = header1 & 0xff;
    frame[2] = len & 0xff;
    frame[3] = (len >> 8) & 0xff;
    for (var i = 0; i < len; i++) {
      frame[4 + i] = payload[i] & 0xff;
    }
    final crc = crc16(frame, 2, 4 + len);
    frame[4 + len] = (crc >> 8) & 0xff;
    frame[5 + len] = crc & 0xff;
    return frame;
  }

  /// Builds a 64-byte-ready FX200 HID packet with the leading 1-byte length prefix
  /// observed on the wire in `captura.pcapng`:
  /// `[frameLen, header0, header1, lenLo, lenHi, ...payload..., crcHi, crcLo]`.
  static Uint8List buildHidPacket({
    int header0 = 0xaa,
    int header1 = 0x55,
    required List<int> payload,
  }) {
    final inner = buildFrame(
      header0: header0,
      header1: header1,
      payload: payload,
    );
    final packet = Uint8List(inner.length + 1);
    packet[0] = inner.length & 0xff;
    packet.setRange(1, packet.length, inner);
    return packet;
  }

  /// Verifies a received HID packet (`[frameLen, 0xAA, 0x55, ...]`) or raw frame (`[0xAA, 0x55, ...]`).
  static bool verifyFrame(List<int> frame) {
    if (frame.length >= 7 && frame[1] == 0xaa && frame[2] == 0x55) {
      return verifyFrame(frame.sublist(1));
    }
    if (frame.length < 6) return false;
    final len = (frame[2] & 0xff) | ((frame[3] & 0xff) << 8);
    if (frame.length < len + 6) return false;
    final expected = crc16(frame, 2, 4 + len);
    final actual = ((frame[4 + len] & 0xff) << 8) | (frame[5 + len] & 0xff);
    return expected == actual;
  }

  /// Splits a packet built by [buildHidPacket] (`[len, 0xAA, 0x55, ...]`)
  /// into 64-byte interrupt reports, each `[n, n frame bytes]` with
  /// `n <= 63`. This is how `FX200.exe` writes frames (`0x401680`, 0x3F-byte
  /// pieces) and how the pedal sends long frames such as `0xA5`; for frames
  /// up to 63 bytes it is a single report, identical to the packet itself.
  static List<Uint8List> splitInterruptChunks(Uint8List packet) {
    const reportSize = Fx200Constants.interruptPacketBytes;
    const pieceSize = reportSize - 1;
    final frame = packet.length > 1 && packet[1] == 0xaa
        ? Uint8List.sublistView(packet, 1)
        : packet;
    final chunks = <Uint8List>[];
    for (var offset = 0; offset < frame.length; offset += pieceSize) {
      final n = frame.length - offset < pieceSize
          ? frame.length - offset
          : pieceSize;
      final report = Uint8List(reportSize);
      report[0] = n;
      report.setRange(1, 1 + n, frame, offset);
      chunks.add(report);
    }
    return chunks;
  }
}
