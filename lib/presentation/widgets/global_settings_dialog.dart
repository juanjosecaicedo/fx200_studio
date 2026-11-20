import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../services/fx200_protocol.dart';
import '../state/device_settings_notifier.dart';
import '../state/editor_notifier.dart';
import 'global_eq_graph.dart';
import '../../core/l10n/l10n.dart';

Future<void> showGlobalSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const GlobalSettingsDialog(),
  );
}

/// SYSTEM menu of the pedal (`0xA1`). Every change is written immediately,
/// like the official editor does.
class GlobalSettingsDialog extends ConsumerWidget {
  const GlobalSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final connected = ref.watch(
      editorProvider.select((s) => s.isHardwareConnected),
    );
    final settings = ref.watch(deviceSettingsProvider).global;
    final pedalScenes = ref.watch(
      editorProvider.select((s) => s.pedalScenesActive),
    );
    final notifier = ref.read(deviceSettingsProvider.notifier);

    Widget body;
    if (!connected) {
      body = DeviceNotice(tr('Connect the FX200 to edit its SYSTEM settings.'));
    } else if (settings == null) {
      body = DeviceNotice(
        tr(
          'Waiting for the SYSTEM block (0xA1). It arrives with the preset sync after connecting.',
        ),
      );
    } else {
      void set(Fx200GlobalSettings next) => notifier.updateGlobal(next);
      body = _SettingsBody(
        settings: settings,
        onChanged: set,
        pedalScenes: pedalScenes,
      );
    }

