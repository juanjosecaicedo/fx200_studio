import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/fx200_backup.dart';
import '../../services/fx200_bfl.dart';
import '../../services/fx200_pfl.dart';
import 'editor_notifier.dart';
import '../../core/l10n/l10n.dart';

enum BackupPhase { idle, backingUp, restoring, done, failed, cancelled }

class BackupState {
  const BackupState({
    this.phase = BackupPhase.idle,
    this.progress = 0,
    this.message = '',
    this.loadedBackup,
    this.loadedPath,
    this.loadedBfl,
  });

  final BackupPhase phase;
  final double progress;
  final String message;

  /// Backup file opened for restore (parsed, not yet written).
  final Fx200Backup? loadedBackup;
  final String? loadedPath;

  /// Official editor backup (`.bfl`) opened for restore.
  final Fx200Bfl? loadedBfl;

  bool get isBusy =>
      phase == BackupPhase.backingUp || phase == BackupPhase.restoring;

  BackupState copyWith({
    BackupPhase? phase,
    double? progress,
    String? message,
    Fx200Backup? loadedBackup,
    String? loadedPath,
    Fx200Bfl? loadedBfl,
    bool clearLoaded = false,
  }) {
    return BackupState(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      loadedBackup: clearLoaded ? null : (loadedBackup ?? this.loadedBackup),
      loadedPath: clearLoaded ? null : (loadedPath ?? this.loadedPath),
      loadedBfl: clearLoaded ? null : (loadedBfl ?? this.loadedBfl),
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

  /// Writes an official-editor backup (`.bfl`) to [path]: presets from the
  /// pedal's dump, IR samples and system data read with `0xAA`, the SYSTEM
  /// block and IR names — byte-compatible with FX200.exe's BACKUP.
  Future<void> createBfl(String path) async {
    if (state.isBusy) return;
    final sync = ref.read(fx200HardwareSyncProvider);
    if (!sync.isConnected) {
      state = state.copyWith(
        phase: BackupPhase.failed,
        message: tr('Connect the FX200 first.'),
      );
      return;
    }
    state = state.copyWith(
      phase: BackupPhase.backingUp,
      progress: 0,
      message: tr('Starting backup...'),
    );
    sync.suppressEditorUpdates = true;
    try {
      if (sync.incompletePresets.isNotEmpty ||
          sync.lastGlobalSettings == null ||
          sync.irNamesBody == null) {
        _onProgress(
          0,
          tr('Reading the presets from the pedal (about 30 s)...'),
        );
        if (sync.incompletePresets.isEmpty) await sync.readFullDump();
        await sync.ensureCompleteRecords();
      }
      final records = <Uint8List>[
        for (var i = 0; i < 200; i++)
          sync.presetRecord(i) ??
              (throw StateError(
                tr('Preset {0} could not be read; nothing more was exported.', [
                  i.toString().padLeft(3, '0'),
                ]),
              )),
      ];
      final namesBody = sync.irNamesBody;
      final global = sync.lastGlobalSettings;
      if (namesBody == null || global == null) {
        throw StateError(
          tr('The pedal did not send its SYSTEM block or IR list.'),
        );
      }
      final names = sync.irNames ?? const <String>[];
      final used = <int>[
        for (var s = 0; s < names.length; s++)
          if (names[s].isNotEmpty) s,
      ];
      final extras = await fx200ReadBackupExtras(
        sync,
        used,
        onProgress: (f, m) => _onProgress(f, tr(m)),
      );
      final active = ref.read(editorProvider).preset?.patchNumber ?? 0;
      final bytes = Fx200Bfl.build(
        records: records,
        activePreset: active,
        irSamples: extras.irSamples,
        irNamesBody: namesBody,
        globalBody: global.raw,
        type5: extras.type5,
      );
      await File(path).writeAsBytes(bytes, flush: true);
      state = state.copyWith(
        phase: BackupPhase.done,
        progress: 1,
        message: tr('Official backup saved: 200 presets, {0} IRs → {1}', [
          extras.irSamples.length,
          path,
        ]),
      );
    } catch (e) {
      state = state.copyWith(phase: BackupPhase.failed, message: '$e');
    } finally {
      await _finishSweep();
    }
  }

  /// Reads every preset + global settings and writes them to [path].
  Future<void> createBackup(String path) async {
    if (state.isBusy) return;
    final sync = ref.read(fx200HardwareSyncProvider);
    if (!sync.isConnected) {
      state = state.copyWith(
        phase: BackupPhase.failed,
        message: tr('Connect the FX200 first.'),
      );
      return;
    }
    final service = Fx200BackupService(sync);
    _service = service;
    state = state.copyWith(
      phase: BackupPhase.backingUp,
      progress: 0,
      message: tr('Starting backup...'),
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
            ? tr('Backup saved: {0} presets + global settings → {1}', [
                backup.presets.length,
                path,
              ])
            : tr(
                'Backup saved → {0} ({1} presets incomplete, they will be skipped on restore)',
                [path, missing],
              ),
      );
    } on Fx200BackupCancelled {
      state = state.copyWith(
        phase: BackupPhase.cancelled,
        message: tr('Backup cancelled. No file written.'),
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
      if (path.toLowerCase().endsWith('.${Fx200Bfl.fileExtension}')) {
        final bfl = Fx200Bfl.parse(await File(path).readAsBytes());
        state = BackupState(loadedBfl: bfl, loadedPath: path);
        return;
      }
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
        message: tr('Could not open backup: {0}', [e]),
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
        message: tr('Connect the FX200 first.'),
      );
      return;
    }
    final service = Fx200BackupService(sync);
    _service = service;
    state = state.copyWith(
      phase: BackupPhase.restoring,
      progress: 0,
      message: tr('Starting restore...'),
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
        message: tr('Restore complete: {0}.', [parts.join(', ')]),
      );
    } on Fx200BackupCancelled {
      state = state.copyWith(
        phase: BackupPhase.cancelled,
        message: tr('Restore cancelled. Presets already written stay written.'),
      );
    } catch (e) {
      state = state.copyWith(phase: BackupPhase.failed, message: '$e');
    } finally {
      await _finishSweep();
    }
  }

