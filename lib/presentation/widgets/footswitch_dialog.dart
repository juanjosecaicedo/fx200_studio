import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../services/fx200_hardware_sync.dart';
import '../../services/fx200_protocol.dart';
import '../state/device_settings_notifier.dart';
import '../state/editor_notifier.dart';
import 'global_settings_dialog.dart';

Future<void> showFootswitchDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const FootswitchDialog(),
  );
}

/// FOOTSWITCH menu of the pedal: OFF / CTRL / TAP for the active preset
/// (`0xA4`). Like on the hardware, it only persists after saving the preset.
class FootswitchDialog extends ConsumerWidget {
  const FootswitchDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final editor = ref.watch(editorProvider);
    final device = ref.watch(deviceSettingsProvider);
    final notifier = ref.read(deviceSettingsProvider.notifier);
    final config = device.footswitch;
    final preset = editor.preset;
    final presetLabel = preset == null
        ? ''
        : '${preset.patchNumber.toString().padLeft(3, '0')} ${preset.name}';

    Widget body;
    if (!editor.isHardwareConnected) {
      body = const DeviceNotice('Connect the FX200 to assign the footswitch.');
    } else if (config == null) {
      body = const DeviceNotice(
        'Waiting for the footswitch state (0xA4). Select a preset to load it.',
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('MODE', style: text.labelSmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: Fx200FootswitchConfig.modeOff,
                  label: Text('OFF'),
                  icon: Icon(Icons.block, size: 16),
                ),
                ButtonSegment(
                  value: Fx200FootswitchConfig.modeCtrl,
                  label: Text('CTRL'),
                  icon: Icon(Icons.toggle_on_outlined, size: 16),
                ),
                ButtonSegment(
                  value: Fx200FootswitchConfig.modeTap,
                  label: Text('TAP'),
                  icon: Icon(Icons.touch_app_outlined, size: 16),
                ),
              ],
              selected: <int>{config.mode},
              onSelectionChanged: (sel) =>
                  notifier.updateFootswitch(config.copyWith(mode: sel.first)),
            ),
            const SizedBox(height: 8),
            Text(switch (config.mode) {
              Fx200FootswitchConfig.modeCtrl =>
                'The preset footswitch turns the selected modules on/off '
                    '(LED blue / purple).',
              Fx200FootswitchConfig.modeTap =>
                'The preset footswitch taps the tempo (LED blinks red). '
                    'Current tempo: ${config.bpm} BPM. Turn on SUB-D in the '
                    'DELAY module to follow it.',
              _ =>
                'Pressing the footswitch only selects presets '
                    '(LED stays green).',
            }, style: text.bodySmall?.copyWith(color: ext.textMuted)),
            const SizedBox(height: 16),
            Text(
              'CTRL MODULES',
              style: text.labelSmall?.copyWith(
                color: config.mode == Fx200FootswitchConfig.modeCtrl
                    ? ext.textPrimary
                    : ext.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (
                  var slot = 0;
                  slot < Fx200FootswitchConfig.ctrlModuleNames.length;
                  slot++
                )
                  FilterChip(
                    label: Text(Fx200FootswitchConfig.ctrlModuleNames[slot]),
                    selected: config.isCtrlAssigned(slot),
                    selectedColor: ext
                        .colorFor(Fx200HardwareSync.categoryForSlot(slot))
                        .withValues(alpha: 0.28),
                    side: BorderSide(
                      color: ext.colorFor(
                        Fx200HardwareSync.categoryForSlot(slot),
                      ),
                    ),
                    onSelected: config.mode == Fx200FootswitchConfig.modeCtrl
                        ? (v) => notifier.updateFootswitch(
                            config.withCtrlAssigned(slot, v),
                          )
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (device.footswitchUnsaved)
                  Expanded(
                    child: Text(
                      'Not saved — the pedal forgets it when you change preset.',
                      style: text.bodySmall?.copyWith(
                        color: ext.colorFor(EffectCategory.drive),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: device.footswitchUnsaved
                      ? notifier.saveFootswitchToPreset
                      : null,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('SAVE TO PRESET'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: ext.panelSurface,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeviceDialogHeader(
              title: 'FOOTSWITCH',
              subtitle: presetLabel.isEmpty
                  ? 'Per-preset assignment'
                  : 'Assignment for preset $presetLabel',
            ),
            Flexible(child: SingleChildScrollView(child: body)),
          ],
        ),
      ),
    );
  }
}
