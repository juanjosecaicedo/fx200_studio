import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/fx200_backup.dart';
import 'editor_notifier.dart';

enum BackupPhase { idle, backingUp, restoring, done, failed, cancelled }

class BackupState {
  const BackupState({
    this.phase = BackupPhase.idle,
    this.progress = 0,
    this.message = '',
    this.loadedBackup,
    this.loadedPath,
  });

  final BackupPhase phase;
  final double progress;
  final String message;

  /// Backup file opened for restore (parsed, not yet written).
  final Fx200Backup? loadedBackup;
  final String? loadedPath;

  bool get isBusy =>
      phase == BackupPhase.backingUp || phase == BackupPhase.restoring;

  BackupState copyWith({
    BackupPhase? phase,
    double? progress,
    String? message,
    Fx200Backup? loadedBackup,
    String? loadedPath,
    bool clearLoaded = false,
  }) {
    return BackupState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      loadedBackup: clearLoaded ? null : (loadedBackup ?? this.loadedBackup),
      loadedPath: clearLoaded ? null : (loadedPath ?? this.loadedPath),
    );
  }
}

final backupProvider = NotifierProvider<BackupNotifier, BackupState>(
  BackupNotifier.new,
);

/// Drives full-device backups and restores through [Fx200BackupService].
class BackupNotifier extends Notifier<BackupState> {
  Fx200BackupService? _service;

  @override
  BackupState build() => const BackupState();

  /// Reads every preset + global settings and writes them to [path].
  Future<void> createBackup(String path) async {
    if (state.isBusy) return;
    final sync = ref.read(fx200HardwareSyncProvider);
    if (!sync.isConnected) {
      state = state.copyWith(
        phase: BackupPhase.failed,
        message: 'Connect the FX200 first.',
      );
      return;
    }
    final service = Fx200BackupService(sync);
    _service = service;
    state = state.copyWith(
      phase: BackupPhase.backingUp,
      progress: 0,
      message: 'Starting backup...',
    );
    sync.suppressEditorUpdates = true;
    try {
      final backup = await service.createBackup(
        knownNames: ref.read(editorProvider).presetNames,
        onProgress: _onProgress,
      );
      await File(path).writeAsString(backup.encode(), flush: true);
      final missing = backup.presets.length - backup.restorablePresetCount;
      state = state.copyWith(
        phase: BackupPhase.done,
        progress: 1,
        message: missing == 0
            ? 'Backup saved: ${backup.presets.length} presets + global settings'
                  ' → $path'
            : 'Backup saved → $path ($missing presets incomplete, '
                  'they will be skipped on restore)',
      );
    } on Fx200BackupCancelled {
      state = state.copyWith(
        phase: BackupPhase.cancelled,
        message: 'Backup cancelled. No file written.',
      );
    } catch (e) {
      state = state.copyWith(phase: BackupPhase.failed, message: '$e');
    } finally {
      await _finishSweep();
    }
  }

  /// Parses a backup file so the user can review it before restoring.
  Future<void> loadBackupFile(String path) async {
    if (state.isBusy) return;
    try {
      final backup = Fx200Backup.decode(await File(path).readAsString());
      state = state.copyWith(
        phase: BackupPhase.idle,
        progress: 0,
        message: '',
        loadedBackup: backup,
        loadedPath: path,
      );
    } catch (e) {
      state = state.copyWith(
        phase: BackupPhase.failed,
        message: 'Could not open backup: $e',
        clearLoaded: true,
      );
    }
  }

  void clearLoadedBackup() {
    if (state.isBusy) return;
    state = state.copyWith(clearLoaded: true, phase: BackupPhase.idle);
  }

  /// Writes the loaded backup to the pedal (overwrites presets / globals).
  Future<void> restoreLoadedBackup({
    required bool presets,
    required bool globals,
  }) async {
    final backup = state.loadedBackup;
    if (backup == null || state.isBusy) return;
    final sync = ref.read(fx200HardwareSyncProvider);
    if (!sync.isConnected) {
      state = state.copyWith(
        phase: BackupPhase.failed,
        message: 'Connect the FX200 first.',
      );
      return;
    }
    final service = Fx200BackupService(sync);
    _service = service;
    state = state.copyWith(
      phase: BackupPhase.restoring,
      progress: 0,
      message: 'Starting restore...',
    );
    sync.suppressEditorUpdates = true;
    try {
      final result = await service.restoreBackup(
        backup,
        restorePresets: presets,
        restoreGlobals: globals,
        onProgress: _onProgress,
      );
      final parts = <String>[
        if (presets) '${result.written} presets written',
        if (presets && result.skipped > 0)
          '${result.skipped} skipped (incomplete in backup)',
        if (globals && backup.globalSettings != null) 'global settings written',
      ];
      state = state.copyWith(
        phase: BackupPhase.done,
        progress: 1,
        message: 'Restore complete: ${parts.join(', ')}.',
      );
    } on Fx200BackupCancelled {
      state = state.copyWith(
        phase: BackupPhase.cancelled,
        message: 'Restore cancelled. Presets already written stay written.',
      );
    } catch (e) {
      state = state.copyWith(phase: BackupPhase.failed, message: '$e');
    } finally {
      await _finishSweep();
    }
  }

  void cancel() => _service?.cancel();

  void _onProgress(double fraction, String message) {
    state = state.copyWith(progress: fraction, message: message);
  }

  /// Re-enables live editor updates and reselects the preset the user was
  /// editing, so the editor and pedal agree again after the sweep.
  Future<void> _finishSweep() async {
    _service = null;
    final sync = ref.read(fx200HardwareSyncProvider);
    sync.suppressEditorUpdates = false;
    final editor = ref.read(editorProvider);
    final patch = editor.preset?.patchNumber;
    if (patch != null) {
      await ref.read(editorProvider.notifier).loadPreset(patch);
    }
  }
}