  bool _bflCancelled = false;

  /// Writes the loaded official `.bfl` backup to the pedal.
  Future<void> restoreLoadedBfl({
    required bool presets,
    required bool irs,
    required bool globals,
  }) async {
    final bfl = state.loadedBfl;
    if (bfl == null || state.isBusy) return;
    final sync = ref.read(fx200HardwareSyncProvider);
    if (!sync.isConnected) {
      state = state.copyWith(
        phase: BackupPhase.failed,
        message: tr('Connect the FX200 first.'),
      );
      return;
    }
    _bflCancelled = false;
    state = state.copyWith(
      phase: BackupPhase.restoring,
      progress: 0,
      message: tr('Starting restore...'),
    );
    sync.suppressEditorUpdates = true;
    try {
      final r = await fx200RestoreBfl(
        sync,
        bfl,
        presets: presets,
        irs: irs,
        globals: globals,
        onProgress: _onProgress,
        isCancelled: () => _bflCancelled,
      );
      // Verify on the pedal itself: re-read every preset (the uploads mark
      // them stale) and compare with the backup. This also refreshes the
      // preset names shown in the list from what the pedal really holds.
      var verified = '';
      if (presets) {
        _onProgress(
          1,
          tr('Verifying: reading the presets back (about 30 s)...'),
        );
        await sync.ensureCompleteRecords();
        final mismatched = <int>[
          for (var i = 0; i < bfl.presets.length; i++)
            if (!_sameStruct(sync.presetRecord(i), bfl.presets[i])) i,
        ];
        ref.read(editorProvider.notifier).applyPresetNames(<int, String>{
          for (var i = 0; i < 200; i++)
            if (sync.presetRecord(i) != null)
              i: Fx200Pfl.nameOf(sync.presetRecord(i)!),
        });
        if (mismatched.isNotEmpty) {
          state = state.copyWith(
            phase: BackupPhase.failed,
            progress: 1,
            message: tr(
              'The pedal reports {0} presets that differ from the backup: {1}',
              [
                mismatched.length,
                mismatched
                    .take(12)
                    .map((i) => i.toString().padLeft(3, '0'))
                    .join(', '),
              ],
            ),
          );
          return;
        }
        verified = tr(' (verified on the pedal)');
      }
      state = state.copyWith(
        phase: BackupPhase.done,
        progress: 1,
        message:
            tr('Restore complete: {0} presets, {1} IRs{2}.', [
              r.presets,
              r.irs,
              globals ? tr(', global settings') : '',
            ]) +
            verified,
      );
    } on Fx200BackupCancelled {
      state = state.copyWith(
        phase: BackupPhase.cancelled,
        message: tr('Restore cancelled. Data already written stays written.'),
      );
    } catch (e) {
      state = state.copyWith(phase: BackupPhase.failed, message: '$e');
    } finally {
      await _finishSweep();
    }
  }

  static bool _sameStruct(Uint8List? record, Uint8List struct) {
    if (record == null || record.length < Fx200Pfl.structSize) return false;
    for (var i = 0; i < Fx200Pfl.structSize; i++) {
      if (record[i] != struct[i]) return false;
    }
    return true;
  }

  void cancel() {
    _bflCancelled = true;
    _service?.cancel();
  }

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
