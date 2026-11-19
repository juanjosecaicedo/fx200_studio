import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import 'block_tile.dart';
import '../../core/l10n/l10n.dart';

/// Horizontal hardware signal chain supporting drag-and-drop reordering and
/// `+` empty slots. The FX200 chain is a single serial lane (its only
/// parallel path is the FX LOOP module's PARALLEL mode).
class SignalChainView extends StatelessWidget {
  const SignalChainView({
    super.key,
    required this.preset,
    required this.selectedBlockId,
    required this.catalog,
    required this.onSelectBlock,
    required this.onToggleBypass,
    required this.onReorderBlock,
    required this.onAddFromCatalog,
    this.onRemoveBlock,
  });

  final Preset preset;
  final String? selectedBlockId;
  final List<CatalogModel> catalog;
  final ValueChanged<String> onSelectBlock;
  final ValueChanged<String> onToggleBypass;
  final void Function(String blockId, int targetLane, int targetSlot)
  onReorderBlock;
  final void Function(CatalogModel model, int targetLane, int targetSlot)
  onAddFromCatalog;
  final ValueChanged<String>? onRemoveBlock;

  List<EffectBlock> get _chain {
    final list = preset.blocks.toList()
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final chain = _chain;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ext.panelSurface,
        borderRadius: BorderRadius.circular(ext.panelRadius),
        border: Border.all(color: ext.subtleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('SIGNAL CHAIN'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _EndpointNode(label: tr('INPUT'), icon: Icons.login, ext: ext),
                _WireSegment(ext: ext),
                _LaneRow(
                  laneIndex: 0,
                  laneLabel: null,
                  blocks: chain,
                  selectedBlockId: selectedBlockId,
                  catalog: catalog,
                  ext: ext,
                  onSelectBlock: onSelectBlock,
                  onToggleBypass: onToggleBypass,
                  onReorderBlock: onReorderBlock,
                  onAddFromCatalog: onAddFromCatalog,
                  onRemoveBlock: onRemoveBlock,
                ),
                _WireSegment(ext: ext),
                _EndpointNode(
                  label: tr('OUTPUT'),
                  icon: Icons.logout,
                  ext: ext,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LaneRow extends StatelessWidget {
  const _LaneRow({
    required this.laneIndex,
    required this.laneLabel,
    required this.blocks,
    required this.selectedBlockId,
    required this.catalog,
    required this.ext,
    required this.onSelectBlock,
    required this.onToggleBypass,
    required this.onReorderBlock,
    required this.onAddFromCatalog,
    this.onRemoveBlock,
  });

  final int laneIndex;
  final String? laneLabel;
  final List<EffectBlock> blocks;
  final String? selectedBlockId;
  final List<CatalogModel> catalog;
  final FxEditorThemeExtension ext;
  final ValueChanged<String> onSelectBlock;
  final ValueChanged<String> onToggleBypass;
  final void Function(String blockId, int targetLane, int targetSlot)
  onReorderBlock;
  final void Function(CatalogModel model, int targetLane, int targetSlot)
  onAddFromCatalog;
  final ValueChanged<String>? onRemoveBlock;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (laneLabel != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: ext.blockSurface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: ext.subtleBorder),
            ),
            child: Text(
              laneLabel!,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          _WireSegment(ext: ext),
        ],
        for (var i = 0; i < blocks.length; i++) ...[
          _DropInsertZone(
            laneIndex: laneIndex,
            slotIndex: i,
            ext: ext,
            onDropBlock: (b) {
              final target = (b.laneIndex == laneIndex && b.slotIndex < i)
                  ? i - 1
                  : i;
              onReorderBlock(b.id, laneIndex, target);
            },
            onDropCatalog: (m) => onAddFromCatalog(m, laneIndex, i),
          ),
          DragTarget<Object>(
            onAcceptWithDetails: (details) {
              final data = details.data;
              if (data is EffectBlock && data.id != blocks[i].id) {
                onReorderBlock(data.id, laneIndex, i);
              } else if (data is CatalogModel) {
                onAddFromCatalog(data, laneIndex, i);
              }
            },
            builder: (context, candidateData, _) {
              final hovered = candidateData.isNotEmpty;
              return Container(
                decoration: hovered
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          ext.blockRadius + 2,
                        ),
                        border: Border.all(
                          color: ext.colorFor(EffectCategory.delay),
                          width: 2,
                        ),
                      )
                    : null,
                child: BlockTile(
                  block: blocks[i],
                  isSelected: blocks[i].id == selectedBlockId,
                  onSelect: () => onSelectBlock(blocks[i].id),
                  onToggleBypass: () => onToggleBypass(blocks[i].id),
                  onRemove: onRemoveBlock == null
                      ? null
                      : () => onRemoveBlock!(blocks[i].id),
                ),
              );
            },
          ),
        ],
        _DropInsertZone(
          laneIndex: laneIndex,
          slotIndex: blocks.length,
          ext: ext,
          onDropBlock: (b) {
            final target =
                (b.laneIndex == laneIndex && b.slotIndex < blocks.length)
                ? blocks.length - 1
                : blocks.length;
            onReorderBlock(b.id, laneIndex, target);
          },
          onDropCatalog: (m) => onAddFromCatalog(m, laneIndex, blocks.length),
        ),
        _AddBlockSlot(
          ext: ext,
          catalog: catalog,
          onSelected: (model) =>
              onAddFromCatalog(model, laneIndex, blocks.length),
        ),
      ],
    );
  }
}

