import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/fx200_models.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../services/fx200_hardware_sync.dart';
import '../../services/fx200_pedal_scenes.dart';
import '../../services/fx200_protocol.dart';
import '../state/pedal_scenes_notifier.dart';

Future<void> showPedalScenesDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const PedalScenesDialog(),
);

/// The four scenes stored on the pedal (FX200 Studio firmware, FS MODE
/// SCENE) side by side: per module, on/off and model, with the modules that
/// differ between scenes highlighted. Lets the user switch scenes and copy
/// one scene over another; changes stay on the pedal until Save.
class PedalScenesDialog extends ConsumerStatefulWidget {
  const PedalScenesDialog({super.key});

  @override
  ConsumerState<PedalScenesDialog> createState() => _PedalScenesDialogState();
}

class _PedalScenesDialogState extends ConsumerState<PedalScenesDialog> {
  int _copyFrom = 0;
  int _copyTo = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(pedalScenesProvider.notifier).loadAll(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final st = ref.watch(pedalScenesProvider);
    final notifier = ref.read(pedalScenesProvider.notifier);
    final scenes = st.scenes;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              st.preset == null
                  ? tr('Pedal scenes')
                  : tr('Pedal scenes - preset {0}', [
                      st.preset.toString().padLeft(3, '0'),
                    ]),
            ),
          ),
          IconButton(
            tooltip: tr('Read again from the pedal'),
            onPressed: st.busy || !st.available ? null : notifier.loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr(
                'Scenes are stored on the pedal. Click a scene to play it; edits go to the scene being played. Copies stay on the pedal until you Save the preset.',
              ),
              style: text.bodySmall?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 12),
            if (!st.available)
              Text(
                tr(
                  'Pedal scenes need the FX200 Studio firmware in FS MODE SCENE.',
                ),
                style: text.bodySmall,
              )
            else if (scenes == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _SceneTable(
                scenes: scenes,
                active: st.active,
                enabled: !st.busy,
                onSelect: (n) async {
                  await notifier.select(n);
                  await notifier.loadAll();
                },
              ),
            if (st.error != null) ...[
              const SizedBox(height: 8),
              Text(
                st.error!,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Text(tr('Copy scene'), style: text.labelSmall),
                const SizedBox(width: 8),
                _ScenePicker(
                  value: _copyFrom,
                  onChanged: (v) => setState(() => _copyFrom = v),
                ),
                const SizedBox(width: 8),
                Text(tr('to'), style: text.labelSmall),
                const SizedBox(width: 8),
                _ScenePicker(
                  value: _copyTo,
                  onChanged: (v) => setState(() => _copyTo = v),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: st.busy || scenes == null || _copyFrom == _copyTo
                      ? null
                      : () => notifier.copy(_copyFrom, _copyTo),
                  child: Text(tr('COPY')),
                ),
                if (st.busy) ...[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('CLOSE')),
        ),
      ],
    );
  }
}

class _ScenePicker extends StatelessWidget {
  const _ScenePicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButton<int>(
    value: value,
    isDense: true,
    items: [
      for (var n = 0; n < Fx200PedalScenes.sceneCount; n++)
        DropdownMenuItem<int>(value: n, child: Text(kSceneNames[n])),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

/// What one module looks like in one scene, for display.
class _Cell {
  _Cell(this.module, this.category, this.paramLabels);

  final Fx200SceneModule module;
  final EffectCategory category;
  final List<String> paramLabels;

  String get modelName {
    final models = Fx200Models.modelsFor(category);
    final i = module.modelId - 1;
    return i >= 0 && i < models.length ? models[i] : '#${module.modelId}';
  }

  bool sameAs(_Cell o) {
    if (o.module.enabled != module.enabled ||
        o.module.modelId != module.modelId) {
      return false;
    }
    for (var i = 0; i < module.params.length; i++) {
      if (o.module.params[i] != module.params[i]) return false;
    }
    return true;
  }
}

class _SceneTable extends StatelessWidget {
  const _SceneTable({
    required this.scenes,
    required this.active,
    required this.enabled,
    required this.onSelect,
  });

  final List<Fx200PedalScene> scenes;
  final int? active;
  final bool enabled;
  final ValueChanged<int> onSelect;

  static _Cell _cell(Fx200PedalScene scene, int slot) {
    final category = Fx200HardwareSync.categoryForSlot(slot);
    // Same parameter count as the module frames: the model's layout.
    final probe = scene.module(slot, 0);
    final models = Fx200Models.modelsFor(category);
    final i = probe.modelId - 1;
    final template = i >= 0 && i < models.length
        ? Fx200Models.parametersForModel(category, models[i])
        : null;
    final labels = <String>[for (final p in template ?? const []) p.label];
    return _Cell(scene.module(slot, labels.length), category, labels);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final text = Theme.of(context).textTheme;
    final cells = <List<_Cell>>[
      for (var slot = 0; slot < Fx200Protocol.moduleNames.length; slot++)
        [for (final s in scenes) _cell(s, slot)],
    ];

    Widget header(int n) {
      final isActive = n == active;
      final accent = ext.colorFor(EffectCategory.amp);
      return Padding(
        padding: const EdgeInsets.all(4),
        child: Tooltip(
          message: isActive
              ? tr('Scene being played')
              : tr('Play scene {0} on the pedal', [kSceneNames[n]]),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: isActive ? accent.withValues(alpha: 0.18) : null,
              side: BorderSide(color: isActive ? accent : ext.subtleBorder),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: enabled && !isActive ? () => onSelect(n) : null,
            child: Text(
              kSceneNames[n],
              style: text.labelLarge?.copyWith(
                color: isActive ? accent : ext.textPrimary,
              ),
            ),
          ),
        ),
      );
    }

    Widget cell(List<_Cell> row, int n) {
      final c = row[n];
      final differs = row.any((o) => !o.sameAs(c));
      final color = ext.colorFor(c.category);
      final changed = <String>[
        if (row.any((o) => o.module.enabled != c.module.enabled)) tr('on/off'),
        if (row.any((o) => o.module.modelId != c.module.modelId)) tr('model'),
        for (var i = 0; i < c.paramLabels.length; i++)
          if (row.any(
            (o) =>
                o.module.modelId == c.module.modelId &&
                i < o.module.params.length &&
                o.module.params[i] != c.module.params[i],
          ))
            c.paramLabels[i],
      ];
      return Tooltip(
        message: differs && changed.isNotEmpty
            ? tr('Differs in: {0}', [changed.join(', ')])
            : '',
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: differs ? color.withValues(alpha: 0.12) : ext.blockSurface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: differs ? color.withValues(alpha: 0.6) : ext.subtleBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                c.module.enabled ? Icons.circle : Icons.circle_outlined,
                size: 10,
                color: c.module.enabled ? color : ext.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.modelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: c.module.enabled ? ext.textPrimary : ext.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Table(
      columnWidths: const <int, TableColumnWidth>{0: FixedColumnWidth(84)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            for (var n = 0; n < scenes.length; n++) header(n),
          ],
        ),
        for (var slot = 0; slot < cells.length; slot++)
          TableRow(
            children: [
              Text(Fx200Protocol.moduleNames[slot], style: text.labelSmall),
              for (var n = 0; n < scenes.length; n++) cell(cells[slot], n),
            ],
          ),
      ],
    );
  }
}
