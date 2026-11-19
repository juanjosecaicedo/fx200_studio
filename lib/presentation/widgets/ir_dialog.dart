import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../services/fx200_ir.dart';
import '../state/editor_notifier.dart';
import '../state/ir_notifier.dart';
import 'global_settings_dialog.dart';
import '../../core/l10n/l10n.dart';

Future<void> showIrDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const IrDialog());
}

/// User IR slots (CAB 31-80), Software Guide p. 14: load a third-party WAV
/// into any slot (loading over a used slot replaces it). The pedal stores
/// 1024 points at 44.1 kHz / 24-bit; other rates and lengths are converted.
class IrDialog extends ConsumerWidget {
  const IrDialog({super.key});

  static XTypeGroup get _wav =>
      XTypeGroup(label: tr('Impulse response'), extensions: <String>['wav']);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final editor = ref.watch(editorProvider);
    final ir = ref.watch(irProvider);
    final notifier = ref.read(irProvider.notifier);
    final accent = ext.colorFor(EffectCategory.cab);

    Future<void> load(int slot) async {
      final file = await openFile(acceptedTypeGroups: [_wav]);
      if (file == null) return;
      await notifier.loadWav(slot, file.path);
    }

    Future<void> remove(int slot, String name) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('Delete IR')),
          content: Text(
            tr(
              'Delete "{0}" from CAB {1} on the pedal? Presets using it will have an empty cabinet.',
              [name, slot + Fx200Ir.firstCabModel],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(tr('CANCEL')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(tr('DELETE')),
            ),
          ],
        ),
      );
      if (ok == true) await notifier.deleteSlot(slot);
    }

    Widget body;
    if (!editor.isHardwareConnected) {
      body = DeviceNotice(tr('Connect the FX200 to manage user IRs.'));
    } else if (ir.names == null) {
      body = DeviceNotice(
        tr(
          'Waiting for the IR list (0x85). It is sent when the pedal connects.',
        ),
      );
    } else {
      final names = ir.names!;
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ir.message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                ir.message!,
                style: text.bodySmall?.copyWith(
                  color: ir.isError
                      ? ext.colorFor(EffectCategory.drive)
                      : ext.textMuted,
                ),
              ),
            ),
          if (ir.isBusy)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: LinearProgressIndicator(
                value: ir.progress,
                minHeight: 3,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
                backgroundColor: ext.blockSurface,
              ),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: Fx200Ir.slotCount,
              itemBuilder: (_, slot) {
                final name = names[slot];
                final busy = ir.busySlot == slot;
                return ListTile(
                  dense: true,
                  leading: SizedBox(
                    width: 36,
                    child: Text(
                      '${slot + Fx200Ir.firstCabModel}',
                      style: text.labelLarge?.copyWith(color: accent),
                    ),
                  ),
                  title: Text(
                    name.isEmpty ? 'EMPTY' : name,
                    style: name.isEmpty
                        ? text.bodySmall?.copyWith(color: ext.textMuted)
                        : text.bodyMedium,
                  ),
                  trailing: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: ir.isBusy ? null : () => load(slot),
                              icon: Icon(
                                name.isEmpty ? Icons.add : Icons.swap_horiz,
                                size: 16,
                              ),
                              label: Text(
                                name.isEmpty ? tr('LOAD WAV') : tr('REPLACE'),
                              ),
                            ),
                            if (name.isNotEmpty)
                              IconButton(
                                tooltip: tr('Delete'),
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                ),
                                onPressed: ir.isBusy
                                    ? null
                                    : () => remove(slot, name),
                              ),
                          ],
                        ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              tr(
                'WAV 44.1 / 48 / 88.2 / 96 kHz, 16 / 24 / 32-bit float. The first 1024 points at 44.1 kHz are kept, like the official editor. Turn on the CAB module and pick the slot to use it.',
              ),
              style: text.bodySmall?.copyWith(color: ext.textMuted),
            ),
          ),
        ],
      );
    }

    return Dialog(
      backgroundColor: ext.panelSurface,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeviceDialogHeader(
              title: tr('USER IR'),
              subtitle: tr('Impulse responses in CAB slots 31-80'),
            ),
            Flexible(child: body),
          ],
        ),
      ),
    );
  }
}