class _DropInsertZone extends StatelessWidget {
  const _DropInsertZone({
    required this.laneIndex,
    required this.slotIndex,
    required this.ext,
    required this.onDropBlock,
    required this.onDropCatalog,
  });

  final int laneIndex;
  final int slotIndex;
  final FxEditorThemeExtension ext;
  final ValueChanged<EffectBlock> onDropBlock;
  final ValueChanged<CatalogModel> onDropCatalog;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Object>(
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is EffectBlock) {
          onDropBlock(data);
        } else if (data is CatalogModel) {
          onDropCatalog(data);
        }
      },
      builder: (context, candidateData, _) {
        final hovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: ext.transitionDuration,
          width: hovered ? 28 : 14,
          height: 62,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: hovered
                ? ext.colorFor(EffectCategory.delay).withValues(alpha: 0.25)
                : ext.subtleBorder.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(6),
            border: hovered
                ? Border.all(color: ext.colorFor(EffectCategory.delay))
                : null,
          ),
          child: hovered
              ? Icon(
                  Icons.add,
                  size: 14,
                  color: ext.colorFor(EffectCategory.delay),
                )
              : Center(child: Container(height: 2, color: ext.subtleBorder)),
        );
      },
    );
  }
}

class _AddBlockSlot extends StatelessWidget {
  const _AddBlockSlot({
    required this.ext,
    required this.catalog,
    required this.onSelected,
  });

  final FxEditorThemeExtension ext;
  final List<CatalogModel> catalog;
  final ValueChanged<CatalogModel> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CatalogModel>(
      tooltip: tr('Add effect block'),
      color: ext.elevatedSurface,
      onSelected: onSelected,
      itemBuilder: (context) => catalog
          .map(
            (m) => PopupMenuItem<CatalogModel>(
              value: m,
              child: Row(
                children: [
                  Icon(
                    BlockTile.iconFor(m.category),
                    size: 16,
                    color: ext.colorFor(m.category),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    m.name,
                    style: TextStyle(color: ext.textPrimary, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        width: 44,
        height: 68,
        decoration: BoxDecoration(
          color: ext.blockSurface,
          borderRadius: BorderRadius.circular(ext.blockRadius),
          border: Border.all(color: ext.subtleBorder),
        ),
        child: Icon(Icons.add, color: ext.textMuted, size: 18),
      ),
    );
  }
}

class _EndpointNode extends StatelessWidget {
  const _EndpointNode({
    required this.label,
    required this.icon,
    required this.ext,
  });

  final String label;
  final IconData icon;
  final FxEditorThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: ext.blockSurface,
        borderRadius: BorderRadius.circular(ext.blockRadius),
        border: Border.all(color: ext.subtleBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ext.textMuted),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _WireSegment extends StatelessWidget {
  const _WireSegment({required this.ext});

  final FxEditorThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(width: 14, height: 2, color: ext.subtleBorder);
  }
}
