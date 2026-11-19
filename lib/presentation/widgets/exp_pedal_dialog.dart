import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../services/fx200_hardware_sync.dart';
import '../../services/fx200_protocol.dart';
import '../state/editor_notifier.dart';
import '../state/exp_pedal_notifier.dart';
import 'global_settings_dialog.dart';
import 'value_field.dart';
import '../../core/l10n/l10n.dart';

Future<void> showExpPedalDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const ExpPedalDialog(),
  );
}

/// EXPRESSION PEDAL window, as described in the FX200 Software Guide (p. 9-10):
/// PEDAL 1 is the built-in pedal (EXPRESSION or VOLUME mode), PEDAL 2 the
/// external jack (EXPRESSION only). In EXPRESSION mode a pedal can drive
/// several module parameters at once, each with its own heel (minimum) and
/// toe (maximum) value. Like on the pedal, the setup belongs to the active
/// preset and must be saved to it.
class ExpPedalDialog extends ConsumerStatefulWidget {
  const ExpPedalDialog({super.key});

  @override
  ConsumerState<ExpPedalDialog> createState() => _ExpPedalDialogState();
}

class _ExpPedalDialogState extends ConsumerState<ExpPedalDialog> {
  int _pedal = Fx200ExpFrame.pedalInternal;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final editor = ref.watch(editorProvider);
    final exp = ref.watch(expPedalProvider);
    final notifier = ref.read(expPedalProvider.notifier);
    final preset = editor.preset;
    final presetLabel = preset == null
        ? ''
        : '${preset.patchNumber.toString().padLeft(3, '0')} ${preset.name}';

    Widget body;
    if (!editor.isHardwareConnected) {
      body = DeviceNotice(
        tr('Connect the FX200 to set up the expression pedals.'),
      );
    } else if (!exp.loaded || preset == null) {
      body = DeviceNotice(
        tr(
          'Waiting for the expression pedal setup (0xA3). Select a preset to load it.',
        ),
      );
    } else {
      final isVolume =
          _pedal == Fx200ExpFrame.pedalInternal &&
          exp.pedal1Mode == Fx200ExpFrame.modeVolume;
      body = Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: Fx200ExpFrame.pedalInternal,
                  label: Text(tr('PEDAL 1 · INTERNAL')),
                ),
                ButtonSegment(
                  value: Fx200ExpFrame.pedalExternal,
                  label: Text(tr('PEDAL 2 · EXTERNAL')),
                ),
              ],
              selected: <int>{_pedal},
              onSelectionChanged: (s) => setState(() => _pedal = s.first),
            ),
            const SizedBox(height: 16),
            Text(tr('MODE'), style: text.labelSmall),
            const SizedBox(height: 8),
            if (_pedal == Fx200ExpFrame.pedalInternal)
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: Fx200ExpFrame.modeExpression,
                    label: Text(tr('EXPRESSION')),
                    icon: Icon(Icons.tune, size: 16),
                  ),
                  ButtonSegment(
                    value: Fx200ExpFrame.modeVolume,
                    label: Text(tr('VOLUME')),
                    icon: Icon(Icons.volume_up_outlined, size: 16),
                  ),
                ],
                selected: <int>{exp.pedal1Mode},
                onSelectionChanged: (s) => notifier.setPedal1Mode(s.first),
              )
            else
              Text(
                tr(
                  'EXPRESSION — the external pedal cannot work in VOLUME mode.',
                ),
                style: text.bodySmall?.copyWith(color: ext.textMuted),
              ),
            const SizedBox(height: 16),
            if (isVolume)
              _VolumeSection(exp: exp, notifier: notifier)
            else
              _ExpressionSection(
                pedal: _pedal,
                preset: preset,
                assignments: exp.assignmentsFor(_pedal),
                notifier: notifier,
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (exp.unsaved)
                  Expanded(
                    child: Text(
                      tr(
                        'Not saved — the pedal forgets it when you change preset.',
                      ),
                      style: text.bodySmall?.copyWith(
                        color: ext.colorFor(EffectCategory.drive),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: exp.unsaved ? notifier.saveToPreset : null,
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: Text(tr('SAVE TO PRESET')),
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
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DeviceDialogHeader(
              title: tr('EXPRESSION PEDAL'),
              subtitle: presetLabel.isEmpty
                  ? tr('Per-preset setup')
                  : tr('Setup for preset {0}', [presetLabel]),
            ),
            Flexible(child: SingleChildScrollView(child: body)),
          ],
        ),
      ),
    );
  }
}

