import 'preset.dart';

/// State of one module inside a scene: on/off, model and raw parameter
/// values (same order as the pedal's `0x91..0x9A` frames).
class SceneBlockState {
  const SceneBlockState({
    required this.enabled,
    required this.modelName,
    required this.values,
  });

  final bool enabled;
  final String modelName;
  final List<double> values;

  factory SceneBlockState.of(EffectBlock b) => SceneBlockState(
    enabled: b.enabled,
    modelName: b.modelName,
    values: List<double>.unmodifiable(b.parameters.map((p) => p.value)),
  );

  bool matches(EffectBlock b) {
    if (b.enabled != enabled || b.modelName != modelName) return false;
    if (b.parameters.length != values.length) return false;
    for (var i = 0; i < values.length; i++) {
      if (b.parameters[i].value != values[i]) return false;
    }
    return true;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'enabled': enabled,
    'model': modelName,
    'values': values,
  };

  factory SceneBlockState.fromJson(Map<String, Object?> j) => SceneBlockState(
    enabled: j['enabled'] as bool? ?? true,
    modelName: j['model'] as String? ?? '',
    values: List<double>.unmodifiable(
      (j['values'] as List? ?? const <Object?>[]).map(
        (v) => (v as num).toDouble(),
      ),
    ),
  );
}

/// A scene: a snapshot of every module of a preset (the chain order is
/// shared by the four scenes of a preset).
class Scene {
  const Scene(this.blocks);

  /// Module state by category (FX, DRIVE, AMP, ...).
  final Map<EffectCategory, SceneBlockState> blocks;

  factory Scene.capture(Preset p) => Scene(
    Map<EffectCategory, SceneBlockState>.unmodifiable(
      <EffectCategory, SceneBlockState>{
        for (final b in p.blocks) b.category: SceneBlockState.of(b),
      },
    ),
  );

  /// True when [p] sounds exactly like this scene.
  bool matches(Preset p) {
    for (final b in p.blocks) {
      final s = blocks[b.category];
      if (s != null && !s.matches(b)) return false;
    }
    return true;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    for (final e in blocks.entries) e.key.name: e.value.toJson(),
  };

  factory Scene.fromJson(Map<String, Object?> j) => Scene(
    Map<EffectCategory, SceneBlockState>.unmodifiable(
      <EffectCategory, SceneBlockState>{
        for (final c in EffectCategory.values)
          if (j[c.name] is Map)
            c: SceneBlockState.fromJson(
              (j[c.name] as Map).cast<String, Object?>(),
            ),
      },
    ),
  );
}
