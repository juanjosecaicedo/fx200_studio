import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'fx200_protocol.dart';

/// One section of an `.fl` firmware container.
class Fx200FirmwareSection {
  const Fx200FirmwareSection({
    required this.index,
    required this.headerOffset,
    required this.dataOffset,
    required this.size,
    required this.dataOpcode,
    required this.ackOpcode,
    required this.timeoutMs,
    required this.firstBlock,
  });

  final int index;
  final int headerOffset;
  final int dataOffset;
  final int size;
  final int dataOpcode;
  final int ackOpcode;
  final int timeoutMs;

  /// Block number of the first 512-byte block (sent as the u16 sequence).
  final int firstBlock;

  int get blockCount => size ~/ Fx200FirmwareImage.blockSize;

  /// What the section holds, as found in FX200 V2.0.1.
  String get description => switch (dataOpcode) {
    0x04 => 'Main MCU application',
    0x06 when firstBlock == 0 => 'Audio engine (DSP MCU)',
    0x06 => 'Audio resources',
    0x08 => 'Factory presets',
    _ => 'Section $index',
  };
}

/// Official FX200 firmware container (`.fl`), as read by the official
/// updater. Layout (verified against `captura4.pcapng`, where every
/// transmitted block matches the file byte for byte):
///
/// * file header (0x80 bytes): `"Mooer_TAG"`, product name at 0x09
///   (`"FX200"`), start opcode at 0x29 (`0x02`), its answer at 0x2A (`0x03`),
///   timeout ms u32 LE at 0x2B, section count at 0x2F, start parameter u32 LE
///   at 0x30;
/// * one 0x200-byte header per section, also starting with `"Mooer_TAG"`:
///   +0x09 data offset (u32 LE, bit 0 set), +0x0D next header offset,
///   +0x11 data size, +0x15 data opcode, +0x16 answer opcode, +0x17 timeout
///   ms, +0x1B first block number.
class Fx200FirmwareImage {
  Fx200FirmwareImage._({
    required this.bytes,
    required this.productName,
    required this.startOpcode,
    required this.startAckOpcode,
    required this.startTimeoutMs,
    required this.startParameter,
    required this.sections,
    required this.sha256Hex,
  });

  static const int blockSize = 512;
  static const String _tag = 'Mooer_TAG';

  /// SHA-256 of firmware files published by Flamma (for the "official"
  /// badge; any other file is flagged as unknown/modified).
  static const Map<String, String> knownOfficial = <String, String>{
    '1503a5677a5c90cd0caf7d76b700b31a54acb28f325afb53566b5c8825a99b08':
        'FX200 V2.0.1',
  };

  final Uint8List bytes;
  final String productName;
  final int startOpcode;
  final int startAckOpcode;
  final int startTimeoutMs;
  final int startParameter;
  final List<Fx200FirmwareSection> sections;
  final String sha256Hex;

  String? get officialName => knownOfficial[sha256Hex];
  int get totalBlocks => sections.fold(0, (n, s) => n + s.blockCount);

  static int _u32(Uint8List b, int o) =>
      b[o] | b[o + 1] << 8 | b[o + 2] << 16 | b[o + 3] << 24;

  static bool _hasTag(Uint8List b, int o) =>
      o + _tag.length <= b.length &&
      String.fromCharCodes(b.sublist(o, o + _tag.length)) == _tag;

