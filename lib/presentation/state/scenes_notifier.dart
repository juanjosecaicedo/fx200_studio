import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/scene_store.dart';
import '../../domain/entities/preset.dart';
import '../../domain/entities/scene.dart';
import 'editor_notifier.dart';

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

  /// Scene last applied or saved in this session for this preset.
  final String? active;

  /// True when the sound was edited after [active] was applied / saved.
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
class ScenesNotifier extends Notifier<ScenesState> {
  SceneStore get _db => ref.read(sceneStoreProvider);
  Map<int, PresetScenes> get _store => _db.all;
  Map<int, String> get _activeByPatch => _db.activeByPatch;

  @override
  ScenesState build() {
    final preset = ref.watch(editorProvider.select((s) => s.preset));
    return _compute(preset);
  }

  void _refresh() => state = _compute(_preset);

  ScenesState _compute(Preset? preset) {
    if (preset == null) return const ScenesState();
    final entry = _store[preset.patchNumber];
    final active = _activeByPatch[preset.patchNumber];
    final scenes = entry?.scenes ?? const <String, Scene>{};
    final activeScene = active == null ? null : scenes[active];
    return ScenesState(
      patch: preset.patchNumber,
      scenes: scenes,
      active: active,
      activeModified: activeScene != null && !activeScene.matches(preset),
      storedForOtherPreset:
          entry != null &&
          entry.presetName.isNotEmpty &&
          entry.presetName != preset.name,
    );
  }

  Preset? get _preset => ref.read(editorProvider).preset;

  /// Click on a scene: applies it, or stores the current sound when empty.
  void select(String scene) {
    final preset = _preset;
    if (preset == null) return;
    final stored = _store[preset.patchNumber]?.scenes[scene];
    if (stored == null) {
      save(scene);
      return;
    }
    _activeByPatch[preset.patchNumber] = scene;
    ref.read(editorProvider.notifier).applyScene(scene, stored);
    _refresh();
  }

  /// Stores the current sound of the active preset in [scene].
  void save(String scene) {
    final preset = _preset;
    if (preset == null) return;
    final entry = _store[preset.patchNumber] ?? const PresetScenes();
    _store[preset.patchNumber] = entry.copyWith(
      presetName: preset.name,
      scenes: <String, Scene>{...entry.scenes, scene: Scene.capture(preset)},
    );
    _activeByPatch[preset.patchNumber] = scene;
    _persist();
    ref.read(editorProvider.notifier).selectScene(scene);
    _refresh();
  }

  /// Removes [scene] of the active preset.
  void clear(String scene) {
    final preset = _preset;
    if (preset == null) return;
    final entry = _store[preset.patchNumber];
    if (entry == null) return;
    _store[preset.patchNumber] = entry.copyWith(
      scenes: <String, Scene>{...entry.scenes}..remove(scene),
    );
    if (_activeByPatch[preset.patchNumber] == scene) {
      _activeByPatch.remove(preset.patchNumber);
    }
    _persist();
    _refresh();
  }

  void _persist() {
    try {
      _db.flush();
    } catch (_) {
      // Not fatal: the scenes stay for this session.
    }
  }
}