    return Dialog(
      backgroundColor: ext.panelSurface,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeviceDialogHeader(
              title: tr('SYSTEM · GLOBAL SETTINGS'),
              subtitle: tr('Applied to the pedal immediately'),
            ),
            Flexible(child: body),
          ],
        ),
      ),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody({
    required this.settings,
    required this.onChanged,
    this.pedalScenes = false,
  });

  final Fx200GlobalSettings settings;
  final ValueChanged<Fx200GlobalSettings> onChanged;

  /// The pedal runs the custom scenes firmware: offer FS MODE SCENE.
  final bool pedalScenes;

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final eqOn = s.globalEqEnabled;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Section('DISPLAY'),
          _IntSlider(
            label: tr('BRIGHTNESS'),
            value: s.brightness,
            min: 0,
            max: 100,
            onChanged: (v) => onChanged(s.withBrightness(v)),
          ),
          const _Section('INPUT'),
          _IntSlider(
            label: tr('INPUT LEVEL'),
            hint: tr(
              'Global input gain, as in the official editor (0 to 20 dB)',
            ),
            value: s.inputLevelDb,
            min: 0,
            max: 20,
            suffix: ' dB',
            onChanged: (v) => onChanged(s.withInputLevelDb(v)),
          ),
          const _Section('CAB'),
          _Toggle(
            label: tr('CAB SYNC'),
            hint: tr('Changing the AMP model also picks its matching cabinet'),
            value: s.cabSync,
            onChanged: (v) => onChanged(s.withCabSync(v)),
          ),
          _Row(
            label: tr('GLOBAL CAB'),
            hint: tr('Cab sim on the left / right output channel'),
            child: Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: Text(tr('LEFT')),
                  selected: s.globalCabLeft,
                  onSelected: (v) => onChanged(s.withGlobalCabLeft(v)),
                ),
                FilterChip(
                  label: Text(tr('RIGHT')),
                  selected: s.globalCabRight,
                  onSelected: (v) => onChanged(s.withGlobalCabRight(v)),
                ),
              ],
            ),
          ),
          _Section(tr('FOOTSWITCH & LOOPER')),
          _Row(
            label: tr('FS MODE'),
            hint: pedalScenes
                ? tr(
                    'NORMAL: banks + A/B · FAVORITE: 4 favorite presets · SCENE: the 4 footswitches select scenes 1-4 (custom firmware)',
                  )
                : tr('NORMAL: banks + A/B · FAVORITE: 4 favorite presets'),
            child: _Choice<int>(
              value: s.fsMode,
              options: <int, String>{
                Fx200GlobalSettings.fsModeNormal: 'NORMAL',
                Fx200GlobalSettings.fsModeFavorite: 'FAVORITE',
                Fx200GlobalSettings.fsModeDual: 'DUAL',
                // Also shown if the pedal reports 3 without the marker, so
                // the current value is never hidden.
                if (pedalScenes || s.fsMode == Fx200GlobalSettings.fsModeScene)
                  Fx200GlobalSettings.fsModeScene: 'SCENE',
              },
              onChanged: (v) =>
                  onChanged(s.withFsMode(v, allowScene: pedalScenes)),
            ),
          ),
          _Toggle(
            label: tr('DLY / REV SPILL-OVER'),
            hint: tr('Let delay and reverb tails ring out when switching'),
            value: s.spillOver,
            onChanged: (v) => onChanged(s.withSpillOver(v)),
          ),
          _Row(
            label: tr('LOOPER POSITION'),
            child: _Choice<bool>(
              value: s.looperPost,
              options: const <bool, String>{false: 'PRE', true: 'POST'},
              onChanged: (v) => onChanged(s.withLooperPost(v)),
            ),
          ),
          const _Section('GLOBAL EQ'),
          _Toggle(
            label: tr('GLOBAL EQ'),
            hint: tr('Applies to OUTPUT / XLR OUT / PHONES'),
            value: eqOn,
            onChanged: (v) => onChanged(s.withGlobalEqEnabled(v)),
          ),
          const SizedBox(height: 6),
          GlobalEqGraph(settings: s, enabled: eqOn, onChanged: onChanged),
          const SizedBox(height: 4),
          _EqHint(enabled: eqOn),
          const SizedBox(height: 8),
          _EqReadouts(settings: s, enabled: eqOn),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                tr('EXACT VALUES'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              children: [
                _EqBand(
                  label: tr('LOW'),
                  enabled: eqOn,
                  freqHz: s.eqLowFreqHz,
                  gain: s.eqLowGain,
                  onFreq: (v) => onChanged(s.withEqLowFreqHz(v)),
                  onGain: (v) => onChanged(s.withEqLowGain(v)),
                ),
                _EqBand(
                  label: tr('MID'),
                  enabled: eqOn,
                  freqHz: s.eqMidFreqHz,
                  gain: s.eqMidGain,
                  onFreq: (v) => onChanged(s.withEqMidFreqHz(v)),
                  onGain: (v) => onChanged(s.withEqMidGain(v)),
                ),
                _EqBand(
                  label: tr('HIGH'),
                  enabled: eqOn,
                  freqHz: s.eqHighFreqHz,
                  gain: s.eqHighGain,
                  onFreq: (v) => onChanged(s.withEqHighFreqHz(v)),
                  onGain: (v) => onChanged(s.withEqHighGain(v)),
                ),
                _FreqSlider(
                  label: tr('LOW CUT'),
                  enabled: eqOn,
                  valueHz: s.eqLowCutHz,
                  minHz: 40,
                  maxHz: 1000,
                  onChanged: (v) => onChanged(s.withEqLowCutHz(v)),
                ),
                _FreqSlider(
                  label: tr('HIGH CUT'),
                  enabled: eqOn,
                  valueHz: s.eqHighCutHz,
                  minHz: 3000,
                  maxHz: 20000,
                  onChanged: (v) => onChanged(s.withEqHighCutHz(v)),
                ),
              ],
            ),
          ),
          const _Section('MIDI'),
          _Row(
            label: tr('MIDI PORT'),
            child: _Choice<bool>(
              value: s.midiOut,
              options: <bool, String>{false: 'MIDI IN', true: tr('MIDI OUT')},
              onChanged: (v) => onChanged(s.withMidiOut(v)),
            ),
          ),
          _Row(
            label: tr('MIDI CHANNEL'),
            child: DropdownButton<int>(
              value: s.midiChannel.clamp(
                0,
                s.midiOut ? 15 : Fx200GlobalSettings.midiChannelOmni,
              ),
              onChanged: (v) {
                if (v != null) onChanged(s.withMidiChannel(v));
              },
              items: [
                for (var ch = 0; ch < 16; ch++)
                  DropdownMenuItem<int>(
                    value: ch,
                    child: Text(tr('CH {0}', [ch + 1])),
                  ),
                if (!s.midiOut)
                  DropdownMenuItem<int>(
                    value: Fx200GlobalSettings.midiChannelOmni,
                    child: Text(tr('OMNI')),
                  ),
              ],
            ),
          ),
          _Toggle(
            label: tr('SYNC CLOCK'),
            hint: tr('Receive (IN) or send (OUT) MIDI clock'),
            value: s.midiClockSync,
            onChanged: (v) => onChanged(s.withMidiClockSync(v)),
          ),
          _Section(tr('USB AUDIO')),
          _Row(
            label: tr('LEFT OUTPUT'),
            child: _Choice<bool>(
              value: s.usbLeftDry,
              options: const <bool, String>{false: 'EFFECTS', true: 'DRY'},
              onChanged: (v) => onChanged(s.withUsbLeftDry(v)),
            ),
          ),
          _Row(
            label: tr('RIGHT OUTPUT'),
            child: _Choice<bool>(
              value: s.usbRightDry,
              options: const <bool, String>{false: 'EFFECTS', true: 'DRY'},
              onChanged: (v) => onChanged(s.withUsbRightDry(v)),
            ),
          ),
          _IntSlider(
            label: tr('REC VOL'),
            value: s.usbRecVol,
            min: 0,
            max: 100,
            onChanged: (v) => onChanged(s.withUsbRecVol(v)),
          ),
          _IntSlider(
            label: tr('PLAY VOL'),
            value: s.usbPlayVol,
            min: 0,
            max: 100,
            onChanged: (v) => onChanged(s.withUsbPlayVol(v)),
          ),
          _IntSlider(
            label: tr('MIX'),
            hint: tr('0 = direct monitoring only · 100 = USB playback only'),
            value: s.usbMix,
            min: 0,
            max: 100,
            onChanged: (v) => onChanged(s.withUsbMix(v)),
          ),
        ],
      ),
    );
  }
}

