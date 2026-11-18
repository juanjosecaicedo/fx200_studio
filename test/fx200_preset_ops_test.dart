import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/services/fx200_backup.dart';
import 'package:fx200_studio/services/fx200_preset_ops.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

/// Pedal simulator with real preset memory: `0xA6` selects a slot and
/// reports its frames; state frames / `0xA0` edit the active slot; `0xA8`
/// commits the edit buffer and the name to the slot.
class _MemoryPedal implements Fx200DeviceLink {
  _MemoryPedal(int count) {
    for (var i = 0; i < count; i++) {
      stored[i] = <int, Uint8List>{
        for (final op in fx200PresetStateOpcodes)
          op: Uint8List.fromList(<int>[op, i]),
      };
      names[i] = 'P$i';
      chains[i] = Uint8List.fromList(<int>[
        ...List<int>.generate(10, (k) => k + 1),
        ...List.filled(10, i),
      ]);
    }
  }

  final Map<int, Map<int, Uint8List>> stored = <int, Map<int, Uint8List>>{};
  final Map<int, String> names = <int, String>{};
  final Map<int, Uint8List> chains = <int, Uint8List>{};
  final Map<int, Uint8List> _edit = <int, Uint8List>{};
  Uint8List? _editChain;
  int active = 0;
  int writes = 0;

  final StreamController<({int opcode, Uint8List body})> _frames =
      StreamController<({int opcode, Uint8List body})>.broadcast();

  @override
  bool get isConnected => true;

  @override
  Stream<({int opcode, Uint8List body})> get frames => _frames.stream;

  @override
  Uint8List? chainBlockFor(int index) => chains[index];

  @override
  void rememberChainBlock(int index, Uint8List chain) {}

  @override
  Future<void> waitUntilReady() async {}

  @override
  Future<({Map<int, Uint8List> dumps, Fx200GlobalSettings? global})>
  readFullDump() async => (dumps: <int, Uint8List>{}, global: null);

  /// Identity of the content in [slot] (which original preset it came from).
  int contentOf(int slot) => stored[slot]![0x91]![1];

  @override
  void sendPacket(Uint8List packet) {
    final len = packet[3] | (packet[4] << 8);
    final op = packet[5];
    final body = Uint8List.fromList(packet.sublist(6, 5 + len));
    if (op == Fx200Protocol.opPresetRead) {
      active = body[0];
      _edit
        ..clear()
        ..addAll(stored[active]!);
      _editChain = chains[active];
      scheduleMicrotask(() {
        for (final o in fx200PresetStateOpcodes) {
          final body = stored[active]![o];
          if (body != null) _frames.add((opcode: o, body: body));
        }
      });
    } else if (op == Fx200Protocol.opCmdA0) {
      _editChain = body;
    } else if (fx200PresetStateOpcodes.contains(op)) {
      _edit[op] = body;
    } else if (op == Fx200Protocol.opPresetSave) {
      final slot = body[0];
      stored[slot] = Map<int, Uint8List>.of(_edit);
      chains[slot] = _editChain!;
      names[slot] = String.fromCharCodes(body.sublist(1).where((b) => b != 0));
      writes++;
    }
  }
}

Fx200PresetOps _ops(_MemoryPedal pedal) => Fx200PresetOps(
  pedal,
  io: Fx200BackupService(
    pedal,
    selectTimeout: const Duration(milliseconds: 200),
    packetGap: Duration.zero,
    settleDelay: Duration.zero,
  ),
);

void main() {
  test('copy + paste duplicates a preset into another slot', () async {
    final pedal = _MemoryPedal(6);
    final ops = _ops(pedal);
    final clip = await ops.copy(2, pedal.names);
    expect(clip.name, 'P2');
    expect(pedal.writes, 0, reason: 'copy never writes');

    await ops.paste(clip, 5);
    expect(pedal.contentOf(5), 2);
    expect(pedal.names[5], 'P2');
    expect(pedal.chains[5]!.last, 2, reason: 'chain copied too');
    expect(pedal.contentOf(2), 2, reason: 'source untouched');
    expect(pedal.writes, 1);
  });

  test('moving down shifts the presets in between up', () async {
    final pedal = _MemoryPedal(6);
    final names = await _ops(pedal).move(1, 4, Map.of(pedal.names));
    expect(
      [for (var i = 0; i < 6; i++) pedal.contentOf(i)],
      [0, 2, 3, 4, 1, 5],
    );
    expect(names, {1: 'P2', 2: 'P3', 3: 'P4', 4: 'P1'});
    expect(pedal.writes, 4, reason: 'only the affected range is rewritten');
  });

  test('moving up shifts the presets in between down', () async {
    final pedal = _MemoryPedal(6);
    await _ops(pedal).move(4, 1, Map.of(pedal.names));
    expect(
      [for (var i = 0; i < 6; i++) pedal.contentOf(i)],
      [0, 4, 1, 2, 3, 5],
    );
    expect(
      [for (var i = 0; i < 6; i++) pedal.names[i]],
      ['P0', 'P4', 'P1', 'P2', 'P3', 'P5'],
    );
  });

  test('a failed read aborts the move before anything is written', () async {
    final pedal = _MemoryPedal(6);
    pedal.stored[3]!.remove(Fx200Protocol.opCmdA4); // incomplete answer
    await expectLater(
      _ops(pedal).move(1, 4, Map.of(pedal.names)),
      throwsA(isA<StateError>()),
    );
    expect(pedal.writes, 0);
    expect(
      [for (var i = 0; i < 6; i++) pedal.contentOf(i)],
      [0, 1, 2, 3, 4, 5],
    );
  });

  test(
    'clear switches every module off and resets chain, FS and EXP',
    () async {
      final pedal = _MemoryPedal(4);
      pedal.stored[2]![0x93] = Uint8List.fromList([
        0x00,
        0x01,
        0x00,
        0x07,
        0x00,
        0x37,
      ]);
      await _ops(pedal).clear(2);

      final amp = pedal.stored[2]![0x93]!;
      expect(amp.sublist(0, 2), [0, 0], reason: 'module disabled');
      expect(amp.sublist(2), [
        0x00,
        0x07,
        0x00,
        0x37,
      ], reason: 'model/params kept');
      expect(pedal.stored[2]![Fx200Protocol.opCmdA4], [0, 0, 0, 0, 120]);
      expect(
        pedal.stored[2]![Fx200Protocol.opCmdA3],
        Fx200PresetOps.defaultExpBody,
      );
      expect(pedal.chains[2], [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
        ...List.filled(10, 0),
      ]);
      expect(pedal.names[2], 'Empty');
      expect(pedal.contentOf(1), 1, reason: 'neighbours untouched');
      expect(pedal.writes, 1);
    },
  );

  test('clear writes nothing if the preset cannot be read', () async {
    final pedal = _MemoryPedal(4);
    pedal.stored[2]!.remove(0x95);
    await expectLater(_ops(pedal).clear(2), throwsA(isA<StateError>()));
    expect(pedal.writes, 0);
  });
}
