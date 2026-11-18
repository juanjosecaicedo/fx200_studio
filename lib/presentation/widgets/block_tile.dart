import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import 'model_art_view.dart';

/// Draggable hardware-styled effect block tile for [SignalChainView].
class BlockTile extends StatelessWidget {
  const BlockTile({
    super.key,
    required this.block,
    required this.isSelected,
    required this.onSelect,
    required this.onToggleBypass,
    this.onRemove,
  });

  final EffectBlock block;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onToggleBypass;
  final VoidCallback? onRemove;

  static IconData iconFor(EffectCategory category) {
    switch (category) {
      case EffectCategory.gate:
        return Icons.shield_outlined;
      case EffectCategory.compressor:
        return Icons.compress;
      case EffectCategory.drive:
        return Icons.local_fire_department_outlined;
      case EffectCategory.amp:
        return Icons.speaker_group_outlined;
      case EffectCategory.cab:
        return Icons.surround_sound_outlined;
      case EffectCategory.eq:
        return Icons.equalizer;
      case EffectCategory.modulation:
        return Icons.waves;
      case EffectCategory.delay:
        return Icons.graphic_eq;
      case EffectCategory.reverb:
        return Icons.blur_on;
      case EffectCategory.volume:
        return Icons.volume_up_outlined;
    }
  }

  static String shortLabelFor(EffectCategory category) {
    switch (category) {
      case EffectCategory.gate:
        return 'GATE';
      case EffectCategory.compressor:
        return 'COMP';
      case EffectCategory.drive:
        return 'DRIVE';
      case EffectCategory.amp:
        return 'AMP';
      case EffectCategory.cab:
        return 'CAB';
      case EffectCategory.eq:
        return 'EQ';
      case EffectCategory.modulation:
        return 'MOD';
      case EffectCategory.delay:
        return 'DELAY';
      case EffectCategory.reverb:
        return 'REVERB';
      case EffectCategory.volume:
        return 'VOL';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final accent = ext.colorFor(block.category);

    final tile = _TileBody(
      block: block,
      accent: accent,
      ext: ext,
      isSelected: isSelected,
      onSelect: onSelect,
      onToggleBypass: onToggleBypass,
      onRemove: onRemove,
    );

    return Draggable<Object>(
      data: block,
      feedback: Material(
        color: ext.panelSurface.withValues(alpha: 0.0),
        child: Opacity(opacity: 0.9, child: tile),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: tile),
      child: tile,
    );
  }
}

class _TileBody extends StatelessWidget {
  const _TileBody({
    required this.block,
    required this.accent,
    required this.ext,
    required this.isSelected,
    required this.onSelect,
    required this.onToggleBypass,
    this.onRemove,
  });

  final EffectBlock block;
  final Color accent;
  final FxEditorThemeExtension ext;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onToggleBypass;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = block.enabled ? accent : ext.textMuted;

    return GestureDetector(
      onTap: onSelect,
      onDoubleTap: onToggleBypass,
      child: AnimatedContainer(
        duration: ext.transitionDuration,
        curve: Curves.easeOutCubic,
        width: 112,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? ext.elevatedSurface : ext.blockSurface,
          borderRadius: BorderRadius.circular(ext.blockRadius),
          border: Border.all(
            color: isSelected ? accent : ext.subtleBorder,
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: ext.glowFor(accent, active: isSelected),
        ),
        child: AnimatedOpacity(
          duration: ext.transitionDuration,
          opacity: block.enabled ? 1.0 : 0.48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: effectiveAccent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      BlockTile.iconFor(block.category),
                      size: 14,
                      color: effectiveAccent,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: onToggleBypass,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: block.enabled ? accent : ext.subtleBorder,
                          boxShadow: ext.glowFor(accent, active: block.enabled),
                        ),
                      ),
                    ),
                  ),
                  if (onRemove != null) ...[
                    const SizedBox(width: 2),
                    InkWell(
                      onTap: onRemove,
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: ext.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              ModelArtView(
                category: block.category,
                modelName: block.modelName,
                width: double.infinity,
                height: 44,
              ),
              const SizedBox(height: 4),
              Text(
                BlockTile.shortLabelFor(block.category),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: effectiveAccent,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                block.modelName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: ext.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
