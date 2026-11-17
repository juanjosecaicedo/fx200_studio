import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../data/datasources/preset_remote_datasource.dart';
import '../../data/repositories/preset_repository_impl.dart';
import '../../domain/entities/preset.dart';
import '../../domain/repositories/preset_repository.dart';
import '../../domain/usecases/preset_usecases.dart';
import '../../services/fx200_hardware_sync.dart';
import '../../services/fx200_protocol.dart';
import 'editor_state.dart';

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final presetRemoteDataSourceProvider = Provider<PresetRemoteDataSource>((ref) {
  return PresetRemoteDataSource(client: ref.watch(httpClientProvider));
});

final presetRepositoryProvider = Provider<PresetRepository>((ref) {
  return PresetRepositoryImpl(ref.watch(presetRemoteDataSourceProvider));
});

final getPresetUseCaseProvider = Provider<GetPresetUseCase>(
  (ref) => GetPresetUseCase(ref.watch(presetRepositoryProvider)),
);

final savePresetUseCaseProvider = Provider<SavePresetUseCase>(
  (ref) => SavePresetUseCase(ref.watch(presetRepositoryProvider)),
);

final getModelCatalogUseCaseProvider = Provider<GetModelCatalogUseCase>(
  (ref) => GetModelCatalogUseCase(ref.watch(presetRepositoryProvider)),
);

final fx200HardwareSyncProvider = Provider<Fx200HardwareSync>((ref) {
  final sync = Fx200HardwareSync();
  ref.onDispose(sync.disconnect);
  return sync;
});

final editorProvider = NotifierProvider<EditorNotifier, EditorState>(
  EditorNotifier.new,
);

/// State management controller for the multi-FX editor.
/// Maintains immutable undo/redo history and delegates mutations to usecases.
class EditorNotifier extends Notifier<EditorState> {
  static const int _maxHistory = 40;
  static const UpdateBlockParameterUseCase _updateParamUseCase =
      UpdateBlockParameterUseCase();
  static const ToggleBlockBypassUseCase _toggleBypassUseCase =
      ToggleBlockBypassUseCase();
  static const ReorderBlocksUseCase _reorderBlocksUseCase =
      ReorderBlocksUseCase();

  final Map<int, String> _hardwarePresetNames = <int, String>{};

  @override
  EditorState build() {
    Future<void>.microtask(() => loadPreset(0));
    return const EditorState(
      preset: null,
      selectedBlockId: null,
      catalog: <CatalogModel>[],
      isLoading: true,
    );
  }

