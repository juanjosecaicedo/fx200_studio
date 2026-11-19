import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_backup.dart';
import 'package:fx200_studio/services/fx200_bfl.dart';
import 'package:fx200_studio/services/fx200_ir.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

int off(int address) => address - 0xdc5a60 + 0x80;

Uint8List _bfl() {
  final f = Uint8List(Fx200Bfl.fileSize);
  f.setAll(0, 'FX200'.codeUnits);
  f.setAll(0x20, 'V1.1.8'.codeUnits);
  f.setAll(off(0xdc5a6c), 'FIRST'.codeUnits);
  f.setAll(off(0xdc5a6c + 199 * 0x840), 'LAST'.codeUnits);
  f[off(0xe53366 + 3)] = 4; // IR slot 3 in use
  f.setAll(off(0xe53398 + 3 * 15), 'MyCab'.codeUnits);
  f[off(0xe536c4 + 18)] = 77; // brightness
  f[off(0xe537ec)] = 1;
  f[off(0xe537f8)] = 9;
  f[off(0xe537f9)] = 2;
  f[off(0xe537fa)] = 60;
  f[off(0xe537fc)] = 140;
  return f;
}

class _Pedal implements Fx200DeviceLink {
  final _frames = StreamController<({int opcode, Uint8List body})>.broadcast();
  final List<int> ops = <int>[];
  @override
  bool isConnected = true;
  @override
  Stream<({int opcode, Uint8List body})> get frames => _frames.stream;
  @override
  void sendPacket(Uint8List packet) {
    final len = packet[3] | (packet[4] << 8);
    final op = packet[5];
    final body = packet.sublist(6, 5 + len);
    ops.add(op);
    if (op == Fx200Ir.opUpload) {
      scheduleMicrotask(
        () => _frames.add((opcode: op, body: Uint8List.fromList([body[1]]))),
      );
    }
    if (op == Fx200Protocol.opCmd83 && body[3] <= 3) {
      scheduleMicrotask(
        () => _frames.add((
          opcode: op,
          body: Uint8List.fromList([1, body[1], body[2], body[3]]),
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
  test('parses presets, used IR slots, globals and drum', () {
    final b = Fx200Bfl.parse(_bfl());
    expect(b.presets.length, 200);
    expect(b.presetNames.first, 'FIRST');
    expect(b.presetNames.last, 'LAST');
    expect(b.irRecords.keys, [3]);
    expect(String.fromCharCodes(b.irRecords[3]!.sublist(3072, 3077)), 'MyCab');
    expect(b.global.raw[18], 77);
    expect(
      (
        b.drum!.on,
        b.drum!.isMetronome,
        b.drum!.groove,
        b.drum!.volume,
        b.drum!.bpm,
      ),
      (true, true, 2, 60, 140),
    );
  });

  test('rejects other files', () {
    expect(() => Fx200Bfl.parse(Uint8List(100)), throwsFormatException);
    expect(
      () => Fx200Bfl.parse(Uint8List(Fx200Bfl.fileSize)),
      throwsFormatException,
    );
  });

  test('restore writes globals, drum, IRs and every preset', () async {
    final pedal = _Pedal();
    final r = await fx200RestoreBfl(
      pedal,
      Fx200Bfl.parse(_bfl()),
      uploadQuiet: const Duration(milliseconds: 5),
      settle: Duration.zero,
    );
    expect((r.presets, r.irs), (200, 1));
    expect(pedal.ops.skip(pedal.ops.length - 2), [0xa1, 0xad]);
    expect(pedal.ops.first, 0x83);
    expect(pedal.ops.where((o) => o == 0xe1).length, 7);
    expect(pedal.ops.where((o) => o == 0x83).length, 200 * 5);
  });

  test('build -> parse round trip and type 5 / IR reads', () async {
    final records = [
      for (var i = 0; i < 200; i++) Uint8List(4096)..setAll(0, 'P$i'.codeUnits),
    ];
    final names = Uint8List(750);
    names.setAll(0, 'MyCab'.codeUnits);
    for (var s = 1; s < 50; s++) {
      names.setAll(s * 15, 'EMPTY'.codeUnits);
    }
    final samples = Uint8List(3072)..[0] = 0x7f;
    final type5 = {0: Uint8List(512)..[0xf8 + 0x0c] = 2, 1: Uint8List(512)};
    type5[0]![0xf8 + 0x10] = 100;
    final global = Uint8List(46)..[16] = 9;
    final f = Fx200Bfl.build(
      records: records,
      activePreset: 3,
      irSamples: {0: samples},
      irNamesBody: names,
      globalBody: global,
      type5: type5,
    );
    final b = Fx200Bfl.parse(f);
    expect(b.presetNames[3], 'P3');
    expect(b.irRecords.keys, [0]);
    expect(b.irRecords[0]![0], 0x7f);
    expect(String.fromCharCodes(b.irRecords[0]!.sublist(3072, 3077)), 'MyCab');
    expect(b.global.inputLevelDb, 8);
    expect((b.drum!.style, b.drum!.bpm), (2, 100));
    expect(b.global.withInputLevelDb(20).raw[16], 21);
  });
}
