import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_firmware.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

void _u32(Uint8List b, int o, int v) {
  b[o] = v & 0xff;
  b[o + 1] = (v >> 8) & 0xff;
  b[o + 2] = (v >> 16) & 0xff;
  b[o + 3] = (v >> 24) & 0xff;
}

/// Small .fl with the same structure as FX200 V2.0.1 (two sections).
Uint8List syntheticFl({String product = 'FX200'}) {
  const s0 = 3 * 512, s1 = 2 * 512;
  final h0 = 0x80, d0 = h0 + 0x200, h1 = d0 + s0, d1 = h1 + 0x200;
  final b = Uint8List(d1 + s1);
  b.setAll(0, 'Mooer_TAG'.codeUnits);
  b.setAll(9, product.codeUnits);
  b[0x29] = 0x02;
  b[0x2a] = 0x03;
  _u32(b, 0x2b, 60000);
  b[0x2f] = 2;
  _u32(b, 0x30, 7);
  void header(int h, int d, int size, int op, int first) {
    b.setAll(h, 'Mooer_TAG'.codeUnits);
    _u32(b, h + 9, d | 1);
    _u32(b, h + 0x0d, d + size);
    _u32(b, h + 0x11, size);
    b[h + 0x15] = op;
    b[h + 0x16] = op + 1;
    _u32(b, h + 0x17, 40000);
    _u32(b, h + 0x1b, first);
  }

  header(h0, d0, s0, 0x04, 64);
  header(h1, d1, s1, 0x06, 0);
  for (var i = 0; i < s0 + s1; i++) {
    b[(i < s0 ? d0 + i : d1 + i - s0)] = (i * 13) & 0xff;
  }
  return b;
}

/// Pedal in update mode answering like in captura4.pcapng.
class _Pedal implements Fx200UpdatePort {
  _Pedal({this.rejectBlock});
  final int? rejectBlock;
  final List<({int op, Uint8List body})> sent = [];
  final List<({int opcode, Uint8List body})> _out = [];
  var blocks = 0;

  @override
  void send(Uint8List packet) {
    expect(Fx200Protocol.verifyFrame(packet), isTrue);
    final len = packet[3] | packet[4] << 8;
    final op = packet[5];
    final body = Uint8List.fromList(packet.sublist(6, 5 + len));
    sent.add((op: op, body: body));
    void answer(int o, List<int> b) =>
        _out.add((opcode: o, body: Uint8List.fromList(b)));
    switch (op) {
      case 0x00:
        answer(0x01, [...'FX200'.codeUnits, 0, 0, ...'V1.0.0'.codeUnits, 0]);
      case 0xaa:
        answer(0xab, [0xff]);
      case 0x02:
        answer(0x03, [1]);
      case 0x04 || 0x06 || 0x08:
        answer(op + 1, [blocks++ == rejectBlock ? 0 : 1]);
      case 0xff:
        answer(0x0d, [0xff]);
      case 0x0c:
        if (sent.where((s) => s.op == 0xff).isEmpty &&
            sent.where((s) => s.op == 0x0c).length < 2) {
          answer(0x0d, [0xff]);
        }
    }
  }

  @override
  ({int opcode, Uint8List body})? receive(int timeoutMs) =>
      _out.isEmpty ? null : _out.removeAt(0);
}

void main() {
  test('parses the container and its sections', () {
    final img = Fx200FirmwareImage.parse(syntheticFl());
    expect(img.productName, 'FX200');
    expect((img.startOpcode, img.startParameter), (0x02, 7));
    expect(
      img.sections.map((s) => (s.dataOpcode, s.firstBlock, s.blockCount)),
      [(0x04, 64, 3), (0x06, 0, 2)],
    );
    expect(img.officialName, isNull);
  });

  test('rejects foreign or damaged files', () {
    expect(
      () => Fx200FirmwareImage.parse(syntheticFl(product: 'GE300')),
      throwsFormatException,
    );
    final bad = syntheticFl()..[0x80 + 0x11] ^= 1;
    expect(() => Fx200FirmwareImage.parse(bad), throwsFormatException);
    final cut = syntheticFl().sublist(0, syntheticFl().length - 512);
    expect(() => Fx200FirmwareImage.parse(cut), throwsFormatException);
  });

  test('runs the official sequence', () {
    final img = Fx200FirmwareImage.parse(syntheticFl());
    final pedal = _Pedal();
    fx200RunFirmwareUpdate(pedal, img);
    expect(pedal.sent.map((s) => s.op), [
      0x00, 0xaa, 0x02, 0x04, 0x04, 0x04, 0x0c, 0x06, 0x06, 0x0c, 0xff, //
    ]);
    expect(pedal.sent[2].body, [7, 0, 0, 0]);
    expect(pedal.sent[3].body.sublist(0, 2), [0, 64]);
    expect(pedal.sent[6].body, [64, 0, 0, 0]); // closes section 0
    expect(pedal.sent[9].body, [0, 0, 0, 0]); // closes section 1
    expect(
      pedal.sent[4].body.sublist(2),
      img.bytes.sublist(0x280 + 512, 0x280 + 1024),
    );
  });

  test('pedal rebooting after FF (no 0D, device gone) is a success', () {
    final img = Fx200FirmwareImage.parse(syntheticFl());
    final pedal = _GonePedal();
    final steps = <String>[];
    fx200RunFirmwareUpdate(pedal, img, onProgress: (d, t, s) => steps.add(s));
    expect(pedal.sent.last.op, 0xff);
    expect(steps.last, 'Done (the pedal restarted)');
  });

  test('stops when the pedal rejects a block', () {
    final img = Fx200FirmwareImage.parse(syntheticFl());
    final pedal = _Pedal(rejectBlock: 1);
    expect(
      () => fx200RunFirmwareUpdate(pedal, img),
      throwsA(isA<Fx200UpdateException>()),
    );
    expect(pedal.sent.last.op, 0x04);
    expect(pedal.sent.where((s) => s.op == 0xff), isEmpty);
  });
}

/// Answers like the real pedal but disappears after FF (libusb -4).
class _GonePedal extends _Pedal {
  bool gone = false;

  @override
  void send(Uint8List packet) {
    if (packet[5] == 0xff) {
      sent.add((op: 0xff, body: Uint8List(1)));
      gone = true;
      return;
    }
    if (packet[5] == 0x0c && sent.where((s) => s.op == 0x0c).isNotEmpty) {
      sent.add((op: 0x0c, body: Uint8List(4)));
      return;
    }
    super.send(packet);
  }

  @override
  ({int opcode, Uint8List body})? receive(int timeoutMs) {
    if (gone) {
      throw const Fx200UpdateException('The FX200 disconnected (USB -4).');
    }
    return super.receive(timeoutMs);
  }
}