  /// Parses and fully validates [bytes]; throws [FormatException] on any
  /// inconsistency so a damaged or foreign file is never sent.
  factory Fx200FirmwareImage.parse(Uint8List bytes) {
    if (bytes.length < 0x280 || !_hasTag(bytes, 0)) {
      throw const FormatException('Not an FX200 firmware file (.fl).');
    }
    final nameBytes = <int>[];
    for (var i = 9; i < 0x29 && bytes[i] != 0; i++) {
      nameBytes.add(bytes[i]);
    }
    final product = String.fromCharCodes(nameBytes);
    if (product != 'FX200') {
      throw FormatException('Firmware is for "$product", not the FX200.');
    }
    final count = bytes[0x2f];
    if (count < 1 || count > 8) {
      throw FormatException('Invalid section count $count.');
    }
    final sections = <Fx200FirmwareSection>[];
    var header = 0x80;
    for (var i = 0; i < count; i++) {
      if (!_hasTag(bytes, header)) {
        throw FormatException(
          'Section $i header missing at 0x'
          '${header.toRadixString(16)}.',
        );
      }
      final start = _u32(bytes, header + 0x09) & ~1;
      final next = _u32(bytes, header + 0x0d);
      final size = _u32(bytes, header + 0x11);
      final dataOp = bytes[header + 0x15];
      final ackOp = bytes[header + 0x16];
      final timeout = _u32(bytes, header + 0x17);
      final first = _u32(bytes, header + 0x1b);
      if (start != header + 0x200 ||
          start + size != next ||
          size % blockSize != 0 ||
          size == 0 ||
          next > bytes.length ||
          ackOp != dataOp + 1 ||
          !const <int>{0x04, 0x06, 0x08}.contains(dataOp) ||
          first + size ~/ blockSize > 0x10000) {
        throw FormatException('Section $i header is inconsistent.');
      }
      sections.add(
        Fx200FirmwareSection(
          index: i,
          headerOffset: header,
          dataOffset: start,
          size: size,
          dataOpcode: dataOp,
          ackOpcode: ackOp,
          timeoutMs: timeout,
          firstBlock: first,
        ),
      );
      header = next;
    }
    if (header != bytes.length) {
      throw const FormatException('File length does not match its sections.');
    }
    return Fx200FirmwareImage._(
      bytes: bytes,
      productName: product,
      startOpcode: bytes[0x29],
      startAckOpcode: bytes[0x2a],
      startTimeoutMs: _u32(bytes, 0x2b),
      startParameter: _u32(bytes, 0x30),
      sections: sections,
      sha256Hex: sha256.convert(bytes).toString(),
    );
  }

  /// Body of block [k] of [section]: `[seqHi, seqLo, 512 bytes]`.
  Uint8List blockBody(Fx200FirmwareSection section, int k) {
    final seq = section.firstBlock + k;
    final out = Uint8List(2 + blockSize);
    out[0] = (seq >> 8) & 0xff;
    out[1] = seq & 0xff;
    final o = section.dataOffset + k * blockSize;
    out.setRange(2, 2 + blockSize, bytes, o);
    return out;
  }
}

/// Blocking frame I/O with the pedal in update mode (`0x0483:0x5703`).
abstract class Fx200UpdatePort {
  void send(Uint8List packet);

  /// Next frame from the pedal, or null after [timeoutMs].
  ({int opcode, Uint8List body})? receive(int timeoutMs);
}

class Fx200UpdateException implements Exception {
  const Fx200UpdateException(this.message);
  final String message;
  @override
  String toString() => message;
}

List<int> _u32le(int v) => <int>[
  v & 0xff,
  (v >> 8) & 0xff,
  (v >> 16) & 0xff,
  (v >> 24) & 0xff,
];

/// Device information from the `0x01` answer (printable strings, e.g.
/// `FX200`, `V1.0.0`, `V2.0.0`).
List<String> fx200UpdateInfoStrings(Uint8List body) {
  final out = <String>[];
  final cur = <int>[];
  for (final b in body) {
    if (b >= 0x20 && b < 0x7f) {
      cur.add(b);
    } else {
      if (cur.length >= 2) out.add(String.fromCharCodes(cur));
      cur.clear();
    }
  }
  if (cur.length >= 2) out.add(String.fromCharCodes(cur));
  return out;
}

