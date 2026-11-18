import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/fx200_models.dart';
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
  Timer? _autoConnectTimer;
  bool _manualDisconnect = false;

  @override
  EditorState build() {
    ref.onDispose(() {
      _autoConnectTimer?.cancel();
      _autoConnectTimer = null;
    });
    Future<void>.microtask(() async {
      await loadPreset(0);
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        await _tryAutoConnect();
      }
    });
    return const EditorState(
      preset: null,
      selectedBlockId: null,
      catalog: <CatalogModel>[],
      isLoading: true,
    );
  }

  Future<void> _tryAutoConnect() async {
    if (_manualDisconnect ||
        state.isHardwareConnected ||
        state.isConnectingHardware) {
      return;
    }
    await _connectHardware(silentOnFail: true);
    if (!state.isHardwareConnected && !_manualDisconnect) {
      _autoConnectTimer?.cancel();
      _autoConnectTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
        if (_manualDisconnect || state.isHardwareConnected) {
          _autoConnectTimer?.cancel();
          return;
        }
        await _connectHardware(silentOnFail: true);
      });
    }
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

  Future<void> toggleHardwareConnection() async {
    final sync = ref.read(fx200HardwareSyncProvider);
    if (sync.isConnected) {
      _manualDisconnect = true;
      _autoConnectTimer?.cancel();
      sync.disconnect();
      state = state.copyWith(
        isHardwareConnected: false,
        isConnectingHardware: false,
        isSyncingPresets: false,
        hardwareStatus: 'USB OFFLINE',
      );
      return;
    }
    _manualDisconnect = false;
    await _connectHardware(silentOnFail: false);
  }

  Future<void> _connectHardware({required bool silentOnFail}) async {
    final sync = ref.read(fx200HardwareSyncProvider);
    if (sync.isConnected || state.isConnectingHardware) return;

    if (!silentOnFail) {
      state = state.copyWith(
        isConnectingHardware: true,
        hardwareStatus: 'CONNECTING...',
      );
    }

    final result = await sync.connect(
      onModuleReceived: _applyHardwareModule,
      onPresetNamesReceived: (names) {
        _hardwarePresetNames.addAll(names);
        final current = state.preset;
        final updatedName = current != null
            ? _hardwarePresetNames[current.patchNumber]
            : null;
        final syncedCount = _hardwarePresetNames.length;
        // The names are complete slightly before the 0xE0 dump ends; the
        // sync only counts as finished when the dump closes.
        final done = syncedCount >= 200 && !sync.isDumping;
        state = state.copyWith(
          presetNames: Map<int, String>.unmodifiable(_hardwarePresetNames),
          isSyncingPresets: !done,
          hardwareStatus: done
              ? 'FX200 LIVE (IF 3)'
              : 'SYNCING $syncedCount/200',
          preset:
              (current != null && updatedName != null && updatedName.isNotEmpty)
              ? current.copyWith(name: updatedName)
              : null,
        );
      },
      onPresetSyncComplete: () {
        if (!state.isHardwareConnected) return;
        state = state.copyWith(
          isSyncingPresets: false,
          hardwareStatus: 'FX200 LIVE (IF 3)',
        );
      },
      onActivePatchReceived: (patch) {
        final current = state.preset;
        if (current != null && current.patchNumber != patch) {
          final hwName = _hardwarePresetNames[patch];
          // Changed on the pedal (footswitch / knob): follow it, never
          // answer with a select. Undo history belongs to the old patch.
          state = state.copyWith(
            hasUnsavedChanges: false,
            undoStack: const <Preset>[],
            redoStack: const <Preset>[],
            preset: current.copyWith(
              patchNumber: patch,
              name: (hwName != null && hwName.isNotEmpty)
                  ? hwName
                  : Fx200Models.defaultPresetName(patch),
            ),
          );
        }
      },
      onChainOrderReceived: _applyHardwareChainOrder,
      onOutputLevelReceived: (db) {
        final current = state.preset;
        if (current != null) {
          state = state.copyWith(preset: current.copyWith(outputLevelDb: db));
        }
      },
      onBpmReceived: (bpm) {
        final current = state.preset;
        if (current != null) {
          state = state.copyWith(
            preset: current.copyWith(bpm: bpm.clamp(40.0, 260.0)),
          );
        }
      },
    );

    if (result.ok) {
      _autoConnectTimer?.cancel();
      state = state.copyWith(
        isHardwareConnected: true,
        isConnectingHardware: false,
        isSyncingPresets: true,
        hardwareStatus: 'SYNCING PRESETS...',
      );
      // Only read: the 0xE0 dump ends with the pedal's own active patch
      // (`A6 [patch]`) and its module frames, which onActivePatchReceived /
      // _applyHardwareModule adopt. Sending `A6` here would switch the pedal
      // to whatever the app opened locally (patch 0 = 01A), and because the
      // pedal queues it behind the ~27 s dump it lands late, overriding
      // footswitch changes made in the meantime.
      sync.requestPresetList();
    } else {
      state = state.copyWith(
        isHardwareConnected: false,
        isConnectingHardware: false,
        isSyncingPresets: false,
        hardwareStatus: silentOnFail ? 'WAITING FX200 USB...' : result.message,
      );
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
      final updatedModels =
          (mod.modelId >= 1 && mod.modelId <= block.availableModels.length)
          ? block.availableModels[mod.modelId - 1]
          : block.modelName;
      final template =
          Fx200Models.parametersForModel(block.category, updatedModels) ??
          block.parameters;
      final updatedParams = <BlockParameter>[];
      for (var i = 0; i < mod.params.length; i++) {
        final hwVal = mod.params[i].toDouble();
        if (i < template.length) {
          final p = template[i];
          updatedParams.add(
            (hwVal > p.max ? p.withMax(hwVal) : p).copyWith(value: hwVal),
          );
        } else {
          // Word the current model does not use: keep it so it is written
          // back unchanged, but do not show it.
          updatedParams.add(
            BlockParameter(
              id: 'p$i',
              label: 'RESERVED',
              value: hwVal,
              defaultValue: hwVal,
              max: 65535,
              kind: BlockParameterKind.reserved,
            ),
          );
        }
      }
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

  void _applyHardwareChainOrder(
    List<int> order1Based,
    List<bool> enabledStates,
  ) {
    final current = state.preset;
    if (current == null) return;
    final slotPositionByCategory = <EffectCategory, int>{};
    for (var pos = 0; pos < order1Based.length; pos++) {
      final hwSlot = order1Based[pos] - 1;
      final cat = Fx200HardwareSync.categoryForSlot(hwSlot);
      slotPositionByCategory[cat] = pos;
    }
    final updatedBlocks = current.blocks.map((block) {
      final hwSlot = Fx200HardwareSync.slotForCategory(block.category);
      final nextPos = slotPositionByCategory[block.category] ?? block.slotIndex;
      final nextEnabled = hwSlot < enabledStates.length
          ? enabledStates[hwSlot]
          : block.enabled;
      return block.copyWith(
        laneIndex: 0,
        slotIndex: nextPos,
        enabled: nextEnabled,
      );
    }).toList();
    state = state.copyWith(preset: current.copyWith(blocks: updatedBlocks));
  }

  Future<void> saveCurrentPreset() async {
    final current = state.preset;
    if (current == null) return;
    final trimmed = current.name.trim();
    final resolvedName = trimmed.isNotEmpty
        ? (trimmed.length > 15 ? trimmed.substring(0, 15) : trimmed)
        : Fx200Models.defaultPresetName(current.patchNumber);
    final toSave = current.copyWith(name: resolvedName);
    await ref.read(savePresetUseCaseProvider)(toSave);
    _hardwarePresetNames[toSave.patchNumber] = resolvedName;
    if (state.isHardwareConnected) {
      final sync = ref.read(fx200HardwareSyncProvider);
      sync.sendChainOrder(toSave.blocks);
      sync.sendPresetSave(toSave.patchNumber, resolvedName);
    }
    state = state.copyWith(
      preset: toSave,
      hasUnsavedChanges: false,
      presetNames: Map<int, String>.unmodifiable(_hardwarePresetNames),
    );
  }

  /// Applies preset names written by copy/paste/move operations.
  void applyPresetNames(Map<int, String> names) {
    if (names.isEmpty) return;
    _hardwarePresetNames.addAll(names);
    final current = state.preset;
    final renamed = current != null ? names[current.patchNumber] : null;
    state = state.copyWith(
      presetNames: Map<int, String>.unmodifiable(_hardwarePresetNames),
      preset: renamed != null ? current!.copyWith(name: renamed) : null,
    );
  }

  void togglePresetSidebar() {
    state = state.copyWith(isPresetSidebarOpen: !state.isPresetSidebarOpen);
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
    if (state.isHardwareConnected) {
      ref.read(fx200HardwareSyncProvider).sendChainOrder(next.blocks);
    }
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
      // Models with their own layout (EQ) start from that model's defaults,
      // like the pedal does when the model is changed on its screen.
      final template = b.modelName == modelName
          ? null
          : Fx200Models.parametersForModel(b.category, modelName);
      return b.copyWith(modelName: modelName, parameters: template);
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
    if (current == null) return;
    final capped = name.length > 15 ? name.substring(0, 15) : name;
    _commitPreset(current.copyWith(name: capped), recordHistory: false);
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
    final clampedBpm = bpm.clamp(40.0, 260.0).roundToDouble();
    final delayMs = (60000.0 / clampedBpm).roundToDouble().clamp(20.0, 2000.0);
    String? delayBlockId;
    final updatedBlocks = current.blocks.map((block) {
      if (block.category != EffectCategory.delay || block.parameters.isEmpty) {
        return block;
      }
      delayBlockId = block.id;
      final params = List<BlockParameter>.from(block.parameters);
      params[0] = params[0].copyWith(value: delayMs);
      return block.copyWith(parameters: params);
    }).toList();
    final next = current.copyWith(bpm: clampedBpm, blocks: updatedBlocks);
    _commitPreset(next);
    if (state.isHardwareConnected) {
      ref.read(fx200HardwareSyncProvider).sendTapTempoBpm(clampedBpm);
      if (delayBlockId != null) {
        _syncBlockToHardware(next, delayBlockId!, force: true);
      }
    }
  }

  void setOutputLevelDb(double db) {
    final current = state.preset;
    if (current == null) return;
    final clamped = db.clamp(-60.0, 6.0);
    _commitPreset(current.copyWith(outputLevelDb: clamped));
    if (state.isHardwareConnected) {
      ref.read(fx200HardwareSyncProvider).sendOutputLevelDb(clamped);
    }
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
