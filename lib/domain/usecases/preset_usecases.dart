import '../entities/preset.dart';
import '../repositories/preset_repository.dart';

class GetPresetUseCase {
  const GetPresetUseCase(this._repository);

  final PresetRepository _repository;

  Future<Preset> call(int patchNumber) => _repository.getPreset(patchNumber);
}

class SavePresetUseCase {
  const SavePresetUseCase(this._repository);

  final PresetRepository _repository;

  Future<void> call(Preset preset) => _repository.savePreset(preset);
}

class GetModelCatalogUseCase {
  const GetModelCatalogUseCase(this._repository);

  final PresetRepository _repository;

  Future<List<CatalogModel>> call() => _repository.getModelCatalog();
}

class UpdateBlockParameterUseCase {
  const UpdateBlockParameterUseCase();

  Preset call({
    required Preset preset,
    required String blockId,
    required String parameterId,
    required double value,
  }) {
    final updatedBlocks = preset.blocks.map((block) {
      if (block.id != blockId) return block;
      final updatedParams = block.parameters.map((param) {
        if (param.id != parameterId) return param;
        return param.copyWith(value: value);
      }).toList();
      return block.copyWith(parameters: updatedParams);
    }).toList();

    return preset.copyWith(blocks: updatedBlocks);
  }
}

class ToggleBlockBypassUseCase {
  const ToggleBlockBypassUseCase();

  Preset call({required Preset preset, required String blockId}) {
    final updatedBlocks = preset.blocks.map((block) {
      if (block.id != blockId) return block;
      return block.copyWith(enabled: !block.enabled);
    }).toList();
    return preset.copyWith(blocks: updatedBlocks);
  }
}

class ReorderBlocksUseCase {
  const ReorderBlocksUseCase();

  Preset call({
    required Preset preset,
    required String blockId,
    required int targetLane,
    required int targetSlot,
  }) {
    final moving = preset.blocks.where((b) => b.id == blockId).firstOrNull;
    if (moving == null) return preset;

    final remaining = preset.blocks.where((b) => b.id != blockId).toList();
    final laneBlocks =
        remaining.where((b) => b.laneIndex == targetLane).toList()
          ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));

    final clampedSlot = targetSlot.clamp(0, laneBlocks.length);
    laneBlocks.insert(
      clampedSlot,
      moving.copyWith(laneIndex: targetLane, slotIndex: clampedSlot),
    );

    final reindexedTarget = <EffectBlock>[
      for (var i = 0; i < laneBlocks.length; i++)
        laneBlocks[i].copyWith(slotIndex: i),
    ];

    final otherLane = targetLane == 0 ? 1 : 0;
    final otherBlocks =
        remaining.where((b) => b.laneIndex == otherLane).toList()
          ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    final reindexedOther = <EffectBlock>[
      for (var i = 0; i < otherBlocks.length; i++)
        otherBlocks[i].copyWith(slotIndex: i),
    ];

    return preset.copyWith(
      blocks: <EffectBlock>[...reindexedTarget, ...reindexedOther],
    );
  }
}