/// Runs the official update sequence (from `captura4.pcapng`):
///
/// 1. `00` → `01` device info;  2. `AA` → `AB ff`;
/// 3. start opcode (`02 [param]`) → `03 01`;
/// 4. per section: (from the 2nd on) `0C [first block of the previous
///    section]` → `0D ff`, then every block `op [seq, 512 B]` → `op+1 [01]`;
/// 5. `0C [first block of the last section]`, `FF` → `0D ff`.
///
/// Every step waits for the pedal's answer; any missing or negative answer
/// aborts with [Fx200UpdateException] (the pedal stays in update mode and
/// the update can simply be started again).
void fx200RunFirmwareUpdate(
  Fx200UpdatePort port,
  Fx200FirmwareImage image, {
  void Function(int done, int total, String step)? onProgress,
  void Function(List<String> info)? onDeviceInfo,
  bool Function()? isCancelled,
  Duration finalAnswerTimeout = const Duration(seconds: 10),
}) {
  ({int opcode, Uint8List body}) expect(
    int opcode,
    int timeoutMs,
    String what,
  ) {
    final deadline = DateTime.now().add(Duration(milliseconds: timeoutMs));
    while (true) {
      final left = deadline.difference(DateTime.now()).inMilliseconds;
      if (left <= 0) {
        throw Fx200UpdateException('No answer from the FX200 ($what).');
      }
      final f = port.receive(left < 200 ? left : 200);
      if (f == null) continue;
      if (f.opcode == opcode) return f;
    }
  }

  void send(int opcode, List<int> body) =>
      port.send(Fx200Protocol.buildRawPacket(opcode, body));

  final total = image.totalBlocks;
  var done = 0;
  onProgress?.call(0, total, 'Connecting');

  send(0x00, const <int>[0]);
  final info = expect(0x01, 3000, 'device info');
  final strings = fx200UpdateInfoStrings(info.body);
  if (strings.isEmpty || strings.first != image.productName) {
    throw Fx200UpdateException(
      'The connected device is not an FX200 in update mode '
      '(${strings.join(' ')}).',
    );
  }
  onDeviceInfo?.call(strings);

  send(0xaa, const <int>[0]);
  expect(0xab, 3000, 'update handshake');

  onProgress?.call(0, total, 'Preparing the pedal');
  send(image.startOpcode, _u32le(image.startParameter));
  final started = expect(image.startAckOpcode, image.startTimeoutMs, 'start');
  if (started.body.isEmpty || started.body[0] != 1) {
    throw const Fx200UpdateException('The FX200 refused to start the update.');
  }

  Fx200FirmwareSection? previous;
  for (final section in image.sections) {
    if (previous != null) {
      send(0x0c, _u32le(previous.firstBlock));
      expect(0x0d, section.timeoutMs, 'section ${previous.index} commit');
    }
    for (var k = 0; k < section.blockCount; k++) {
      if (isCancelled?.call() ?? false) {
        throw const Fx200UpdateException('Update cancelled.');
      }
      send(section.dataOpcode, image.blockBody(section, k));
      final ack = expect(
        section.ackOpcode,
        section.timeoutMs,
        'block ${k + 1}/${section.blockCount} of section ${section.index}',
      );
      if (ack.body.isEmpty || ack.body[0] != 1) {
        throw Fx200UpdateException(
          'The FX200 rejected block ${k + 1} of section ${section.index}.',
        );
      }
      done++;
      if (done % 16 == 0 || done == total) {
        onProgress?.call(done, total, section.description);
      }
    }
    previous = section;
  }
  // Every block is confirmed at this point. The pedal may reboot right
  // after FF, before (or instead of) answering 0D: on the real pedal the
  // device vanished (libusb -4) while waiting, yet the update was complete
  // and it came back with the new firmware. So a missing 0D, a vanished
  // device or a failed final write all count as "restarting".
  try {
    send(0x0c, _u32le(previous!.firstBlock));
    send(0xff, const <int>[0]);
    expect(0x0d, finalAnswerTimeout.inMilliseconds, 'final commit');
    onProgress?.call(total, total, 'Done');
  } on Fx200UpdateException {
    onProgress?.call(total, total, 'Done (the pedal restarted)');
  }
}
