import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../services/fx200_protocol.dart';
import '../state/device_settings_notifier.dart';
import '../state/editor_notifier.dart';
import 'global_settings_dialog.dart';
import 'value_field.dart';
import '../../core/l10n/l10n.dart';

Future<void> showDrumDialog(BuildContext context) {
  return showDialog<void>(context: context, builder: (_) => const DrumDialog());
}

/// DRUM window (Software Guide p. 15, Manual p. 22-23): on/off, RHYTHM or
/// METRONOME, style and rhythm type, BPM (slider, typed value or TAP) and
/// volume. The drum machine is global and applies immediately.
class DrumDialog extends ConsumerStatefulWidget {
  const DrumDialog({super.key});

  @override
  ConsumerState<DrumDialog> createState() => _DrumDialogState();
}

class _DrumDialogState extends ConsumerState<DrumDialog> {
  DateTime? _lastTap;

  void _tap(Fx200DrumSettings drum) {
    final now = DateTime.now();
    final prev = _lastTap;
    _lastTap = now;
    if (prev == null) return;
    final ms = now.difference(prev).inMilliseconds;
    final bpm = (60000 / ms).round();
    if (bpm >= Fx200DrumSettings.minBpm && bpm <= Fx200DrumSettings.maxBpm) {
      ref
          .read(deviceSettingsProvider.notifier)
          .updateDrum(drum.copyWith(bpm: bpm));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final editor = ref.watch(editorProvider);
    final drum = ref.watch(deviceSettingsProvider).drum;
    final notifier = ref.read(deviceSettingsProvider.notifier);
    final accent = ext.colorFor(EffectCategory.delay);

    Widget body;
    if (!editor.isHardwareConnected) {
      body = DeviceNotice(tr('Connect the FX200 to use the drum machine.'));
    } else if (drum == null) {
      body = DeviceNotice(
        tr(
          'Waiting for the drum machine state (0xAD). It is sent when the pedal connects.',
        ),
      );
    } else {
      void update(Fx200DrumSettings next, {bool debounce = false}) =>
          notifier.updateDrum(next, debounce: debounce);

      Widget stepper(
        String label,
        int value,
        int count,
        ValueChanged<int> onChanged,
      ) {
        return Row(
          children: [
            SizedBox(width: 72, child: Text(label, style: text.labelSmall)),
            IconButton(
              tooltip: tr('Previous {0}', [label]),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_left, size: 18),
              onPressed: () => onChanged(value <= 1 ? count : value - 1),
            ),
            SizedBox(
              width: 72,
              child: Text(
                '$value / $count',
                textAlign: TextAlign.center,
                style: text.labelLarge,
              ),
            ),
            IconButton(
              tooltip: tr('Next {0}', [label]),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chevron_right, size: 18),
              onPressed: () => onChanged(value >= count ? 1 : value + 1),
            ),
          ],
        );
      }

      Widget slider(
        String label,
        int value,
        int min,
        int max,
        String suffix,
        Fx200DrumSettings Function(int) apply,
      ) {
        int? parse(String s) {
          final m = RegExp(r'\d+').firstMatch(s);
          return m == null ? null : int.parse(m.group(0)!).clamp(min, max);
        }

        return Row(
          children: [
            SizedBox(width: 72, child: Text(label, style: text.labelSmall)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: accent,
                  thumbColor: accent,
                  inactiveTrackColor: ext.subtleBorder,
                  trackHeight: 3,
                  overlayShape: SliderComponentShape.noOverlay,
                ),
                child: Slider(
                  value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
                  min: min.toDouble(),
                  max: max.toDouble(),
                  divisions: max - min,
                  onChanged: (v) => update(apply(v.round()), debounce: true),
                  onChangeEnd: (v) => update(apply(v.round())),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueField(
              text: '$value$suffix',
              accent: accent,
              parse: parse,
              onSubmit: (v) => update(apply(v)),
            ),
          ],
        );
      }

      body = Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Switch(
                  value: drum.on,
                  activeThumbColor: accent,
                  onChanged: (v) => update(drum.copyWith(on: v)),
                ),
                const SizedBox(width: 8),
                Text(drum.on ? 'ON' : 'OFF', style: text.labelLarge),
                const Spacer(),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, label: Text(tr('RHYTHM'))),
                    ButtonSegment(value: true, label: Text(tr('METRONOME'))),
                  ],
                  selected: <bool>{drum.isMetronome},
                  onSelectionChanged: (s) =>
                      update(drum.withMetronome(s.first)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!drum.isMetronome)
              stepper(
                'STYLE',
                drum.style,
                Fx200DrumSettings.rhythmStyleCount,
                (v) => update(drum.copyWith(style: v, groove: 1)),
              ),
            stepper(
              drum.isMetronome ? 'TEMPO' : 'RHYTHM',
              drum.groove,
              Fx200DrumSettings.grooveCount,
              (v) => update(drum.copyWith(groove: v)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: slider(
                    'BPM',
                    drum.bpm,
                    Fx200DrumSettings.minBpm,
                    Fx200DrumSettings.maxBpm,
                    '',
                    (v) => drum.copyWith(bpm: v),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _tap(drum),
                  child: Text(tr('TAP')),
                ),
              ],
            ),
            slider(
              'VOLUME',
              drum.volume,
              0,
              100,
              '',
              (v) => drum.copyWith(volume: v),
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'Global setting, applied immediately (no preset save needed).',
              ),
              style: text.bodySmall?.copyWith(color: ext.textMuted),
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
              title: tr('DRUM'),
              subtitle: tr('Drum machine and metronome'),
            ),
            Flexible(child: SingleChildScrollView(child: body)),
          ],
        ),
      ),
    );
  }
}