class _EqBand extends StatelessWidget {
  const _EqBand({
    required this.label,
    required this.enabled,
    required this.freqHz,
    required this.gain,
    required this.onFreq,
    required this.onGain,
  });

  final String label;
  final bool enabled;
  final int freqHz;
  final int gain;
  final ValueChanged<int> onFreq;
  final ValueChanged<int> onGain;

  @override
  Widget build(BuildContext context) {
    final db = Fx200GlobalSettings.gainToDb(gain);
    return Row(
      children: [
        Expanded(
          child: _FreqSlider(
            label: tr('{0} FREQ', [label]),
            enabled: enabled,
            valueHz: freqHz,
            minHz: 40,
            maxHz: 20000,
            onChanged: onFreq,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _LabeledSlider(
            label: tr('{0} GAIN', [label]),
            valueLabel: '${db >= 0 ? '+' : ''}${db.toStringAsFixed(1)} dB',
            value: gain.clamp(0, Fx200GlobalSettings.eqGainMax).toDouble(),
            min: 0,
            max: Fx200GlobalSettings.eqGainMax.toDouble(),
            divisions: Fx200GlobalSettings.eqGainMax,
            onChanged: enabled ? (v) => onGain(v.round()) : null,
          ),
        ),
      ],
    );
  }
}

/// Logarithmic frequency slider (Hz).
class _FreqSlider extends StatelessWidget {
  const _FreqSlider({
    required this.label,
    required this.enabled,
    required this.valueHz,
    required this.minHz,
    required this.maxHz,
    required this.onChanged,
  });

  final String label;
  final bool enabled;
  final int valueHz;
  final int minHz;
  final int maxHz;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final lo = _log(minHz.toDouble());
    final hi = _log(maxHz.toDouble());
    final pos = _log(valueHz.clamp(minHz, maxHz).toDouble());
    return _LabeledSlider(
      label: label,
      valueLabel: valueHz >= 1000
          ? '${(valueHz / 1000).toStringAsFixed(valueHz >= 10000 ? 1 : 2)} kHz'
          : '$valueHz Hz',
      value: pos,
      min: lo,
      max: hi,
      onChanged: enabled
          ? (v) => onChanged(_exp(v).round().clamp(minHz, maxHz))
          : null,
    );
  }

