import '../../domain/entities/preset.dart';

/// Serializable DTO for [BlockParameter]. Only handles JSON conversion.
class BlockParameterModel {
  const BlockParameterModel({
    required this.id,
    required this.label,
    required this.value,
    required this.defaultValue,
    required this.min,
    required this.max,
    required this.unit,
    required this.kind,
    required this.options,
  });

  final String id;
  final String label;
  final double value;
  final double defaultValue;
  final double min;
  final double max;
  final String unit;
  final String kind;
  final List<String> options;

  factory BlockParameterModel.fromJson(Map<String, dynamic> json) {
    return BlockParameterModel(
      id: json['id'] as String,
      label: json['label'] as String,
      value: (json['value'] as num).toDouble(),
      defaultValue: (json['defaultValue'] as num).toDouble(),
      min: (json['min'] as num?)?.toDouble() ?? 0.0,
      max: (json['max'] as num?)?.toDouble() ?? 100.0,
      unit: json['unit'] as String? ?? '',
      kind: json['kind'] as String? ?? 'knob',
      options: (json['options'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'value': value,
    'defaultValue': defaultValue,
    'min': min,
    'max': max,
    'unit': unit,
    'kind': kind,
    'options': options,
  };

  BlockParameter toEntity() {
    return BlockParameter(
      id: id,
      label: label,
      value: value,
      defaultValue: defaultValue,
      min: min,
      max: max,
      unit: unit,
      kind: BlockParameterKind.values.firstWhere(
        (k) => k.name == kind,
        orElse: () => BlockParameterKind.knob,
      ),
      options: options,
    );
  }

  factory BlockParameterModel.fromEntity(BlockParameter entity) {
    return BlockParameterModel(
      id: entity.id,
      label: entity.label,
      value: entity.value,
      defaultValue: entity.defaultValue,
      min: entity.min,
      max: entity.max,
      unit: entity.unit,
      kind: entity.kind.name,
      options: entity.options,
    );
  }
}

/// Serializable DTO for [EffectBlock]. Only handles JSON conversion.
class EffectBlockModel {
  const EffectBlockModel({
    required this.id,
    required this.category,
    required this.modelName,
    required this.availableModels,
    required this.enabled,
    required this.laneIndex,
    required this.slotIndex,
    required this.parameters,
    required this.mode,
  });

  final String id;
  final String category;
  final String modelName;
  final List<String> availableModels;
  final bool enabled;
  final int laneIndex;
  final int slotIndex;
  final List<BlockParameterModel> parameters;
  final String mode;

  factory EffectBlockModel.fromJson(Map<String, dynamic> json) {
    return EffectBlockModel(
      id: json['id'] as String,
      category: json['category'] as String,
      modelName: json['modelName'] as String,
      availableModels:
          (json['availableModels'] as List<dynamic>? ?? const <dynamic>[])
              .map((e) => e.toString())
              .toList(),
      enabled: json['enabled'] as bool? ?? true,
      laneIndex: json['laneIndex'] as int? ?? 0,
      slotIndex: json['slotIndex'] as int? ?? 0,
      parameters: (json['parameters'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => BlockParameterModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      mode: json['mode'] as String? ?? 'Mono',
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'category': category,
    'modelName': modelName,
    'availableModels': availableModels,
    'enabled': enabled,
    'laneIndex': laneIndex,
    'slotIndex': slotIndex,
    'parameters': parameters.map((p) => p.toJson()).toList(),
    'mode': mode,
  };

  EffectBlock toEntity() {
    return EffectBlock(
      id: id,
      category: EffectCategory.values.firstWhere(
        (c) => c.name == category,
        orElse: () => EffectCategory.amp,
      ),
      modelName: modelName,
      availableModels: availableModels,
      enabled: enabled,
      laneIndex: laneIndex,
      slotIndex: slotIndex,
      parameters: parameters.map((p) => p.toEntity()).toList(),
      mode: mode,
    );
  }

  factory EffectBlockModel.fromEntity(EffectBlock entity) {
    return EffectBlockModel(
      id: entity.id,
      category: entity.category.name,
      modelName: entity.modelName,
      availableModels: entity.availableModels,
      enabled: entity.enabled,
      laneIndex: entity.laneIndex,
      slotIndex: entity.slotIndex,
      parameters: entity.parameters
          .map(BlockParameterModel.fromEntity)
          .toList(),
      mode: entity.mode,
    );
  }
}

/// Serializable DTO for [Preset]. Only handles JSON conversion.
class PresetModel {
  const PresetModel({
    required this.id,
    required this.patchNumber,
    required this.name,
    required this.activeScene,
    required this.bpm,
    required this.outputLevelDb,
    required this.blocks,
  });

  final String id;
  final int patchNumber;
  final String name;
  final String activeScene;
  final double bpm;
  final double outputLevelDb;
  final List<EffectBlockModel> blocks;

  factory PresetModel.fromJson(Map<String, dynamic> json) {
    return PresetModel(
      id: json['id'] as String,
      patchNumber: json['patchNumber'] as int,
      name: json['name'] as String,
      activeScene: json['activeScene'] as String? ?? 'A',
      bpm: (json['bpm'] as num?)?.toDouble() ?? 120.0,
      outputLevelDb: (json['outputLevelDb'] as num?)?.toDouble() ?? 0.0,
      blocks: (json['blocks'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => EffectBlockModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'patchNumber': patchNumber,
    'name': name,
    'activeScene': activeScene,
    'bpm': bpm,
    'outputLevelDb': outputLevelDb,
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };

  Preset toEntity() {
    return Preset(
      id: id,
      patchNumber: patchNumber,
      name: name,
      activeScene: activeScene,
      bpm: bpm,
      outputLevelDb: outputLevelDb,
      blocks: blocks.map((b) => b.toEntity()).toList(),
    );
  }

  factory PresetModel.fromEntity(Preset entity) {
    return PresetModel(
      id: entity.id,
      patchNumber: entity.patchNumber,
      name: entity.name,
      activeScene: entity.activeScene,
      bpm: entity.bpm,
      outputLevelDb: entity.outputLevelDb,
      blocks: entity.blocks.map(EffectBlockModel.fromEntity).toList(),
    );
  }
}
