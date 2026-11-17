import 'dart:typed_data';

import '../core/fx200_constants.dart';

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

  Fx200ModuleState copyWith({
    bool? enabled,
    int? modelId,
    List<int>? params,
  }) {
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
  static const int opCmdA0 = 0xa0; // len 0x15
  static const int opCmdA1 = 0xa1; // len 0x2f
  static const int opCmdA3 = 0xa3; // len 0x0b
  static const int opCmdA4 = 0xa4; // len 0x06
  static const int opPresetList = 0xa5; // multi-packet preset/IR list
  static const int opPresetDump86 = 0x86; // single-preset dump (same layout as 0xA5)
  static const int opPresetRead = 0xa6; // len 0x11
  static const int opPresetSave = 0xa8; // len 0x12 (index + 16-byte ASCII name)
  static const int opCmdAe = 0xae; // len 0x05
  static const int opCmdBb = 0xbb; // len 0x03
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
    final words = <int>[
      state.enabled ? 1 : 0,
      state.modelId,
      ...state.params,
    ];
    final payload = <int>[state.opcode];
    for (final w in words) {
      payload.add((w >> 8) & 0xff);
      payload.add(w & 0xff);
    }
    return buildHidPacket(payload: payload);
  }

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
    return (
      index: index,
      name: String.fromCharCodes(nameBytes).trim(),
    );
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
    return buildHidPacket(
      payload: <int>[opPresetSave, clamped, ...nameBytes],
    );
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
    return (
      index: index,
      name: String.fromCharCodes(nameBytes).trim(),
    );
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
    return buildHidPacket(
      payload: <int>[opCmdA0, ...order, ...enabled],
    );
  }

  /// Decodes a `0xA4` patch output level frame (`body[4]`, 0.5 dB steps: `120 == 0.0 dB`, `0..132` => `-60..+6 dB`).
  static double? decodeOutputLevelFrame(int opcode, List<int> body) {
    if (opcode != opCmdA4 || body.length < 5) {
      return null;
    }
    final raw = (body[4] & 0xff).clamp(0, 132);
    return (raw / 2.0) - 60.0;
  }

  /// Builds a `0xA4` patch output level HID packet (`-60.0 .. +6.0 dB`).
  static Uint8List buildOutputLevelPacket(double db) {
    final raw = ((db.clamp(-60.0, 6.0) + 60.0) * 2.0).round().clamp(0, 132);
    return buildHidPacket(
      payload: <int>[opCmdA4, 0x01, 0x00, 0x80, 0x00, raw],
    );
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

  /// Splits a framed packet into 64-byte (`interruptPacketBytes`) USB interrupt chunks.
  static List<Uint8List> splitInterruptChunks(Uint8List frame) {
    const chunkSize = Fx200Constants.interruptPacketBytes;
    final chunks = <Uint8List>[];
    for (var offset = 0; offset < frame.length; offset += chunkSize) {
      final chunk = Uint8List(chunkSize);
      final remaining = frame.length - offset;
      final copyLen = remaining < chunkSize ? remaining : chunkSize;
      chunk.setRange(0, copyLen, frame, offset);
      chunks.add(chunk);
    }
    return chunks;
  }
}
