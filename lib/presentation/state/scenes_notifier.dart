import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/scene_store.dart';
import '../../domain/entities/preset.dart';
import '../../domain/entities/scene.dart';
import 'device_settings_notifier.dart';
import 'editor_notifier.dart';
import 'editor_state.dart';
import 'pedal_scenes_notifier.dart' show pedalSceneModeFor;

/// Scenes A-D of the active preset slot.
class ScenesState {
  const ScenesState({
    this.patch,
    this.scenes = const <String, Scene>{},
    this.active,
    this.activeModified = false,
    this.storedForOtherPreset = false,
  });

  final int? patch;
  final Map<String, Scene> scenes;

  /// Scene being played / edited.
  final String? active;

  /// True when the active scene has edits not yet saved with the preset.
  final bool activeModified;

  /// True when the scenes were saved for a preset with another name (the
  /// slot was overwritten since).
  final bool storedForOtherPreset;

  bool has(String scene) => scenes.containsKey(scene);
}

final sceneStoreProvider = Provider<SceneStore>((ref) => SceneStore());

final scenesProvider = NotifierProvider<ScenesNotifier, ScenesState>(
  ScenesNotifier.new,
);

/// App-side scene mode: four snapshots of the modules per preset slot,
/// stored on this computer and applied to the pedal through the normal
/// module frames (only the modules that change are sent). It works while
/// FX200 Studio is connected; a custom firmware will later store and switch
/// scenes on the pedal itself (NAM_PATCH_RESEARCH.md §8).
///
/// Behaves like the scenes of a multi-effects unit: edits made while a
/// scene is active belong to that scene, switching scenes keeps them, and
/// "Save" stores the preset together with its scenes. Leaving the preset
/// without saving discards the scene edits as well.
class ScenesNotifier extends Notifier<ScenesState> {
  SceneStore get _db => ref.read(sceneStoreProvider);
  Map<int, PresetScenes> get _work => _db.all;
  Map<int, String> get _activeByPatch => _db.activeByPatch;

  @override
  ScenesState build() {
    ref.listen<EditorState>(editorProvider, _onEditor);
    return _compute(ref.read(editorProvider).preset);
  }

  void _onEditor(EditorState? prev, EditorState next) {
    final p = next.preset;
    if (p == null) {
      state = const ScenesState();
      return;
    }
    final before = prev?.preset;
    if (before != null && before.patchNumber != p.patchNumber) {
      // Left the preset: unsaved scene edits go with the unsaved preset.
      _db.revert(before.patchNumber);
    } else if (pedalSceneModeFor(
      next,
      ref.read(deviceSettingsProvider).global?.fsMode,
    )) {
      // The pedal handles scenes (FS MODE SCENE): the sound belongs to the
      // pedal's scene, not to an app-side one.
    } else if (prev != null && next.saveCount != prev.saveCount) {
      _db.commit(p);
    } else if (before != null && !identical(before, p)) {
      _follow(p);
    }
    state = _compute(p);
  }

  /// The sound changed inside the active scene: the scene takes the edit.
  void _follow(Preset p) {
    final active = _activeByPatch[p.patchNumber];
    final entry = _work[p.patchNumber];
    if (active == null || entry == null || !entry.scenes.containsKey(active)) {
      return;
    }
    if (entry.scenes[active]!.matches(p)) return;
    _work[p.patchNumber] = entry.copyWith(
      scenes: <String, Scene>{...entry.scenes, active: Scene.capture(p)},
    );
  }

  void _refresh() => state = _compute(_preset);

  ScenesState _compute(Preset? preset) {
    if (preset == null) return const ScenesState();
    final entry = _work[preset.patchNumber];
    final active = _activeByPatch[preset.patchNumber];
    final scenes = entry?.scenes ?? const <String, Scene>{};
    final saved = active == null
        ? null
        : _db.saved[preset.patchNumber]?.scenes[active];
    return ScenesState(
      patch: preset.patchNumber,
      scenes: scenes,
      active: active,
      activeModified:
          active != null &&
          scenes.containsKey(active) &&
          (saved == null || !saved.matches(preset)),
      storedForOtherPreset:
          entry != null &&
          entry.presetName.isNotEmpty &&
          entry.presetName != preset.name,
    );
  }

  Preset? get _preset => ref.read(editorProvider).preset;

  /// Click on a scene: switches to it. An empty scene starts as a copy of
  /// the current sound.
  void select(String scene) {
    final preset = _preset;
    if (preset == null) return;
    final entry = _work[preset.patchNumber] ?? const PresetScenes();
    final stored = entry.scenes[scene];
    if (stored == null) {
      _work[preset.patchNumber] = entry.copyWith(
        presetName: preset.name,
        scenes: <String, Scene>{...entry.scenes, scene: Scene.capture(preset)},
      );
      _activeByPatch[preset.patchNumber] = scene;
      // Marks the preset as edited (the new scene is saved with it).
      ref.read(editorProvider.notifier).selectScene(scene);
      _refresh();
      return;
    }
    if (_activeByPatch[preset.patchNumber] == scene) return;
    _activeByPatch[preset.patchNumber] = scene;
    ref.read(editorProvider.notifier).applyScene(scene, stored);
    _refresh();
  }

  /// Right-click "save": copies the current sound into [scene] and writes
  /// it to disk right away.
  void save(String scene) {
    final preset = _preset;
    if (preset == null) return;
    final captured = Scene.capture(preset);
    final entry = _work[preset.patchNumber] ?? const PresetScenes();
    _work[preset.patchNumber] = entry.copyWith(
      presetName: preset.name,
      scenes: <String, Scene>{...entry.scenes, scene: captured},
    );
    _activeByPatch[preset.patchNumber] = scene;
    _db.persistScene(preset.patchNumber, scene, captured, preset.name);
    ref.read(editorProvider.notifier).selectScene(scene);
    _refresh();
  }

  /// Removes [scene] of the active preset (also from disk).
  void clear(String scene) {
    final preset = _preset;
    if (preset == null) return;
    final entry = _work[preset.patchNumber];
    if (entry == null) return;
    _work[preset.patchNumber] = entry.copyWith(
      scenes: <String, Scene>{...entry.scenes}..remove(scene),
    );
    if (_activeByPatch[preset.patchNumber] == scene) {
      _activeByPatch.remove(preset.patchNumber);
    }
    _db.persistScene(preset.patchNumber, scene, null, preset.name);
    _refresh();
  }
}
