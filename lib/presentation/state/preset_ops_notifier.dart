import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/fx200_backup.dart';
import '../../services/fx200_preset_ops.dart';
import 'editor_notifier.dart';

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
    await _run('Copying preset ${_pad(index)}...', (ops, names) async {
      final snap = await ops.copy(index, names);
      state = state.copyWith(clipboard: snap);
      return (
        message: 'Copied ${_pad(index)} ${snap.name}',
        names: const <int, String>{},
        select: null,
      );
    });
  }

  Future<void> paste(int target) async {
    final clip = state.clipboard;
    if (clip == null) return;
    await _run('Pasting into ${_pad(target)}...', (ops, names) async {
      await ops.paste(clip, target);
      return (
        message: 'Pasted ${clip.name} into ${_pad(target)}',
        names: <int, String>{target: clip.name},
        select: target,
      );
    });
  }

  Future<void> clear(int index) async {
    await _run('Clearing preset ${_pad(index)}...', (ops, names) async {
      final cleared = await ops.clear(index);
      return (
        message: 'Cleared ${_pad(index)}',
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
        message: 'Moved ${_pad(from)} → ${_pad(to)}',
        names: newNames,
        select: to,
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
        message: 'Connect the FX200 first.',
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
