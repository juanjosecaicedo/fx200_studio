/// Effect block categories styled with dedicated hardware accents.
enum EffectCategory {
  gate,
  compressor,
  drive,
  amp,
  cab,
  eq,
  modulation,
  delay,
  reverb,
  volume,
}

/// Control presentation kind for block parameters.
enum BlockParameterKind {
  knob,
  slider,
  toggle,
  mode,
}

/// Immutable parameter definition and current value inside an [EffectBlock].
class BlockParameter {
  const BlockParameter({
    required this.id,
    required this.label,
    required this.value,
    required this.defaultValue,
    this.min = 0.0,
    this.max = 100.0,
    this.unit = '',
    this.kind = BlockParameterKind.knob,
    this.options = const <String>[],
  });

  final String id;
  final String label;
  final double value;
  final double defaultValue;
  final double min;
  final double max;
  final String unit;
  final BlockParameterKind kind;
  final List<String> options;

  BlockParameter copyWith({double? value}) {
    return BlockParameter(
      id: id,
      label: label,
      value: (value ?? this.value).clamp(min, max),
      defaultValue: defaultValue,
      min: min,
      max: max,
      unit: unit,
      kind: kind,
      options: options,
    );
  }
}

/// Immutable DSP effect block placed on a signal lane.
class EffectBlock {
  const EffectBlock({
    required this.id,
    required this.category,
    required this.modelName,
    required this.availableModels,
    required this.enabled,
    required this.laneIndex,
    required this.slotIndex,
    required this.parameters,
    this.mode = 'Mono',
  });

  final String id;
  final EffectCategory category;
  final String modelName;
  final List<String> availableModels;
  final bool enabled;
  final int laneIndex; // 0 = Main Lane A, 1 = Parallel Lane B
  final int slotIndex;
  final List<BlockParameter> parameters;
  final String mode;

  EffectBlock copyWith({
    String? modelName,
    bool? enabled,
    int? laneIndex,
    int? slotIndex,
    List<BlockParameter>? parameters,
    String? mode,
  }) {
    return EffectBlock(
      id: id,
      category: category,
      modelName: modelName ?? this.modelName,
      availableModels: availableModels,
      enabled: enabled ?? this.enabled,
      laneIndex: laneIndex ?? this.laneIndex,
      slotIndex: slotIndex ?? this.slotIndex,
      parameters: parameters ?? this.parameters,
      mode: mode ?? this.mode,
    );
  }
}

/// Catalog entry shown in the collapsible model browser.
class CatalogModel {
  const CatalogModel({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.defaultParameters,
  });

  final String id;
  final String name;
  final EffectCategory category;
  final String description;
  final List<BlockParameter> defaultParameters;
}

/// Immutable preset entity containing blocks, scenes (A-H), and global settings.
class Preset {
  const Preset({
    required this.id,
    required this.patchNumber,
    required this.name,
    required this.activeScene,
    required this.bpm,
    required this.outputLevelDb,
    required this.parallelSplitEnabled,
    required this.blocks,
  });

  final String id;
  final int patchNumber;
  final String name;
  final String activeScene; // 'A'..'H'
  final double bpm;
  final double outputLevelDb;
  final bool parallelSplitEnabled;
  final List<EffectBlock> blocks;

  Preset copyWith({
    int? patchNumber,
    String? name,
    String? activeScene,
    double? bpm,
    double? outputLevelDb,
    bool? parallelSplitEnabled,
    List<EffectBlock>? blocks,
  }) {
    return Preset(
      id: id,
      patchNumber: patchNumber ?? this.patchNumber,
      name: name ?? this.name,
      activeScene: activeScene ?? this.activeScene,
      bpm: bpm ?? this.bpm,
      outputLevelDb: outputLevelDb ?? this.outputLevelDb,
      parallelSplitEnabled: parallelSplitEnabled ?? this.parallelSplitEnabled,
      blocks: blocks ?? this.blocks,
    );
  }
}
