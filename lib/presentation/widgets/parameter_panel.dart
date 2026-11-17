import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import 'block_tile.dart';
import 'parametric_eq_graph.dart';
import 'rotary_knob.dart';

/// Adaptive parameter editor panel for the currently selected [EffectBlock].
class ParameterPanel extends StatelessWidget {
  const ParameterPanel({
    super.key,
    required this.block,
    required this.onParameterChanged,
    required this.onToggleBypass,
    required this.onModelChanged,
    required this.onModeChanged,
  });

  final EffectBlock? block;
  final void Function(String parameterId, double value, {bool recordHistory})
      onParameterChanged;
  final VoidCallback onToggleBypass;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<String> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final current = block;

    if (current == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ext.panelSurface,
          borderRadius: BorderRadius.circular(ext.panelRadius),
          border: Border.all(color: ext.subtleBorder),
        ),
        child: Center(
          child: Text(
            'SELECT A BLOCK IN THE SIGNAL CHAIN TO EDIT PARAMETERS',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      );
    }

    final accent = ext.colorFor(current.category);
    final isGraphicEq = current.category == EffectCategory.eq &&
        current.parameters.length >= 6;
    final eqBands = isGraphicEq
        ? current.parameters.sublist(0, 6)
        : const <BlockParameter>[];
    final nonEqParams = isGraphicEq
        ? current.parameters.sublist(6)
        : current.parameters;
    final knobs = nonEqParams
        .where((p) => p.kind == BlockParameterKind.knob)
        .toList();
    final sliders = nonEqParams
        .where((p) => p.kind == BlockParameterKind.slider)
        .toList();
    final modes = <String>{
      current.mode,
      'Mono',
      'Stereo',
      if (current.category == EffectCategory.amp) 'NAM Slim 35%',
      if (current.category == EffectCategory.cab) '44.1kHz 24b',
    }.toList();

    return AnimatedContainer(
      duration: ext.transitionDuration,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.panelSurface,
        borderRadius: BorderRadius.circular(ext.panelRadius),
        border: Border.all(color: current.enabled ? accent.withValues(alpha: 0.5) : ext.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      BlockTile.iconFor(current.category),
                      size: 16,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BlockTile.shortLabelFor(current.category),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: accent,
                        ),
                      ),
                      Text(
                        current.modelName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ],
              ),
              _CompactDropdown(
                label: 'MODEL',
                value: current.modelName,
                items: current.availableModels.contains(current.modelName)
                    ? current.availableModels
                    : <String>[current.modelName, ...current.availableModels],
                ext: ext,
                onChanged: onModelChanged,
              ),
              _CompactDropdown(
                label: 'MODE',
                value: current.mode,
                items: modes,
                ext: ext,
                onChanged: onModeChanged,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    current.enabled ? 'ACTIVE' : 'BYPASSED',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: current.enabled ? accent : ext.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: current.enabled,
                    activeThumbColor: accent,
                    onChanged: (_) => onToggleBypass(),
                  ),
                ],
              ),
            ],
          ),
          Divider(height: 20, color: ext.subtleBorder),
          if (isGraphicEq) ...[
            ParametricEqGraph(
              blockId: current.id,
              bands: eqBands,
              extraKnobs: knobs,
              accent: accent,
              onParameterChanged: onParameterChanged,
            ),
          ] else if (knobs.isNotEmpty)
            Wrap(
              spacing: 20,
              runSpacing: 14,
              children: [
                for (final param in knobs)
                  RotaryKnob(
                    key: ValueKey<String>('${current.id}_${param.id}'),
                    label: param.label,
                    value: param.value,
                    defaultValue: param.defaultValue,
                    min: param.min,
                    max: param.max,
                    unit: param.unit,
                    accentColor: accent,
                    onChanged: (v) => onParameterChanged(
                      param.id,
                      v,
                      recordHistory: false,
                    ),
                    onChangeEnd: (v) => onParameterChanged(
                      param.id,
                      v,
                      recordHistory: true,
                    ),
                  ),
              ],
            ),
          if (sliders.isNotEmpty) ...[
            if (knobs.isNotEmpty) const SizedBox(height: 12),
            for (final param in sliders)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        param.label,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: accent,
                          inactiveTrackColor: ext.subtleBorder,
                          thumbColor: accent,
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: param.value.clamp(param.min, param.max),
                          min: param.min,
                          max: param.max,
                          onChanged: (v) => onParameterChanged(
                            param.id,
                            v,
                            recordHistory: false,
                          ),
                          onChangeEnd: (v) => onParameterChanged(
                            param.id,
                            v,
                            recordHistory: true,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        '${param.value.round()} ${param.unit}'.trim(),
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: ext.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  const _CompactDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.ext,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final FxEditorThemeExtension ext;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: ext.blockSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ext.subtleBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          dropdownColor: ext.elevatedSurface,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: ext.textPrimary,
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                ),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}