/// The preset's block for module [slot] (FX, DS/OD, AMP, ...), if any.
EffectBlock? _blockForSlot(Preset preset, int slot) {
  final category = Fx200HardwareSync.categoryForSlot(slot);
  for (final b in preset.blocks) {
    if (b.category == category) return b;
  }
  return null;
}

String _moduleName(int slot) => slot >= 0 && slot < 10
    ? Fx200Protocol.moduleNames[slot]
    : 'MODULE ${slot + 1}';

class _ExpressionSection extends StatelessWidget {
  const _ExpressionSection({
    required this.pedal,
    required this.preset,
    required this.assignments,
    required this.notifier,
  });

  final int pedal;
  final Preset preset;
  final List<ExpAssignment> assignments;
  final ExpPedalNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;

    // Knob parameters that are not assigned yet, grouped by module slot.
    final available = <PopupMenuEntry<(int, int)>>[];
    for (var slot = 0; slot < 10; slot++) {
      final block = _blockForSlot(preset, slot);
      if (block == null) continue;
      final items = <PopupMenuEntry<(int, int)>>[];
      for (var i = 0; i < block.parameters.length; i++) {
        final p = block.parameters[i];
        if (p.kind != BlockParameterKind.knob) continue;
        if (assignments.any((a) => a.sameTarget(slot, i))) continue;
        items.add(
          PopupMenuItem<(int, int)>(
            value: (slot, i),
            height: 34,
            child: Text('   ${p.label}'),
          ),
        );
      }
      if (items.isEmpty) continue;
      available
        ..add(
          PopupMenuItem<(int, int)>(
            enabled: false,
            height: 28,
            child: Text(
              '${_moduleName(slot)} · ${block.modelName}',
              style: text.labelSmall?.copyWith(
                color: ext.colorFor(block.category),
              ),
            ),
          ),
        )
        ..addAll(items);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(tr('CONTROLLED PARAMETERS'), style: text.labelSmall),
            ),
            PopupMenuButton<(int, int)>(
              tooltip: tr('Add a parameter'),
              enabled: available.isNotEmpty,
              itemBuilder: (_) => available,
              onSelected: (target) {
                final (slot, index) = target;
                final p = _blockForSlot(preset, slot)!.parameters[index];
                notifier.setAssignment(
                  pedal,
                  ExpAssignment(
                    moduleSlot: slot,
                    paramIndex: index,
                    min: p.min.round(),
                    max: p.max.round(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 16,
                      color: available.isEmpty
                          ? ext.textMuted
                          : ext.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tr('ADD PARAMETER'),
                      style: text.labelSmall?.copyWith(
                        color: available.isEmpty
                            ? ext.textMuted
                            : ext.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (assignments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              tr(
                'Nothing assigned. Add one or more parameters; each moves from its HEEL value (pedal up) to its TOE value (pedal down).',
              ),
              style: text.bodySmall?.copyWith(color: ext.textMuted),
            ),
          )
        else
          for (final a in assignments)
            _AssignmentCard(
              key: ValueKey<String>('$pedal:${a.moduleSlot}:${a.paramIndex}'),
              assignment: a,
              block: _blockForSlot(preset, a.moduleSlot),
              onChanged: (next, {required bool commit}) =>
                  notifier.setAssignment(pedal, next, debounce: !commit),
              onDelete: () => notifier.removeAssignment(pedal, a),
            ),
      ],
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    super.key,
    required this.assignment,
    required this.block,
    required this.onChanged,
    required this.onDelete,
  });

  final ExpAssignment assignment;
  final EffectBlock? block;
  final void Function(ExpAssignment next, {required bool commit}) onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final b = block;
    final param = b != null && assignment.paramIndex < b.parameters.length
        ? b.parameters[assignment.paramIndex]
        : null;
    final color = b != null ? ext.colorFor(b.category) : ext.textMuted;
    final lo = param?.min ?? 0;
    final hi = param?.max ?? 100;
    String fmt(int v) => param?.textOf(v.toDouble()) ?? '$v';
    int? parse(String s) {
      final v = param?.rawFromText(s) ?? double.tryParse(s.trim());
      return v?.round().clamp(lo.round(), hi.round());
    }

    Widget row(String label, int value, ExpAssignment Function(int) apply) {
      return Row(
        children: [
          SizedBox(width: 44, child: Text(label, style: text.labelSmall)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                inactiveTrackColor: ext.subtleBorder,
                trackHeight: 3,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value.toDouble().clamp(lo, hi),
                min: lo,
                max: hi > lo ? hi : lo + 1,
                divisions: (hi - lo) >= 1 ? (hi - lo).round() : null,
                onChanged: (v) => onChanged(apply(v.round()), commit: false),
                onChangeEnd: (v) => onChanged(apply(v.round()), commit: true),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueField(
            text: fmt(value),
            accent: color,
            parse: parse,
            onSubmit: (v) => onChanged(apply(v), commit: true),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 8),
      decoration: BoxDecoration(
        color: ext.blockSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${_moduleName(assignment.moduleSlot)}  ',
                        style: text.labelSmall?.copyWith(color: color),
                      ),
                      TextSpan(
                        text:
                            param?.label ??
                            'PARAM ${assignment.paramIndex + 1}',
                        style: text.labelLarge,
                      ),
                      if (b != null)
                        TextSpan(
                          text: '   ${b.modelName}',
                          style: text.bodySmall?.copyWith(color: ext.textMuted),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('Delete'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, size: 18),
                onPressed: onDelete,
              ),
            ],
          ),
          row('HEEL', assignment.min, (v) => assignment.copyWith(min: v)),
          row('TOE', assignment.max, (v) => assignment.copyWith(max: v)),
        ],
      ),
    );
  }
}

