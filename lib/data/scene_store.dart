import 'dart:convert';
import 'dart:io';

import '../core/app_dirs.dart';
import '../domain/entities/preset.dart';
import '../domain/entities/scene.dart';

/// Scenes of one preset slot as stored on this computer.
class PresetScenes {
  const PresetScenes({
    this.presetName = '',
    this.scenes = const <String, Scene>{},
    this.active,
  });

  /// Name of the preset when the scenes were saved (warns if the slot was
  /// later overwritten by another preset).
  final String presetName;
  final Map<String, Scene> scenes;

  /// Scene that was active when the preset was saved: the pedal's own
  /// preset holds that scene's sound.
  final String? active;

  PresetScenes copyWith({
    String? presetName,
    Map<String, Scene>? scenes,
    String? active,
  }) => PresetScenes(
    presetName: presetName ?? this.presetName,
    scenes: scenes ?? this.scenes,
    active: active ?? this.active,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'presetName': presetName,
    if (active != null) 'active': active,
    'scenes': <String, Object?>{
      for (final e in scenes.entries) e.key: e.value.toJson(),
    },
  };

  factory PresetScenes.fromJson(Map<String, Object?> j) => PresetScenes(
    presetName: j['presetName'] as String? ?? '',
    active: j['active'] as String?,
    scenes: <String, Scene>{
      for (final e
          in ((j['scenes'] as Map?) ?? const <String, Object?>{}).entries)
        if (e.value is Map)
          '${e.key}': Scene.fromJson((e.value as Map).cast<String, Object?>()),
    },
  );
}

/// App-side scene storage (`~/.config/fx200_studio/scenes.json`), keyed by
/// preset slot. Used until a custom firmware stores scenes on the pedal.
///
/// Two copies are kept: what is saved on disk, and the working copy being
/// edited. Like the preset itself, scene edits only reach the disk when the
/// preset is saved ([commit]); leaving the preset without saving discards
/// them ([revert]).
class SceneStore {
  SceneStore({File? file}) : _file = file ?? _defaultFile();

  final File? _file;

  Map<int, PresetScenes>? _savedCache;
  Map<int, PresetScenes>? _workCache;
  Map<int, String>? _activeCache;

  /// Scenes as saved on disk.
  Map<int, PresetScenes> get saved => _savedCache ??= readAll();

  /// Working copy of every slot (includes unsaved scene edits).
  Map<int, PresetScenes> get all =>
      _workCache ??= Map<int, PresetScenes>.of(saved);

  /// Active scene per slot (working copy).
  Map<int, String> get activeByPatch => _activeCache ??= <int, String>{
    for (final e in saved.entries)
      if (e.value.active != null) e.key: e.value.active!,
  };

  /// Discards the unsaved scene edits of [patch].
  void revert(int patch) {
    final s = saved[patch];
    if (s == null) {
      all.remove(patch);
      activeByPatch.remove(patch);
    } else {
      all[patch] = s;
      if (s.active != null) {
        activeByPatch[patch] = s.active!;
      } else {
        activeByPatch.remove(patch);
      }
    }
  }

  /// The preset [p] was saved: its active scene takes the saved sound and
  /// the scenes of that slot are written to disk.
  void commit(Preset p) {
    final active = activeByPatch[p.patchNumber];
    final entry = all[p.patchNumber];
    if (entry == null && active == null) return;
    final base = entry ?? const PresetScenes();
    all[p.patchNumber] = PresetScenes(
      presetName: p.name,
      active: active,
      scenes: <String, Scene>{...base.scenes, ?active: Scene.capture(p)},
    );
    _writeSlot(p.patchNumber, all[p.patchNumber]);
  }

  /// Writes one scene of [patch] straight to disk (explicit "save in scene"
  /// / "clear scene"), without saving the other unsaved scene edits.
  void persistScene(int patch, String name, Scene? scene, String presetName) {
    final base = saved[patch] ?? const PresetScenes();
    final scenes = <String, Scene>{...base.scenes};
    if (scene == null) {
      scenes.remove(name);
    } else {
      scenes[name] = scene;
    }
    _writeSlot(
      patch,
      PresetScenes(
        presetName: scene == null ? base.presetName : presetName,
        active: base.active == name && scene == null ? null : base.active,
        scenes: scenes,
      ),
    );
  }

  void _writeSlot(int patch, PresetScenes? entry) {
    final next = Map<int, PresetScenes>.of(saved);
    if (entry == null || entry.scenes.isEmpty) {
      next.remove(patch);
    } else {
      next[patch] = entry;
    }
    _savedCache = next;
    writeAll(next);
  }

  static File? _defaultFile() {
    // Tests never touch the user's real scenes.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    return fx200SettingsFile('scenes.json');
  }

  Map<int, PresetScenes> readAll() {
    try {
      final f = _file;
      if (f == null || !f.existsSync()) return <int, PresetScenes>{};
      final json = jsonDecode(f.readAsStringSync());
      if (json is! Map) return <int, PresetScenes>{};
      return <int, PresetScenes>{
        for (final e in json.entries)
          if (int.tryParse('${e.key}') != null && e.value is Map)
            int.parse('${e.key}'): PresetScenes.fromJson(
              (e.value as Map).cast<String, Object?>(),
            ),
      };
    } catch (_) {
      return <int, PresetScenes>{};
    }
  }

  void writeAll(Map<int, PresetScenes> all) {
    final f = _file;
    if (f == null) return;
    try {
      f.parent.createSync(recursive: true);
      f.writeAsStringSync(
        const JsonEncoder.withIndent(' ').convert(<String, Object?>{
          for (final e in all.entries)
            if (e.value.scenes.isNotEmpty) '${e.key}': e.value.toJson(),
        }),
      );
    } catch (_) {
      // Not fatal: the scenes stay for this session.
    }
  }
}
