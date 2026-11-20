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
    'edits stay in the active scene; switching sends only changes',
    () async {
      final file = File('${tmp.path}/scenes.json');
      final (c, sync, editor) = await start(file);
      addTearDown(c.dispose);
      final scenes = c.read(scenesProvider.notifier);
      final block = c.read(editorProvider).preset!.blocks.first;
      final p = block.parameters.first;
      double v() =>
          c.read(editorProvider).preset!.blocks.first.parameters.first.value;
      void set(double x) => editor.updateParameter(
        blockId: block.id,
        parameterId: p.id,
        value: x,
      );

      scenes.select('A'); // empty -> copy of the current sound
      expect(c.read(scenesProvider).active, 'A');
      set(p.min + 1); // belongs to A
      scenes.select('B'); // empty -> copy of A
      set(p.min + 2); // belongs to B only
      scenes.select('C');
      set(p.min + 3);

      sync.sent.clear();
      scenes.select('A');
      expect(v(), p.min + 1);
      expect(sync.sent, [block.category.name]);
      scenes.select('B');
      expect(v(), p.min + 2);
      set(p.min + 7); // edit B again
      scenes.select('C');
      expect(v(), p.min + 3);
      scenes.select('A');
      expect(v(), p.min + 1);
      scenes.select('B');
      expect(v(), p.min + 7);
      // Switching scene is not undoable into another scene's sound.
      expect(c.read(editorProvider).canUndo, isFalse);
    },
  );

  test('Save writes the scenes; leaving without saving discards', () async {
    final file = File('${tmp.path}/scenes.json');
    final (c, _, editor) = await start(file);
    addTearDown(c.dispose);
    final scenes = c.read(scenesProvider.notifier);
    final block = c.read(editorProvider).preset!.blocks.first;
    final p = block.parameters.first;
    final patch = c.read(editorProvider).preset!.patchNumber;
    double v() =>
        c.read(editorProvider).preset!.blocks.first.parameters.first.value;
    void set(double x) =>
        editor.updateParameter(blockId: block.id, parameterId: p.id, value: x);

    scenes.select('A');
    set(p.min + 1);
    scenes.select('B');
    set(p.min + 2);
    expect(file.existsSync(), isFalse); // nothing saved yet
    expect(c.read(scenesProvider).activeModified, isTrue);
    await editor.saveCurrentPreset();
    expect(c.read(scenesProvider).activeModified, isFalse);
    final disk = SceneStore(file: file).readAll()[patch]!;
    expect(disk.active, 'B');
    expect(disk.scenes.keys.toSet(), {'A', 'B'});

    set(p.min + 9); // unsaved edit of B
    await editor.loadPreset(patch + 1);
    await editor.loadPreset(patch);
    scenes.select('A');
    expect(v(), p.min + 1);
    scenes.select('B');
    expect(v(), p.min + 2);
  });

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