class _VolumeSection extends StatelessWidget {
  const _VolumeSection({required this.exp, required this.notifier});

  final ExpPedalState exp;
  final ExpPedalNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final range = exp.volume ?? Fx200VolumePedalRange.standard;
    final color = ext.colorFor(EffectCategory.volume);
    int? parse(String s) {
      final m = RegExp(r'\d+').firstMatch(s);
      return m == null ? null : int.parse(m.group(0)!).clamp(0, 100);
    }

    Widget row(String label, int value, Fx200VolumePedalRange Function(int) f) {
      return Row(
        children: [
          SizedBox(width: 44, child: Text(label, style: text.labelSmall)),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                inactiveTrackColor: ext.subtleBorder,
                trackHeight: 3,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                value: value.toDouble(),
                max: 100,
                divisions: 100,
                onChanged: (v) =>
                    notifier.setVolumeRange(f(v.round()), debounce: true),
                onChangeEnd: (v) => notifier.setVolumeRange(f(v.round())),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueField(
            text: '$value %',
            accent: color,
            parse: parse,
            onSubmit: (v) => notifier.setVolumeRange(f(v)),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(
            'The internal pedal controls the FX200 output volume between the HEEL (pedal up) and TOE (pedal down) levels.',
          ),
          style: text.bodySmall?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 12),
        row('HEEL', range.min, (v) => range.copyWith(min: v)),
        row('TOE', range.max, (v) => range.copyWith(max: v)),
      ],
    );
  }
}
