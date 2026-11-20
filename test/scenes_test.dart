import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/data/scene_store.dart';
import 'package:fx200_studio/domain/entities/preset.dart';
import 'package:fx200_studio/domain/entities/scene.dart';
import 'package:fx200_studio/presentation/state/editor_notifier.dart';
import 'package:fx200_studio/presentation/state/scenes_notifier.dart';
import 'package:fx200_studio/services/fx200_hardware_sync.dart';

class _FakeSync extends Fx200HardwareSync {
  final _in = StreamController<({int opcode, Uint8List body})>.broadcast();
  final List<String> sent = <String>[];
  @override
  Stream<({int opcode, Uint8List body})> get frames => _in.stream;
  @override
  void sendBlockUpdate(EffectBlock block, {bool force = false}) =>
      sent.add(block.category.name);
  @override
  void sendChainOrder(List<EffectBlock> blocks) => sent.add('chain');
  @override
  void sendTapTempoBpm(double bpm) {}
}

class _Editor extends EditorNotifier {
  void connected() => state = state.copyWith(isHardwareConnected: true);
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('fx200_scenes'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<(ProviderContainer, _FakeSync, _Editor)> start(File f) async {
    final sync = _FakeSync();
    final editor = _Editor();
    final c = ProviderContainer(
      overrides: [
        fx200HardwareSyncProvider.overrideWithValue(sync),
        editorProvider.overrideWith(() => editor),
        sceneStoreProvider.overrideWithValue(SceneStore(file: f)),
      ],
    );
    c.read(editorProvider);
    for (var i = 0; i < 50 && c.read(editorProvider).preset == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    editor.connected();
    c.read(scenesProvider);
    return (c, sync, editor);
  }

  test(
    'save A, edit, save B, recall A: only the changed module is sent',
    () async {
      final file = File('${tmp.path}/scenes.json');
      final (c, sync, editor) = await start(file);
      addTearDown(c.dispose);
      final scenes = c.read(scenesProvider.notifier);

      scenes.select('A'); // empty -> stores the current sound
      expect(c.read(scenesProvider).has('A'), isTrue);
      expect(c.read(scenesProvider).active, 'A');

      final block = c.read(editorProvider).preset!.blocks.first;
      final p = block.parameters.first;
      final original = p.value;
      final changed = p.value == p.max ? p.min : p.max;
      editor.updateParameter(
        blockId: block.id,
        parameterId: p.id,
        value: changed,
      );
      expect(c.read(scenesProvider).activeModified, isTrue);

      scenes.save('B');
      expect(c.read(scenesProvider).active, 'B');
      expect(c.read(scenesProvider).activeModified, isFalse);

      sync.sent.clear();
      scenes.select('A');
      final now = c.read(editorProvider).preset!.blocks.first;
      expect(now.parameters.first.value, original);
      expect(sync.sent, [block.category.name]);
      expect(c.read(scenesProvider).activeModified, isFalse);

      // One undo step brings scene B's sound back.
      editor.undo();
      expect(
        c.read(editorProvider).preset!.blocks.first.parameters.first.value,
        changed,
      );
    },
  );

  test('scenes persist per preset slot and can be cleared', () async {
    final file = File('${tmp.path}/scenes.json');
    final (c, _, _) = await start(file);
    c.read(scenesProvider.notifier).save('C');
    c.dispose();
    expect(file.existsSync(), isTrue);

    final reread = SceneStore(file: file).readAll();
    expect(reread[0]!.scenes.keys, ['C']);

    final (c2, _, _) = await start(file);
    addTearDown(c2.dispose);
    expect(c2.read(scenesProvider).has('C'), isTrue);
    c2.read(scenesProvider.notifier).clear('C');
    expect(c2.read(scenesProvider).has('C'), isFalse);
    expect(SceneStore(file: file).readAll()[0], isNull);
  });

  test('scene JSON round trip', () async {
    const s = Scene(<EffectCategory, SceneBlockState>{
      EffectCategory.amp: SceneBlockState(
        enabled: true,
        modelName: 'US 65 DR',
        values: <double>[50, 60],
      ),
    });
    final back = Scene.fromJson(s.toJson());
    expect(back.blocks[EffectCategory.amp]!.modelName, 'US 65 DR');
    expect(back.blocks[EffectCategory.amp]!.values, [50, 60]);
  });
}
