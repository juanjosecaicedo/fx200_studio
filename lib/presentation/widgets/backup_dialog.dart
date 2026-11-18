import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../services/fx200_backup.dart';
import '../state/backup_notifier.dart';
import '../state/editor_notifier.dart';
import 'global_settings_dialog.dart';

Future<void> showBackupDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const BackupDialog(),
  );
}

const XTypeGroup _backupTypeGroup = XTypeGroup(
  label: 'FX200 Studio backup',
  extensions: <String>[Fx200Backup.fileExtension],
);

/// Full-device backup (200 presets + SYSTEM block) and restore.
class BackupDialog extends ConsumerStatefulWidget {
  const BackupDialog({super.key});

  @override
  ConsumerState<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends ConsumerState<BackupDialog> {
  bool _restorePresets = true;
  bool _restoreGlobals = true;
  bool _confirmOverwrite = false;

  Future<void> _createBackup() async {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}';
    final location = await getSaveLocation(
      suggestedName: 'fx200_$stamp.${Fx200Backup.fileExtension}',
      acceptedTypeGroups: const <XTypeGroup>[_backupTypeGroup],
    );
    if (location == null) return;
    var path = location.path;
    if (!path.toLowerCase().endsWith('.${Fx200Backup.fileExtension}')) {
      path = '$path.${Fx200Backup.fileExtension}';
    }
    await ref.read(backupProvider.notifier).createBackup(path);
  }

  Future<void> _openBackup() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_backupTypeGroup],
    );
    if (file == null) return;
    setState(() => _confirmOverwrite = false);
    await ref.read(backupProvider.notifier).loadBackupFile(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final connected = ref.watch(
      editorProvider.select((s) => s.isHardwareConnected),
    );
    final state = ref.watch(backupProvider);
    final notifier = ref.read(backupProvider.notifier);
    final busy = state.isBusy;
    final loaded = state.loadedBackup;
    final warn = ext.colorFor(EffectCategory.drive);

    final canRestore =
        connected &&
        !busy &&
        loaded != null &&
        _confirmOverwrite &&
        (_restorePresets || (_restoreGlobals && loaded.globalSettings != null));

    return Dialog(
      backgroundColor: ext.panelSurface,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeviceDialogHeader(
              title: 'BACKUP & RESTORE',
              subtitle: '200 presets + SYSTEM settings',
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!connected)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Connect the FX200 to create or restore a backup. '
                          'You can still open a backup file to inspect it.',
                          style: text.bodySmall?.copyWith(color: warn),
                        ),
                      ),
                    Text('CREATE BACKUP', style: text.labelSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Reads every preset from the pedal (about one minute). '
                      'The pedal steps through all presets while reading and '
                      'returns to the current one at the end.',
                      style: text.bodySmall?.copyWith(color: ext.textMuted),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: connected && !busy ? _createBackup : null,
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: const Text('BACKUP TO FILE...'),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Divider(color: ext.subtleBorder, height: 1),
                    const SizedBox(height: 16),
                    Text('RESTORE', style: text.labelSmall),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : _openBackup,
                        icon: const Icon(Icons.folder_open_outlined, size: 16),
                        label: const Text('OPEN BACKUP...'),
                      ),
                    ),
                    if (loaded != null) ...[
                      const SizedBox(height: 12),
                      _BackupSummary(backup: loaded, path: state.loadedPath),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: _restorePresets,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => _restorePresets = v!),
                        title: Text(
                          'Presets (${loaded.restorablePresetCount} '
                          'of ${loaded.presets.length})',
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: _restoreGlobals && loaded.globalSettings != null,
                        onChanged: busy || loaded.globalSettings == null
                            ? null
                            : (v) => setState(() => _restoreGlobals = v!),
                        title: Text(
                          loaded.globalSettings == null
                              ? 'Global settings (not in this backup)'
                              : 'Global settings (SYSTEM)',
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: _confirmOverwrite,
                        onChanged: busy
                            ? null
                            : (v) => setState(() => _confirmOverwrite = v!),
                        title: Text(
                          'I understand this overwrites the selected data on '
                          'the pedal',
                          style: text.bodySmall?.copyWith(color: warn),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(backgroundColor: warn),
                          onPressed: canRestore
                              ? () => notifier.restoreLoadedBackup(
                                  presets: _restorePresets,
                                  globals: _restoreGlobals,
                                )
                              : null,
                          icon: const Icon(Icons.upload_outlined, size: 16),
                          label: const Text('RESTORE TO PEDAL'),
                        ),
                      ),
                    ],
                    if (state.phase != BackupPhase.idle) ...[
                      const SizedBox(height: 18),
                      _ProgressPanel(state: state, onCancel: notifier.cancel),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackupSummary extends StatelessWidget {
  const _BackupSummary({required this.backup, required this.path});

  final Fx200Backup backup;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final created = backup.createdAt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final date =
        '${created.year}-${two(created.month)}-${two(created.day)} '
        '${two(created.hour)}:${two(created.minute)}';
    final preview = backup.presets
        .take(4)
        .map((p) => '${p.index.toString().padLeft(3, '0')} ${p.name}')
        .join(' · ');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ext.blockSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ext.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            path ?? 'Backup',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall,
          ),
          const SizedBox(height: 2),
          Text(
            'Created $date · ${backup.presets.length} presets'
            '${backup.globalSettings != null ? ' · SYSTEM block' : ''}',
            style: text.bodySmall?.copyWith(color: ext.textMuted),
          ),
          if (preview.isNotEmpty)
            Text(
              '$preview …',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: ext.textMuted),
            ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.state, required this.onCancel});

  final BackupState state;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final color = switch (state.phase) {
      BackupPhase.failed => ext.meterPeak,
      BackupPhase.cancelled => ext.meterMid,
      BackupPhase.done => ext.meterLow,
      _ => ext.textPrimary,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isBusy) ...[
          LinearProgressIndicator(value: state.progress),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                state.message,
                style: text.bodySmall?.copyWith(color: color),
              ),
            ),
            if (state.isBusy)
              TextButton(onPressed: onCancel, child: const Text('CANCEL')),
          ],
        ),
      ],
    );
  }
}
