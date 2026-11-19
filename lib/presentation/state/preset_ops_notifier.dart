import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/fx200_backup.dart';
import '../../services/fx200_pfl.dart';
import '../../services/fx200_preset_ops.dart';
import 'editor_notifier.dart';
import '../../core/l10n/l10n.dart';

class PresetOpsState {
  const PresetOpsState({
    this.clipboard,
    this.isBusy = false,
    this.progress = 0,
    this.message,
    this.isError = false,
  });

  /// Preset copied with COPY, ready to paste into any slot.
  final Fx200PresetSnapshot? clipboard;
  final bool isBusy;
  final double progress;
  final String? message;
  final bool isError;

  PresetOpsState copyWith({
    Fx200PresetSnapshot? clipboard,
    bool? isBusy,
    double? progress,
    String? message,
    bool clearMessage = false,
    bool? isError,
  }) {
    return PresetOpsState(
      clipboard: clipboard ?? this.clipboard,
      isBusy: isBusy ?? this.isBusy,
      progress: progress ?? this.progress,
      message: clearMessage ? null : (message ?? this.message),
      isError: isError ?? this.isError,
    );
  }
}

final presetOpsProvider = NotifierProvider<PresetOpsNotifier, PresetOpsState>(
  PresetOpsNotifier.new,
);

/// Copy / paste / drag-to-reorder of presets on the connected pedal.
class PresetOpsNotifier extends Notifier<PresetOpsState> {
  @override
  PresetOpsState build() => const PresetOpsState();

  static String _pad(int i) => i.toString().padLeft(3, '0');

  Future<void> copy(int index) async {
    await _run(tr('Copying preset {0}...', [_pad(index)]), (ops, names) async {
      final snap = await ops.copy(index, names);
      state = state.copyWith(clipboard: snap);
      return (
        message: tr('Copied {0} {1}', [_pad(index), snap.name]),
        names: const <int, String>{},
        select: null,
      );
    });
  }

  Future<void> paste(int target) async {
    final clip = state.clipboard;
    if (clip == null) return;
    await _run(tr('Pasting into {0}...', [_pad(target)]), (ops, names) async {
      await ops.paste(clip, target);
      return (
        message: tr('Pasted {0} into {1}', [clip.name, _pad(target)]),
        names: <int, String>{target: clip.name},
        select: target,
      );
    });
  }

  Future<void> clear(int index) async {
    await _run(tr('Clearing preset {0}...', [_pad(index)]), (ops, names) async {
      final cleared = await ops.clear(index);
      return (
        message: tr('Cleared {0}', [_pad(index)]),
        names: <int, String>{index: cleared.name},
        select: index,
      );
    });
  }

  Future<void> move(int from, int to) async {
    if (from == to) return;
    await _run('Moving ${_pad(from)} → ${_pad(to)}...', (ops, names) async {
      final newNames = await ops.move(
        from,
        to,
        names,
        onProgress: (fraction, message) {
          state = state.copyWith(progress: fraction, message: message);
        },
      );
      return (
        message: tr('Moved {0} → {1}', [_pad(from), _pad(to)]),
        names: newNames,
        select: to,
      );
    });
  }

  /// Exports [indices] as official-editor `.pfl` files into [directory]
  /// (named like `03A DR Z.pfl`). Uses the raw records received from the
  /// pedal; presets written since are re-read first (full `0xE0` dump).
  Future<void> exportPfl(List<int> indices, String directory) async {
    if (indices.isEmpty) return;
    await _run(tr('Exporting {0} preset(s)...', [indices.length]), (
      ops,
      names,
    ) async {
      final sync = ref.read(fx200HardwareSyncProvider);
      if (indices.any((i) => sync.presetRecord(i) == null)) {
        state = state.copyWith(
          message: tr('Reading the presets from the pedal (about 30 s)...'),
        );
        await sync.ensureCompleteRecords();
      }
      var done = 0;
      for (final i in indices) {
        final record = sync.presetRecord(i);
        if (record == null) {
          throw StateError(
            tr('Preset {0} could not be read; nothing more was exported.', [
              _pad(i),
            ]),
          );
        }
        final name = Fx200Pfl.nameOf(record);
        final file = File(
          '$directory${Platform.pathSeparator}${Fx200Pfl.fileNameFor(i, name)}',
        );
        await file.writeAsBytes(Fx200Pfl.encode(record), flush: true);
        done++;
        state = state.copyWith(
          progress: done / indices.length,
          message: tr('Exported {0} {1}', [_pad(i), name]),
        );
      }
      return (
        message: tr('Exported {0} preset(s) to {1}', [done, directory]),
        names: const <int, String>{},
        select: null,
      );
    });
  }

  /// Writes `.pfl` files into consecutive slots starting at [firstSlot]
  /// with the official editor's `0x83` upload.
  Future<void> importPfl(List<String> paths, int firstSlot) async {
    if (paths.isEmpty) return;
    // Parse everything first: nothing is written if any file is invalid.
    final structs = <Uint8List>[];
    for (final path in paths) {
      try {
        structs.add(Fx200Pfl.decode(await File(path).readAsBytes()));
      } catch (e) {
        state = state.copyWith(
          message: '${path.split(Platform.pathSeparator).last}: $e',
          isError: true,
        );
        return;
      }
    }
    if (firstSlot + structs.length > 200) {
      state = state.copyWith(
        message: tr('Not enough slots after {0} for {1} presets.', [
          _pad(firstSlot),
          structs.length,
        ]),
        isError: true,
      );
      return;
    }
    await _run(tr('Importing {0} preset(s)...', [structs.length]), (
      ops,
      names,
    ) async {
      final sync = ref.read(fx200HardwareSyncProvider);
      final newNames = <int, String>{};
      for (var k = 0; k < structs.length; k++) {
        final slot = firstSlot + k;
        final name = Fx200Pfl.nameOf(structs[k]);
        state = state.copyWith(
          progress: k / structs.length,
          message: tr('Writing {0} into {1}...', [name, _pad(slot)]),
        );
        await fx200UploadPresetStruct(sync, slot, structs[k]);
        newNames[slot] = name;
      }
      return (
        message: tr('Imported {0} preset(s) from {1}', [
          structs.length,
          _pad(firstSlot),
        ]),
        names: newNames,
        select: firstSlot,
      );
    });
  }

  void clearMessage() {
    if (!state.isBusy) state = state.copyWith(clearMessage: true);
  }

  Future<void> _run(
    String startMessage,
    Future<({String message, Map<int, String> names, int? select})> Function(
      Fx200PresetOps ops,
      Map<int, String> names,
    )
    body,
  ) async {
    if (state.isBusy) return;
    final sync = ref.read(fx200HardwareSyncProvider);
    if (!sync.isConnected) {
      state = state.copyWith(
        message: tr('Connect the FX200 first.'),
        isError: true,
      );
      return;
    }
    final editor = ref.read(editorProvider.notifier);
    final returnTo = ref.read(editorProvider).preset?.patchNumber;
    state = state.copyWith(
      isBusy: true,
      progress: 0,
      message: startMessage,
      isError: false,
    );
    sync.suppressEditorUpdates = true;
    int? select = returnTo;
    try {
      final result = await body(
        Fx200PresetOps(sync),
        ref.read(editorProvider).presetNames,
      );
      editor.applyPresetNames(result.names);
      select = result.select ?? returnTo;
      state = state.copyWith(
        isBusy: false,
        progress: 1,
        message: result.message,
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, message: '$e', isError: true);
    } finally {
      sync.suppressEditorUpdates = false;
      if (select != null) await editor.loadPreset(select);
    }
  }
}