  Future<void> loadPreset(int patchNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final preset = await ref.read(getPresetUseCaseProvider)(patchNumber);
      final catalog = await ref.read(getModelCatalogUseCaseProvider)();
      final hwName = _hardwarePresetNames[patchNumber];
      final resolvedPreset = (hwName != null && hwName.isNotEmpty)
          ? preset.copyWith(name: hwName)
          : preset;
      state = state.copyWith(
        preset: resolvedPreset,
        selectedBlockId: resolvedPreset.blocks.isNotEmpty
            ? resolvedPreset.blocks.first.id
            : null,
        catalog: catalog,
        undoStack: const <Preset>[],
        redoStack: const <Preset>[],
        hasUnsavedChanges: false,
        isLoading: false,
      );
      if (state.isHardwareConnected) {
        ref.read(fx200HardwareSyncProvider).requestPreset(patchNumber);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void toggleHardwareConnection() {
    final sync = ref.read(fx200HardwareSyncProvider);
    if (sync.isConnected) {
      sync.disconnect();
      state = state.copyWith(
        isHardwareConnected: false,
        hardwareStatus: 'USB OFFLINE',
      );
      return;
    }

    final result = sync.connect(
      onModuleReceived: _applyHardwareModule,
      onPresetNameReceived: (index, name) {
        _hardwarePresetNames[index] = name;
        final current = state.preset;
        if (current != null && current.patchNumber == index) {
          state = state.copyWith(preset: current.copyWith(name: name));
        }
      },
      onActivePatchReceived: (patch) {
        final current = state.preset;
        if (current != null && current.patchNumber != patch) {
          final hwName = _hardwarePresetNames[patch];
          state = state.copyWith(
            preset: current.copyWith(
              patchNumber: patch,
              name: (hwName != null && hwName.isNotEmpty)
                  ? hwName
                  : current.name,
            ),
          );
        }
      },
    );
    state = state.copyWith(
      isHardwareConnected: result.ok,
      hardwareStatus: result.message,
    );
    if (result.ok) {
      sync.requestPresetList();
      if (state.preset != null) {
        sync.requestPreset(state.preset!.patchNumber);
      }
    }
  }

  void _applyHardwareModule(Fx200ModuleState mod) {
    final current = state.preset;
    if (current == null) return;
    final category = Fx200HardwareSync.categoryForSlot(mod.slotIndex);
    var matched = false;
    final updatedBlocks = current.blocks.map((block) {
      if (block.category != category) return block;
      matched = true;
      final updatedParams = <BlockParameter>[];
      for (var i = 0; i < block.parameters.length; i++) {
        final p = block.parameters[i];
        if (i < mod.params.length) {
          updatedParams.add(p.copyWith(value: mod.params[i].toDouble()));
        } else {
          updatedParams.add(p);
        }
      }
      final updatedModels =
          (mod.modelId >= 1 && mod.modelId <= block.availableModels.length)
          ? block.availableModels[mod.modelId - 1]
          : block.modelName;
      return block.copyWith(
        enabled: mod.enabled,
        modelName: updatedModels,
        parameters: updatedParams,
      );
    }).toList();

    if (matched) {
      state = state.copyWith(preset: current.copyWith(blocks: updatedBlocks));
    }
  }

  Future<void> saveCurrentPreset() async {
    final current = state.preset;
    if (current == null) return;
    await ref.read(savePresetUseCaseProvider)(current);
    state = state.copyWith(hasUnsavedChanges: false);
  }

  void selectBlock(String blockId) {
    state = state.copyWith(selectedBlockId: blockId);
  }

  void toggleBrowser() {
    state = state.copyWith(isBrowserOpen: !state.isBrowserOpen);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategoryFilter(EffectCategory? category) {
    if (category == null) {
      state = state.copyWith(clearCategoryFilter: true);
    } else {
      state = state.copyWith(categoryFilter: category);
    }
  }

  void updateParameter({
    required String blockId,
    required String parameterId,
    required double value,
    bool recordHistory = true,
  }) {
    final current = state.preset;
    if (current == null) return;
    final next = _updateParamUseCase(
      preset: current,
      blockId: blockId,
      parameterId: parameterId,
      value: value,
    );
    _commitPreset(next, recordHistory: recordHistory);
    _syncBlockToHardware(next, blockId, force: recordHistory);
  }

  void toggleBypass(String blockId) {
    final current = state.preset;
    if (current == null) return;
    final next = _toggleBypassUseCase(preset: current, blockId: blockId);
    _commitPreset(next);
    _syncBlockToHardware(next, blockId, force: true);
  }

  void _syncBlockToHardware(
    Preset preset,
    String blockId, {
    bool force = false,
  }) {
    if (!state.isHardwareConnected) return;
    final block = preset.blocks.where((b) => b.id == blockId).firstOrNull;
    if (block != null) {
      ref.read(fx200HardwareSyncProvider).sendBlockUpdate(block, force: force);
    }
  }

  void reorderBlock({
    required String blockId,
    required int targetLane,
    required int targetSlot,
  }) {
    final current = state.preset;
    if (current == null) return;
    final next = _reorderBlocksUseCase(
      preset: current,
      blockId: blockId,
      targetLane: targetLane,
      targetSlot: targetSlot,
    );
    _commitPreset(next);
  }

  void addBlockFromCatalog(
    CatalogModel model, {
    int targetLane = 0,
    int? targetSlot,
  }) {
    final current = state.preset;
    if (current == null) return;
    final laneCount = current.blocks
        .where((b) => b.laneIndex == targetLane)
        .length;
    final newId = 'blk_${DateTime.now().microsecondsSinceEpoch}';
    final newBlock = EffectBlock(
      id: newId,
      category: model.category,
      modelName: model.name,
      availableModels: <String>[model.name],
      enabled: true,
      laneIndex: targetLane,
      slotIndex: targetSlot ?? laneCount,
      parameters: model.defaultParameters,
    );
    final updated = current.copyWith(
      blocks: <EffectBlock>[...current.blocks, newBlock],
    );
    final reindexed = targetSlot == null
        ? updated
        : _reorderBlocksUseCase(
            preset: updated,
            blockId: newId,
            targetLane: targetLane,
            targetSlot: targetSlot,
          );
    _commitPreset(reindexed);
    state = state.copyWith(selectedBlockId: newId);
  }

  void removeBlock(String blockId) {
    final current = state.preset;
    if (current == null) return;
    final remaining = current.blocks.where((b) => b.id != blockId).toList();
    _commitPreset(current.copyWith(blocks: remaining));
    if (state.selectedBlockId == blockId) {
      state = state.copyWith(
        selectedBlockId: remaining.isNotEmpty ? remaining.first.id : null,
        clearSelectedBlock: remaining.isEmpty,
      );
    }
  }

  void changeBlockModel(String blockId, String modelName) {
    final current = state.preset;
    if (current == null) return;
    final updated = current.blocks.map((b) {
      if (b.id != blockId) return b;
      return b.copyWith(modelName: modelName);
    }).toList();
    final next = current.copyWith(blocks: updated);
    _commitPreset(next);
    _syncBlockToHardware(next, blockId, force: true);
  }

  void changeBlockMode(String blockId, String mode) {
    final current = state.preset;
    if (current == null) return;
    final updated = current.blocks.map((b) {
      if (b.id != blockId) return b;
      return b.copyWith(mode: mode);
    }).toList();
    _commitPreset(current.copyWith(blocks: updated));
  }

  void renamePreset(String name) {
    final current = state.preset;
    if (current == null || name.trim().isEmpty) return;
    _commitPreset(current.copyWith(name: name.trim()));
  }

  void selectScene(String scene) {
    final current = state.preset;
    if (current == null) return;
    _commitPreset(current.copyWith(activeScene: scene));
  }

  void toggleParallelSplit() {
    final current = state.preset;
    if (current == null) return;
    _commitPreset(
      current.copyWith(parallelSplitEnabled: !current.parallelSplitEnabled),
    );
  }

  void setBpm(double bpm) {
    final current = state.preset;
    if (current == null) return;
    _commitPreset(current.copyWith(bpm: bpm.clamp(40.0, 240.0)));
  }

  void setOutputLevelDb(double db) {
    final current = state.preset;
    if (current == null) return;
    _commitPreset(current.copyWith(outputLevelDb: db.clamp(-60.0, 12.0)));
  }

  void undo() {
    if (!state.canUndo || state.preset == null) return;
    final prev = state.undoStack.last;
    final newUndo = state.undoStack.sublist(0, state.undoStack.length - 1);
    final newRedo = <Preset>[...state.redoStack, state.preset!];
    state = state.copyWith(
      preset: prev,
      undoStack: newUndo,
      redoStack: newRedo,
      hasUnsavedChanges: true,
    );
  }

  void redo() {
    if (!state.canRedo || state.preset == null) return;
    final next = state.redoStack.last;
    final newRedo = state.redoStack.sublist(0, state.redoStack.length - 1);
    final newUndo = <Preset>[...state.undoStack, state.preset!];
    state = state.copyWith(
      preset: next,
      undoStack: newUndo,
      redoStack: newRedo,
      hasUnsavedChanges: true,
    );
  }

  void _commitPreset(Preset next, {bool recordHistory = true}) {
    final current = state.preset;
    if (current == null) return;
    if (!recordHistory) {
      state = state.copyWith(preset: next, hasUnsavedChanges: true);
      return;
    }
    final history = <Preset>[...state.undoStack, current];
    if (history.length > _maxHistory) {
      history.removeAt(0);
    }
    state = state.copyWith(
      preset: next,
      undoStack: history,
      redoStack: const <Preset>[],
      hasUnsavedChanges: true,
    );
  }
}
