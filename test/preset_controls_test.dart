import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/domain/entities/preset.dart';
import 'package:fx200_studio/presentation/state/editor_notifier.dart';
import 'package:fx200_studio/services/fx200_hardware_sync.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';

/// Hardware link that records what the editor sends and lets the test play
/// frames "from the pedal".
class _FakeSync extends Fx200HardwareSync {
  final _in = StreamController<({int opcode, Uint8List body})>.broadcast();
  final List<String> sent = <String>[];

  @override
  Stream<({int opcode, Uint8List body})> get frames => _in.stream;

  void fromPedal(int opcode, List<int> body) =>
      _in.add((opcode: opcode, body: Uint8List.fromList(body)));

  @override
  void sendExpAssignment(Fx200ExpFrame f) => sent.add(
    'A3 p${f.pedal} m${f.mode} ${f.moduleSlot}:${f.paramIndex} '
    '${f.min}-${f.max} ${f.assigned ? 'on' : 'off'}',
  );

  @override
  void sendVolumePedalRange(Fx200VolumePedalRange r) =>
      sent.add('AE ${r.min}-${r.max}');

  @override
  void sendFootswitch(Fx200FootswitchConfig c) =>
      sent.add('A4 ${c.mode} ${c.ctrlMask}');

  @override
  void sendBlockUpdate(EffectBlock block, {bool force = false}) =>
      sent.add('BLOCK ${block.category.name}');

  @override
  void sendChainOrder(List<EffectBlock> blocks) => sent.add('A0');

  @override
  void sendTapTempoBpm(double bpm) => sent.add('BPM $bpm');
}

class _Editor extends EditorNotifier {
  void connected() => state = state.copyWith(isHardwareConnected: true);
}

Future<(ProviderContainer, _FakeSync, _Editor)> _setUp() async {
  final sync = _FakeSync();
  final editor = _Editor();
  final c = ProviderContainer(
    overrides: [
      fx200HardwareSyncProvider.overrideWithValue(sync),
      editorProvider.overrideWith(() => editor),
    ],
  );
  c.read(editorProvider);
  for (var i = 0; i < 50 && c.read(editorProvider).preset == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  editor.connected();
  return (c, sync, editor);
}

void main() {
  test('pedal reports controls without marking the preset unsaved', () async {
    final (c, sync, _) = await _setUp();
    addTearDown(c.dispose);
    sync.fromPedal(0xa4, [1, 0x00, 0x82, 0, 120]);
    sync.fromPedal(0xa3, [0, 0, 3, 0, 0, 100, 0, 10, 0, 1]);
    sync.fromPedal(0xa3, [1, 0, 9, 2, 0, 50, 0, 0, 0, 1]);
    sync.fromPedal(0xae, [0, 90, 0, 5]);
    await Future<void>.delayed(Duration.zero);
    final s = c.read(editorProvider);
    final ctl = s.preset!.controls;
    expect(s.hasUnsavedChanges, isFalse);
    expect((ctl.footswitchMode, ctl.ctrlMask), (1, 0x82));
    expect(
      ctl.exp1.single,
      const ExpAssignment(moduleSlot: 2, paramIndex: 0, min: 10, max: 100),
    );
    expect(ctl.exp2.single.moduleSlot, 8);
    expect((ctl.volumeMin, ctl.volumeMax), (5, 90));
    expect(sync.sent, isEmpty);
  });

  test(
    'edits are one unsaved preset change, sent as a diff, undoable',
    () async {
      final (c, sync, editor) = await _setUp();
      addTearDown(c.dispose);
      sync.fromPedal(0xa4, [0, 0, 0, 0, 120]);
      sync.fromPedal(0xa3, [0, 0, 1, 0, 0, 0, 0, 0, 0, 0]);
      sync.fromPedal(0xae, [0, 100, 0, 0]);
      await Future<void>.delayed(Duration.zero);

      final ctl = c.read(editorProvider).preset!.controls;
      const a = ExpAssignment(moduleSlot: 2, paramIndex: 1, min: 0, max: 80);
      editor.editControls(ctl.withAssignments(0, [a]).copyWith(ctrlMask: 0x4));
      expect(c.read(editorProvider).hasUnsavedChanges, isTrue);
      expect(sync.sent, ['A4 0 4', 'A3 p0 m0 2:1 0-80 on']);

      sync.sent.clear();
      editor.undo();
      expect(sync.sent, ['A4 0 0', 'A3 p0 m0 2:1 0-0 off']);
      expect(c.read(editorProvider).preset!.controls.exp1, isEmpty);

      sync.sent.clear();
      editor.redo();
      expect(sync.sent, ['A4 0 4', 'A3 p0 m0 2:1 0-80 on']);
    },
  );

  test('undo of a parameter change is sent to the pedal', () async {
    final (c, sync, editor) = await _setUp();
    addTearDown(c.dispose);
    final block = c.read(editorProvider).preset!.blocks.first;
    final p = block.parameters.first;
    editor.updateParameter(
      blockId: block.id,
      parameterId: p.id,
      value: p.value == p.max ? p.min : p.max,
    );
    sync.sent.clear();
    editor.undo();
    expect(sync.sent, ['BLOCK ${block.category.name}']);
  });
}
