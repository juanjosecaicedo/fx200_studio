import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_backup.dart';
import 'package:fx200_studio/services/fx200_ir.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

class _IrPedal implements Fx200DeviceLink {
  _IrPedal({this.ack = true});
  final bool ack;
  final _frames = StreamController<({int opcode, Uint8List body})>.broadcast();
  final List<Uint8List> bodies = <Uint8List>[];

  @override
  bool isConnected = true;
  @override
  Stream<({int opcode, Uint8List body})> get frames => _frames.stream;
  @override
  void sendPacket(Uint8List packet) {
    expect(Fx200Protocol.verifyFrame(packet), isTrue);
    final len = packet[3] | (packet[4] << 8);
    expect(packet[5], Fx200Ir.opUpload);
    final body = Uint8List.fromList(packet.sublist(6, 5 + len));
    bodies.add(body);
    if (ack) {
      scheduleMicrotask(
        () => _frames.add((
          opcode: Fx200Ir.opUpload,
          body: Uint8List.fromList([body[1]]),
        )),
      );
    }
  }

  @override
  Future<void> waitUntilReady() async {}
  @override
  Uint8List? chainBlockFor(int index) => null;
  @override
  void rememberChainBlock(int index, Uint8List chain) {}
  @override
  Future<({Map<int, Uint8List> dumps, Fx200GlobalSettings? global})>
  readFullDump() => throw UnimplementedError();
}

void main() {
  final impulse = List<double>.generate(
    2000,
    (i) => math.exp(-i / 200) * math.sin(i / 3) * 0.9,
  );

  test('record: 2 blocks x [hi, mid, lo] planes + 15-byte name', () {
    final rec = Fx200Ir.encodeRecord(
      impulse,
      44100,
      'Disturbed_Stricken_IR.wav',
    );
    expect(rec.length, 3087);
    expect(String.fromCharCodes(rec.sublist(3072)), 'Disturbed_Stric');
    final v0 = (impulse[0] * 8388608).truncate() & 0xffffff;
    expect(
      [rec[0], rec[512], rec[1024]],
      [v0 >> 16, (v0 >> 8) & 0xff, v0 & 0xff],
    );
    final back = Fx200Ir.decodeSamples(rec);
    for (var i = 0; i < 1024; i++) {
      expect(back[i], closeTo(impulse[i], 1e-6));
    }
  });

  test('resamples 48 kHz to 44.1 kHz (sample 0 kept, then interpolated)', () {
    final rec = Fx200Ir.encodeRecord(impulse, 48000, 'x');
    final back = Fx200Ir.decodeSamples(rec);
    expect(back[0], closeTo(impulse[0], 1e-6));
    final t = 100 * 48000 / 44100;
    final k = t.floor();
    final want = impulse[k] + (impulse[k + 1] - impulse[k]) * (t - k);
    expect(back[100], closeTo(want, 1e-6));
  });

  test('0x85 names: 50 x 15 bytes, EMPTY slots become empty', () {
    final body = Uint8List(750);
    body.setAll(0, 'Disturbed_Stric'.codeUnits);
    for (var i = 1; i < 50; i++) {
      body.setAll(i * 15, 'EMPTY       '.codeUnits);
    }
    final names = Fx200Ir.decodeNames(body);
    expect(names.length, 50);
    expect(names[0], 'Disturbed_Stric');
    expect(names[1], '');
  });

  test('upload sends chunks 1..7 and waits for each acknowledgement', () async {
    final pedal = _IrPedal();
    final rec = Fx200Ir.encodeRecord(impulse, 44100, 'Meshuggah');
    await fx200UploadIr(pedal, 1, rec);
    expect(pedal.bodies.map((b) => b[1]), [1, 2, 3, 4, 5, 6, 7]);
    expect(pedal.bodies.every((b) => b[0] == 1), isTrue);
    expect(pedal.bodies.take(6).every((b) => b.length == 514), isTrue);
    expect(pedal.bodies.last.length, 17);
    final joined = <int>[for (final b in pedal.bodies) ...b.sublist(2)];
    expect(joined, rec);
  });

  test('upload stops if the pedal does not confirm a chunk', () async {
    final pedal = _IrPedal(ack: false);
    await expectLater(
      fx200UploadIr(
        pedal,
        0,
        Fx200Ir.encodeRecord(impulse, 44100, 'x'),
        ackTimeout: const Duration(milliseconds: 30),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(pedal.bodies.length, 1);
  });

  deleteTests();
}

void deleteTests() {
  test(
    'delete = zero record named "Empty" via 0xE1, then 0xE4 [slot]',
    () async {
      final ops = <int>[];
      final bodies = <Uint8List>[];
      final pedal = _IrPedal();
      final link = _Recording(pedal, ops, bodies);
      await fx200DeleteIr(link, 1);
      expect(ops.where((o) => o == 0xe1).length, 7);
      expect(ops.last, 0xe4);
      expect(bodies.last, [1]);
      final last = bodies[6];
      expect(last.sublist(0, 2), [1, 7]);
      expect(String.fromCharCodes(last.sublist(2, 7)), 'Empty');
      expect(last.sublist(7).every((b) => b == 0), isTrue);
      expect(bodies[0].sublist(2).every((b) => b == 0), isTrue);
    },
  );
}

class _Recording implements Fx200DeviceLink {
  _Recording(this.inner, this.ops, this.bodies);
  final _IrPedal inner;
  final List<int> ops;
  final List<Uint8List> bodies;
  @override
  bool get isConnected => true;
  @override
  Stream<({int opcode, Uint8List body})> get frames => inner.frames;
  @override
  void sendPacket(Uint8List p) {
    final len = p[3] | (p[4] << 8);
    ops.add(p[5]);
    bodies.add(Uint8List.fromList(p.sublist(6, 5 + len)));
    if (p[5] == Fx200Ir.opUpload) inner.sendPacket(p);
  }

  @override
  Future<void> waitUntilReady() async {}
  @override
  Uint8List? chainBlockFor(int index) => null;
  @override
  void rememberChainBlock(int index, Uint8List chain) {}
  @override
  Future<({Map<int, Uint8List> dumps, Fx200GlobalSettings? global})>
  readFullDump() => throw UnimplementedError();
}
