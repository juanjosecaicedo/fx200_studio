import 'package:material_ui/material_ui.dart';

import '../../core/fx200_models.dart';
import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import 'block_tile.dart';
import 'cab_designer.dart';
import 'compressor_designer.dart';
import 'model_art_view.dart';
import 'parametric_eq_graph.dart';
import 'rotary_knob.dart';
import '../../core/l10n/l10n.dart';

/// Adaptive parameter editor panel for the currently selected [EffectBlock].
class ParameterPanel extends StatelessWidget {
  const ParameterPanel({
    super.key,
    required this.block,
    required this.onParameterChanged,
    required this.onToggleBypass,
    required this.onModelChanged,
    required this.onModeChanged,
    this.modelLabel,
  });

  final EffectBlock? block;
  final void Function(String parameterId, double value, {bool recordHistory})
  onParameterChanged;
  final VoidCallback onToggleBypass;
  final ValueChanged<String> onModelChanged;
  final ValueChanged<String> onModeChanged;

  /// Display text of a model name (e.g. user IR slots with their IR name).
  final String Function(String modelName)? modelLabel;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final selected = block;

    if (selected == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ext.panelSurface,
          borderRadius: BorderRadius.circular(ext.panelRadius),
          border: Border.all(color: ext.subtleBorder),
        ),
        child: Center(
          child: Text(
            tr('SELECT A BLOCK IN THE SIGNAL CHAIN TO EDIT PARAMETERS'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      );
    }

    // Labels/ranges always follow the selected model (official table).
    final current = Fx200Models.withModelLayout(selected);
    final accent = ext.colorFor(current.category);
    final isGraphicEq = current.category == EffectCategory.eq;
    final eqLayout = isGraphicEq ? eqLayoutFor(current) : null;
    final nonEqParams = isGraphicEq
        ? const <BlockParameter>[]
        : current.parameters;
    final knobs = nonEqParams
        .where((p) => p.kind == BlockParameterKind.knob)
        .toList();
    final sliders = nonEqParams
        .where((p) => p.kind == BlockParameterKind.slider)
        .toList();
    final lists = CabDesigner.supports(current)
        ? const <BlockParameter>[]
        : nonEqParams.where((p) => p.kind == BlockParameterKind.mode).toList();
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
        border: Border.all(
          color: current.enabled
              ? accent.withValues(alpha: 0.5)
              : ext.subtleBorder,
        ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        BlockTile.shortLabelFor(current.category),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: accent),
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
                label: tr('MODEL'),
                value: current.modelName,
                items: current.availableModels.contains(current.modelName)
                    ? current.availableModels
                    : <String>[current.modelName, ...current.availableModels],
                ext: ext,
                onChanged: onModelChanged,
                itemLabel: modelLabel,
                itemLeading: (name) => ModelArtView(
                  category: current.category,
                  modelName: name,
                  width: 34,
                  height: 22,
                ),
              ),
              _CompactDropdown(
                label: tr('MODE'),
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
          LayoutBuilder(
            builder: (context, constraints) {
              final art = _ModelArtFrame(
                category: current.category,
                modelName: current.modelName,
                accent: accent,
                enabled: current.enabled,
              );
              final controls = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eqLayout != null) ...[
                    ParametricEqGraph(
                      key: ValueKey<String>(
                        '${current.id}_${current.modelName}',
                      ),
                      blockId: current.id,
                      bands: eqLayout.bands,
                      extraKnobs: eqLayout.knobs,
                      accent: accent,
                      onParameterChanged: onParameterChanged,
                    ),
                  ] else if (CompressorDesigner.supports(current)) ...[
                    CompressorDesigner(
                      block: current,
                      accent: accent,
                      onParameterChanged: onParameterChanged,
                    ),
                  ] else if (CabDesigner.supports(current)) ...[
                    CabDesigner(
                      block: current,
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
                            formatter: param.textOf,
                            parser: param.rawFromText,
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
                  if (lists.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        for (final param in lists)
                          _CompactDropdown(
                            key: ValueKey<String>('${current.id}_${param.id}'),
                            label: param.label,
                            showLabel: true,
                            value: param.displayText,
                            items: param.options,
                            ext: ext,
                            onChanged: (opt) => onParameterChanged(
                              param.id,
                              param.options.indexOf(opt).toDouble(),
                              recordHistory: true,
                            ),
                          ),
                      ],
                    ),
                  ],
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
                                  value: param.value.clamp(
                                    param.min,
                                    param.max,
                                  ),
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
                                param.displayText,
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: ext.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              );
              // Narrow panel: picture above the controls.
              if (constraints.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [art, const SizedBox(height: 14), controls],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  art,
                  const SizedBox(width: 20),
                  Expanded(child: controls),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Large picture of the model being edited, top-aligned with the controls.
class _ModelArtFrame extends StatelessWidget {
  const _ModelArtFrame({
    required this.category,
    required this.modelName,
    required this.accent,
    required this.enabled,
  });

  final EffectCategory category;
  final String modelName;
  final Color accent;
  final bool enabled;

  static const double size = 168;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    return AnimatedOpacity(
      duration: ext.transitionDuration,
      opacity: enabled ? 1.0 : 0.55,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ext.chassisBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: ModelArtView(category: category, modelName: modelName),
      ),
    );
  }
}

class _CompactDropdown extends StatelessWidget {
  const _CompactDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.ext,
    required this.onChanged,
    this.itemLeading,
    this.itemLabel,
    this.showLabel = false,
  });

  /// Shows [label] before the value (parameter lists such as SUB-D).
  final bool showLabel;

  final String label;
  final String value;
  final List<String> items;
  final FxEditorThemeExtension ext;
  final ValueChanged<String> onChanged;

  /// Optional widget shown before each item (e.g. the model illustration).
  final Widget Function(String item)? itemLeading;
  final String Function(String item)? itemLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: ext.blockSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ext.subtleBorder),
      ),
      child: !showLabel
          ? _dropdown(context)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: ext.textMuted),
                ),
                const SizedBox(width: 8),
                _dropdown(context),
              ],
            ),
    );
  }

  Widget _dropdown(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        dropdownColor: ext.elevatedSurface,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: ext.textPrimary),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: itemLeading == null
                    ? Text(itemLabel?.call(item) ?? item)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          itemLeading!(item),
                          const SizedBox(width: 8),
                          Text(itemLabel?.call(item) ?? item),
                        ],
                      ),
              ),
            )
            .toList(),
        onChanged: (val) {
          if (val != null) onChanged(val);
        },
      ),
    );
  }
}
