import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../services/fx200_device_settings.dart';
import '../../services/fx200_pedal_scenes.dart';
import 'device_settings_notifier.dart';
import 'editor_notifier.dart';
import 'editor_state.dart';

/// Scenes stored on the pedal by the FX200 Studio firmware (patch v2, FS
/// MODE SCENE), seen and edited through the `0xF5` command.
class PedalScenesState {
  const PedalScenesState({
    this.available = false,
    this.preset,
    this.active,
    this.scenes,
    this.busy = false,
    this.error,
  });

  /// Pedal with the scenes command, connected, in FS MODE SCENE.
  final bool available;

  /// Preset the scenes belong to, and the scene being played (0..3).
  final int? preset;
  final int? active;

  /// The four scenes as last read (null until [PedalScenesNotifier.loadAll]).
  final List<Fx200PedalScene>? scenes;
  final bool busy;
  final String? error;

  PedalScenesState copyWith({
    bool? available,
    int? preset,
    int? active,
    List<Fx200PedalScene>? scenes,
    bool clearScenes = false,
    bool? busy,
    String? error,
    bool clearError = false,
  }) => PedalScenesState(
    available: available ?? this.available,
    preset: preset ?? this.preset,
    active: active ?? this.active,
    scenes: clearScenes ? null : (scenes ?? this.scenes),
    busy: busy ?? this.busy,
    error: clearError ? null : (error ?? this.error),
  );
}

final pedalScenesProvider =
    NotifierProvider<PedalScenesNotifier, PedalScenesState>(
      PedalScenesNotifier.new,
    );

/// True when [editor] + [fsMode] mean the pedal handles scenes itself.
bool pedalSceneModeFor(EditorState editor, int? fsMode) =>
    editor.pedalScenesActive && fsMode == Fx200GlobalSettings.fsModeScene;

class PedalScenesNotifier extends Notifier<PedalScenesState> {
  static const Duration _refreshDebounce = Duration(milliseconds: 300);

  Fx200PedalScenesClient? _client;
  Timer? _refreshTimer;

  @override
  PedalScenesState build() {
    ref.onDispose(() => _refreshTimer?.cancel());
    ref.listen<EditorState>(editorProvider, (prev, next) => _onChange());
    ref.listen<int?>(
      deviceSettingsProvider.select((d) => d.global?.fsMode),
      (prev, next) => _onChange(),
    );
    return PedalScenesState(available: _isAvailable());
  }

  bool _isAvailable() {
    final editor = ref.read(editorProvider);
    final sync = ref.read(fx200HardwareSyncProvider);
    return pedalSceneModeFor(
          editor,
          ref.read(deviceSettingsProvider).global?.fsMode,
        ) &&
        (sync.firmwareFeatures?.hasPedalSceneCommand ?? false);
  }

  Fx200PedalScenesClient get _c =>
      _client ??= Fx200PedalScenesClient(ref.read(fx200HardwareSyncProvider));

  /// Any change of the sound may come from a footswitch scene switch (the
  /// pedal then reports all modules): re-read which scene is active.
  void _onChange() {
    final available = _isAvailable();
    if (!available) {
      _refreshTimer?.cancel();
      if (state.available) state = const PedalScenesState();
      return;
    }
    if (!state.available) state = state.copyWith(available: true);
    _refreshTimer?.cancel();
    _refreshTimer = Timer(_refreshDebounce, refresh);
  }

  Future<void> refresh() async {
    if (!state.available || state.busy) return;
    try {
      final info = await _c.info();
      final presetChanged = info.preset != state.preset;
      state = state.copyWith(
        preset: info.preset,
        active: info.active,
        clearScenes: presetChanged,
        clearError: true,
      );
    } on Fx200PedalScenesException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<T?> _run<T>(Future<T> Function() job) async {
    if (!state.available || state.busy) return null;
    state = state.copyWith(busy: true, clearError: true);
    try {
      return await job();
    } on Fx200PedalScenesException catch (e) {
      state = state.copyWith(error: e.message);
      return null;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  /// Switches the pedal to [scene] 0..3, like its footswitch. The pedal
  /// reports the new sound with the module frames.
  Future<void> select(int scene) async {
    final active = await _run(() => _c.select(scene));
    if (active != null) state = state.copyWith(active: active);
  }

  /// Reads the four scenes (for the comparison view).
  Future<void> loadAll() async {
    final info = await _run(_c.info);
    if (info == null) return;
    final scenes = await _run(_c.readAll);
    if (scenes != null) {
      state = state.copyWith(
        preset: info.preset,
        active: info.active,
        scenes: scenes,
      );
    }
  }

  /// Copies scene [from] over scene [to] (the active scene = the sound being
  /// played). Kept in the pedal's RAM until the preset is saved.
  Future<bool> copy(int from, int to) async {
    if (from == to) return false;
    final ok = await _run(() async {
      final source = await _c.read(from);
      await _c.write(to, source.data);
      return true;
    });
    if (ok != true) return false;
    // The preset now has unsaved scene edits on the pedal.
    ref.read(editorProvider.notifier).markEdited();
    if (state.scenes != null) await loadAll();
    return true;
  }

  /// Copies the sound being played into [scene].
  Future<bool> storeCurrentIn(int scene) async {
    final active = state.active;
    if (active == null) {
      await refresh();
    }
    final from = state.active;
    if (from == null) {
      state = state.copyWith(error: tr('The active pedal scene is unknown.'));
      return false;
    }
    return copy(from, scene);
  }
}
