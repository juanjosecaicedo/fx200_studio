import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_backup.dart';
import 'package:fx200_studio/services/fx200_firmware_features.dart';
import 'package:fx200_studio/services/fx200_opcodes.dart';
import 'package:fx200_studio/services/fx200_pedal_scenes.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

/// Pedal with the scenes firmware v2, answering `0xF5` like
/// `firmware_patch/scenes/scenes.c` (usb_scenes).
class _FakePedal implements Fx200DeviceLink {
  _FakePedal() {
    for (var n = 0; n < 4; n++) {
      scenes[n].fillRange(0, scenes[n].length, n);
    }
  }

  final List<Uint8List> scenes = List<Uint8List>.generate(
    4,
    (_) => Uint8List(Fx200PedalScenes.sceneBytes),
  );
  final Uint8List _stage = Uint8List(Fx200PedalScenes.sceneBytes);
  int active = 0;
  int preset = 57;
  final List<List<int>> sent = <List<int>>[];
  final _frames = StreamController<({int opcode, Uint8List body})>.broadcast(
    sync: true,
  );

  @override
  bool get isConnected => true;

  @override
  Stream<({int opcode, Uint8List body})> get frames => _frames.stream;

  void _reply(List<int> body) => scheduleMicrotask(
    () => _frames.add((
      opcode: Fx200PedalScenes.opcode,
      body: Uint8List.fromList(body),
    )),
  );

  @override
  void sendPacket(Uint8List packet) {
    // [n, AA 55 lenLo lenHi op body.. crcHi crcLo]
    final frame = packet.sublist(1);
    expect(Fx200Protocol.verifyFrame(frame), isTrue);
    final len = frame[2] | frame[3] << 8;
    expect(frame[4], Fx200PedalScenes.opcode);
    final b = frame.sublist(5, 4 + len);
    sent.add(b);
    const chunk = Fx200PedalScenes.chunkBytes;
    switch (b[0]) {
      case 1:
        _reply(<int>[1, 2, preset, active, 4, 0, 3, chunk, 8]);
      case 2:
        if (b[1] < 4) active = b[1];
        _reply(<int>[2, b[1] < 4 ? 0 : 1, active]);
      case 3:
        final n = b[1], c = b[2];
        _reply(<int>[
          3,
          0,
          n,
          c,
          ...scenes[n].sublist(c * chunk, (c + 1) * chunk),
        ]);
      case 4:
        final n = b[1], c = b[2];
        _stage.setRange(c * chunk, (c + 1) * chunk, b.sublist(3));
        if (c == 7) scenes[n].setAll(0, _stage);
        _reply(<int>[4, 0, n, c]);
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
  test('layout: 10 module blocks of 0xC8 bytes in 8 chunks of 250', () {
    expect(Fx200PedalScenes.sceneBytes, 2000);
    expect(Fx200PedalScenes.chunkCount * Fx200PedalScenes.chunkBytes, 2000);
  });

  test('info, select, read and write against the firmware logic', () async {
    final pedal = _FakePedal();
    final c = Fx200PedalScenesClient(pedal);

    final info = await c.info();
    expect(info.preset, 57);
    expect(info.active, 0);
    expect(info.version, 2);

    expect(await c.select(2), 2);
    expect(pedal.active, 2);

    final s1 = await c.read(1);
    expect(s1.data.every((v) => v == 1), isTrue);

    await c.write(3, s1.data);
    expect(pedal.scenes[3].every((v) => v == 1), isTrue);
    // 8 chunks, each 3 + 250 bytes of body.
    expect(pedal.sent.where((b) => b[0] == 4).length, 8);
    expect(pedal.sent.last.length, 3 + Fx200PedalScenes.chunkBytes);
  });

  test('requests are serialised (one reply per request)', () async {
    final pedal = _FakePedal();
    final c = Fx200PedalScenesClient(pedal);
    final all = await Future.wait([c.read(0), c.read(1), c.info()]);
    expect((all[0] as Fx200PedalScene).data.first, 0);
    expect((all[1] as Fx200PedalScene).data.first, 1);
  });

  test('module block: enable +4, model +5, params u16 LE from +0x34', () {
    final data = Uint8List(Fx200PedalScenes.sceneBytes);
    const slot = 8; // DELAY: preset +0x650 (enable +0x654, param0 +0x684)
    const base = slot * 0xC8;
    data[base + 4] = 1;
    data[base + 5] = 2;
    data[base + 0x34] = 0xE0;
    data[base + 0x35] = 0x01;
    data[base + 0x36] = 20;
    final m = Fx200PedalScene(data).module(slot, 2);
    expect(m.enabled, isTrue);
    expect(m.modelId, 2);
    expect(m.params, [480, 20]);
    expect(m.toModuleState(slot).opcode, 0x99);
  });

  test('info with another chunk layout is rejected', () {
    expect(
      Fx200PedalScenesInfo.fromBody(<int>[1, 2, 0, 0, 4, 0, 3, 200, 10]),
      isNull,
    );
  });

  test('0xF5 is only sendable to the FX200 Studio firmware v2', () {
    expect(
      () => fx200CheckSendable(0xf5),
      throwsA(isA<Fx200ForbiddenCommand>()),
    );
    expect(
      () => fx200CheckSendable(0xf5, customFirmware: true),
      returnsNormally,
    );
    List<int> dev(int v) => <int>[
      ...'FX200'.codeUnits,
      0,
      0x53,
      0x43,
      0x4E,
      v,
      ...List<int>.filled(6, 0),
    ];
    expect(
      Fx200FirmwareFeatures.fromFrame(0x84, dev(1))!.hasPedalSceneCommand,
      isFalse,
    );
    expect(
      Fx200FirmwareFeatures.fromFrame(0x84, dev(2))!.hasPedalSceneCommand,
      isTrue,
    );
  });
}
