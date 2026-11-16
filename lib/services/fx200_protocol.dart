import 'dart:typed_data';

import '../core/fx200_constants.dart';

/// Packet framing and CRC-16/CCITT codec derived from `FX200.exe` (`sub_42a6a0`).
class Fx200Protocol {
  Fx200Protocol._();

  /// Command opcodes observed in `FX200.exe` (`sub_411d50`..`sub_414a90`).
  static const int opCmdA0 = 0xa0; // len 0x15
  static const int opCmdA1 = 0xa1; // len 0x2f
  static const int opCmdA3 = 0xa3; // len 0x0b
  static const int opCmdA4 = 0xa4; // len 0x06
  static const int opCmdAe = 0xae; // len 0x05
  static const int opCmdBb = 0xbb; // len 0x03
  static const int opCmdE0 = 0xe0; // len 0x01

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

  /// Verifies the big-endian CRC-16 trailer of a framed packet.
  static bool verifyFrame(List<int> frame) {
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