  static double _log(double hz) => hz <= 0 ? 0 : math.log(hz);
  static double _exp(double v) => math.exp(v);
}

class _IntSlider extends StatelessWidget {
  const _IntSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.hint,
    this.suffix = '',
  });

  final String label;
  final String? hint;
  final String suffix;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _LabeledSlider(
      label: label,
      hint: hint,
      valueLabel: '$value$suffix',
      value: value.clamp(min, max).toDouble(),
      min: min.toDouble(),
      max: max.toDouble(),
      divisions: max - min,
      onChanged: (v) => onChanged(v.round()),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.hint,
  });

  final String label;
  final String? hint;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: text.labelSmall)),
              Text(
                valueLabel,
                style: text.labelSmall?.copyWith(
                  color: onChanged == null ? ext.textMuted : ext.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (hint != null)
            Text(hint!, style: text.bodySmall?.copyWith(color: ext.textMuted)),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final String? hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _Row(
      label: label,
      hint: hint,
      child: Switch(value: value, onChanged: onChanged),
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: [
        for (final e in options.entries)
          ButtonSegment<T>(value: e.key, label: Text(e.value)),
      ],
      selected: options.containsKey(value) ? <T>{value} : <T>{},
      emptySelectionAllowed: !options.containsKey(value),
      onSelectionChanged: (sel) {
        if (sel.isNotEmpty) onChanged(sel.first);
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child, this.hint});

  final String label;
  final String? hint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 6,
        spacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelSmall),
                if (hint != null)
                  Text(
                    hint!,
                    style: text.bodySmall?.copyWith(color: ext.textMuted),
                  ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 2),
      child: Row(
        children: [
          Text(
            tr(title),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: ext.textMuted, letterSpacing: 1.2),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: ext.subtleBorder, height: 1)),
        ],
      ),
    );
  }
}

class DeviceNotice extends StatelessWidget {
  const DeviceNotice(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: ext.textMuted),
      ),
    );
  }
}

/// Shared header for the device dialogs.
class DeviceDialogHeader extends StatelessWidget {
  const DeviceDialogHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: ext.subtleBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(color: ext.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('Close'),
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _EqHint extends StatelessWidget {
  const _EqHint({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    return Text(
      enabled
          ? tr(
              'Drag L / M / H for frequency + gain, LC / HC for the cuts. Double-click a node to reset it.',
            )
          : tr(
              'Turn GLOBAL EQ on to edit (the pedal ignores the values while off).',
            ),
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: ext.textMuted),
    );
  }
}

class _EqReadouts extends StatelessWidget {
  const _EqReadouts({required this.settings, required this.enabled});

  final Fx200GlobalSettings settings;
  final bool enabled;

  static String _hz(int hz) => hz >= 1000
      ? '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 1 : 2)} kHz'
      : '$hz Hz';

  static String _db(int raw) {
    final db = Fx200GlobalSettings.gainToDb(raw);
    return '${db > 0 ? '+' : ''}${db.toStringAsFixed(1)} dB';
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final s = settings;
    final entries = <(String, String)>[
      ('LC', _hz(s.eqLowCutHz)),
      ('LOW', '${_hz(s.eqLowFreqHz)} · ${_db(s.eqLowGain)}'),
      ('MID', '${_hz(s.eqMidFreqHz)} · ${_db(s.eqMidGain)}'),
      ('HIGH', '${_hz(s.eqHighFreqHz)} · ${_db(s.eqHighGain)}'),
      ('HC', _hz(s.eqHighCutHz)),
    ];
    final text = Theme.of(context).textTheme.labelSmall;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final (label, value) in entries)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ext.blockSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ext.subtleBorder),
            ),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label  ',
                    style: text?.copyWith(color: ext.textMuted),
                  ),
                  TextSpan(
                    text: value,
                    style: text?.copyWith(
                      color: enabled ? ext.textPrimary : ext.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
