import 'dart:convert';
import 'dart:io';

import '../domain/entities/scene.dart';

/// Scenes of one preset slot as stored on this computer.
class PresetScenes {
  const PresetScenes({
    this.presetName = '',
    this.scenes = const <String, Scene>{},
  });

  /// Name of the preset when the scenes were saved (warns if the slot was
  /// later overwritten by another preset).
  final String presetName;
  final Map<String, Scene> scenes;

  PresetScenes copyWith({String? presetName, Map<String, Scene>? scenes}) =>
      PresetScenes(
        presetName: presetName ?? this.presetName,
        scenes: scenes ?? this.scenes,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'presetName': presetName,
    'scenes': <String, Object?>{
      for (final e in scenes.entries) e.key: e.value.toJson(),
    },
  };

  factory PresetScenes.fromJson(Map<String, Object?> j) => PresetScenes(
    presetName: j['presetName'] as String? ?? '',
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
class SceneStore {
  SceneStore({File? file}) : _file = file ?? _defaultFile();

  final File? _file;

  Map<int, PresetScenes>? _cache;

  /// Scenes of every slot (read once, then kept in memory).
  Map<int, PresetScenes> get all => _cache ??= readAll();

  /// Scene last selected per slot in this session.
  final Map<int, String> activeByPatch = <int, String>{};

  /// Writes the in-memory scenes to disk.
  void flush() => writeAll(all);

  static File? _defaultFile() {
    // Tests never touch the user's real scenes.
    if (Platform.environment.containsKey('FLUTTER_TEST')) return null;
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) return null;
    final sep = Platform.pathSeparator;
    return File('$home$sep.config${sep}fx200_studio${sep}scenes.json');
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
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert(<String, Object?>{
        for (final e in all.entries)
          if (e.value.scenes.isNotEmpty) '${e.key}': e.value.toJson(),
      }),
    );
  }
}
