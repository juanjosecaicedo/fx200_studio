import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import 'block_tile.dart';

/// Collapsible side browser listing available DSP models by category
/// with live search and drag-to-chain support.
class ModelBrowser extends StatelessWidget {
  const ModelBrowser({
    super.key,
    required this.catalog,
    required this.searchQuery,
    required this.categoryFilter,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onAddModel,
  });

  final List<CatalogModel> catalog;
  final String searchQuery;
  final EffectCategory? categoryFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<EffectCategory?> onCategoryChanged;
  final ValueChanged<CatalogModel> onAddModel;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final query = searchQuery.trim().toLowerCase();

    final filtered = catalog.where((m) {
      if (categoryFilter != null && m.category != categoryFilter) return false;
      if (query.isEmpty) return true;
      return m.name.toLowerCase().contains(query) ||
          m.description.toLowerCase().contains(query);
    }).toList();

    final categories = catalog.map((c) => c.category).toSet().toList();

    return Container(
      width: 268,
      decoration: BoxDecoration(
        color: ext.panelSurface,
        border: Border(left: BorderSide(color: ext.subtleBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODEL BROWSER',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  onChanged: onSearchChanged,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ext.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search models...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    filled: true,
                    fillColor: ext.blockSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: ext.subtleBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: ext.subtleBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'ALL',
                        selected: categoryFilter == null,
                        accent: ext.textPrimary,
                        ext: ext,
                        onTap: () => onCategoryChanged(null),
                      ),
                      for (final cat in categories)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: _FilterChip(
                            label: BlockTile.shortLabelFor(cat),
                            selected: categoryFilter == cat,
                            accent: ext.colorFor(cat),
                            ext: ext,
                            onTap: () => onCategoryChanged(cat),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: ext.subtleBorder),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(10),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final model = filtered[index];
                final accent = ext.colorFor(model.category);
                final card = _CatalogItemCard(
                  model: model,
                  accent: accent,
                  ext: ext,
                  onAdd: () => onAddModel(model),
                );
                return Draggable<Object>(
                  data: model,
                  feedback: Material(
                    color: ext.panelSurface.withValues(alpha: 0.0),
                    child: SizedBox(width: 240, child: card),
                  ),
                  child: card,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.ext,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final FxEditorThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: ext.transitionDuration,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.2) : ext.blockSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? accent : ext.subtleBorder,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected ? accent : ext.textMuted,
          ),
        ),
      ),
    );
  }
}

class _CatalogItemCard extends StatelessWidget {
  const _CatalogItemCard({
    required this.model,
    required this.accent,
    required this.ext,
    required this.onAdd,
  });

  final CatalogModel model;
  final Color accent;
  final FxEditorThemeExtension ext;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ext.blockSurface,
        borderRadius: BorderRadius.circular(ext.blockRadius),
        border: Border.all(color: ext.subtleBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              BlockTile.iconFor(model.category),
              size: 14,
              color: accent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ext.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  model.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.2,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Add to signal chain',
            icon: Icon(Icons.add_circle_outline, size: 18, color: accent),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
