import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_backup.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

/// Simulated pedal: answers `0xA6` with the state frames of that preset
/// (ending with `0xBB`, as in captura.pcapng) and records what is written.
class _FakePedal implements Fx200DeviceLink {
  _FakePedal(this.presetCount);

  final int presetCount;
  final StreamController<({int opcode, Uint8List body})> _frames =
      StreamController<({int opcode, Uint8List body})>.broadcast();
  final List<({int opcode, Uint8List body})> written =
      <({int opcode, Uint8List body})>[];

  @override
  bool isConnected = true;

  @override
  Stream<({int opcode, Uint8List body})> get frames => _frames.stream;

  static Uint8List stateBody(int opcode, int preset) =>
      Uint8List.fromList(<int>[opcode, preset, 0x00, 0x01]);

  static Uint8List dumpFor(int preset) {
    final dump = Uint8List(Fx200Protocol.presetDumpBytes);
    dump.setAll(0, 'PRESET $preset'.codeUnits);
    dump.setAll(Fx200Protocol.presetDumpChainOffset, <int>[
      2, 1, 3, 4, 5, 6, 7, 8, 9, 10, //
      1, 1, 1, 1, 0, 1, 0, 0, 1, 1,
    ]);
    return dump;
  }

  @override
  Uint8List? chainBlockFor(int index) => null;

  @override
  void rememberChainBlock(int index, Uint8List chain) {}

  @override
  Future<void> waitUntilReady() async {}

  @override
  void sendPacket(Uint8List packet) {
    expect(Fx200Protocol.verifyFrame(packet), isTrue);
    final len = packet[3] | (packet[4] << 8);
    final opcode = packet[5];
    final body = Uint8List.fromList(packet.sublist(6, 5 + len));
    written.add((opcode: opcode, body: body));
    if (opcode == Fx200Protocol.opPresetRead) {
      final preset = body[0];
      scheduleMicrotask(() {
        for (final op in fx200PresetStateOpcodes) {
          _frames.add((opcode: op, body: stateBody(op, preset)));
        }
      });
    }
  }

  @override
  Future<({Map<int, Uint8List> dumps, Fx200GlobalSettings? global})>
  readFullDump() async {
    return (
      dumps: <int, Uint8List>{
        for (var i = 0; i < presetCount; i++) i: dumpFor(i),
      },
      global: Fx200GlobalSettings.fromBody(List<int>.filled(46, 7)),
    );
  }
}

Fx200BackupService _service(_FakePedal pedal) => Fx200BackupService(
  pedal,
  presetCount: pedal.presetCount,
  selectTimeout: const Duration(milliseconds: 200),
  packetGap: Duration.zero,
  settleDelay: Duration.zero,
);

void main() {
  test('backup captures every preset and survives a file round-trip', () async {
    final pedal = _FakePedal(3);
    final backup = await _service(pedal)
        .createBackup(knownNames: const <int, String>{1: 'J900 V1 LEAD'});

    expect(backup.presets.length, 3);
    expect(backup.restorablePresetCount, 3);
    expect(backup.presets[1].name, 'J900 V1 LEAD');
    expect(backup.presets[0].name, 'PRESET 0'); // falls back to the dump
    expect(backup.globalSettings!.raw, List<int>.filled(46, 7));

    final decoded = Fx200Backup.decode(backup.encode());
    expect(decoded.presets.length, 3);
    expect(decoded.restorablePresetCount, 3);
    expect(decoded.presets[2].stateFrames[0x93], _FakePedal.stateBody(0x93, 2));
    expect(decoded.presets[2].dump, _FakePedal.dumpFor(2));
    expect(decoded.globalSettings, backup.globalSettings);
  });

  test(
    'restore replays each preset in a safe order, then the SYSTEM block',
    () async {
      final source = await _service(_FakePedal(2))
          .createBackup(knownNames: const <int, String>{});
      final pedal = _FakePedal(2);
      final result = await _service(pedal).restoreBackup(source);

      expect(result.written, 2);
      expect(result.skipped, 0);
      final ops = pedal.written.map((w) => w.opcode).toList();
      const perPreset = <int>[
        0xa6, 0xa0, //
        0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9a,
        0xa3, 0xa4, 0xbb, 0xa8,
      ];
      expect(ops, <int>[...perPreset, ...perPreset, 0xa1]);

      final chain = pedal.written.firstWhere((w) => w.opcode == 0xa0).body;
      expect(chain.sublist(0, 10), <int>[2, 1, 3, 4, 5, 6, 7, 8, 9, 10]);

      final save = pedal.written.lastWhere((w) => w.opcode == 0xa8).body;
      expect(save[0], 1);
      expect(String.fromCharCodes(save.sublist(1, 9)), 'PRESET 1');
    },
  );

  test('restore skips incomplete presets and honours the options', () async {
    final backup = Fx200Backup(
      createdAt: DateTime(2026),
      globalSettings: Fx200GlobalSettings.fromBody(List<int>.filled(46, 0)),
      presets: const <Fx200PresetSnapshot>[
        Fx200PresetSnapshot(index: 5, name: 'EMPTY'),
      ],
    );
    final pedal = _FakePedal(1);
    final result = await _service(pedal)
        .restoreBackup(backup, restoreGlobals: false);
    expect(result.written, 0);
    expect(result.skipped, 1);
    expect(pedal.written, isEmpty);
  });

  test('cancel stops the sweep', () async {
    final pedal = _FakePedal(50);
    final service = _service(pedal);
    final future = service.createBackup(
      knownNames: const <int, String>{},
      onProgress: (fraction, _) {
        if (fraction > 0.2) service.cancel();
      },
    );
    await expectLater(future, throwsA(isA<Fx200BackupCancelled>()));
  });

  test('rejects files that are not FX200 Studio backups', () {
    expect(
      () => Fx200Backup.decode('{"format":"other"}'),
      throwsFormatException,
    );
    expect(() => Fx200Backup.decode('not json'), throwsFormatException);
  });
}
