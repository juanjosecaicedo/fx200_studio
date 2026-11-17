import 'package:material_ui/material_ui.dart';

import '../../core/fx200_constants.dart';
import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';

/// Left sidebar listing all 200 FX200 presets with real hardware names,
/// live search filtering, and one-click loading into the editor.
class PresetSidebar extends StatefulWidget {
  const PresetSidebar({
    super.key,
    required this.activePatchNumber,
    required this.presetNames,
    required this.onSelectPreset,
    this.isSyncing = false,
  });

  final int activePatchNumber;
  final Map<int, String> presetNames;
  final ValueChanged<int> onSelectPreset;
  final bool isSyncing;

  @override
  State<PresetSidebar> createState() => _PresetSidebarState();
}

class _PresetSidebarState extends State<PresetSidebar> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final accent = ext.colorFor(EffectCategory.amp);
    final q = _query.trim().toLowerCase();

    final visibleIndices = <int>[];
    for (var i = 0; i < Fx200Constants.presetPatchCount; i++) {
      final name = widget.presetNames[i] ?? 'FX200 Patch #$i';
      final numStr = i.toString().padLeft(3, '0');
      if (q.isEmpty ||
          name.toLowerCase().contains(q) ||
          numStr.contains(q)) {
        visibleIndices.add(i);
      }
    }

    return Container(
      width: 230,
      decoration: BoxDecoration(
        color: ext.panelSurface,
        border: Border(right: BorderSide(color: ext.subtleBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Text(
                  'PRESETS',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                Text(
                  widget.isSyncing
                      ? 'SYNC ${widget.presetNames.length}/${Fx200Constants.presetPatchCount}'
                      : '${widget.presetNames.length}/${Fx200Constants.presetPatchCount}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: widget.isSyncing ? accent : ext.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (widget.isSyncing)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: widget.presetNames.isEmpty
                      ? null
                      : widget.presetNames.length /
                          Fx200Constants.presetPatchCount,
                  backgroundColor: ext.blockSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search presets...',
                prefixIcon: Icon(
                  Icons.search,
                  size: 16,
                  color: ext.textMuted,
                ),
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
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              itemCount: visibleIndices.length,
              itemBuilder: (context, idx) {
                final patchIndex = visibleIndices[idx];
                final isSelected = patchIndex == widget.activePatchNumber;
                final hwName = widget.presetNames[patchIndex];
                final displayName = (hwName != null && hwName.isNotEmpty)
                    ? hwName
                    : 'FX200 Patch #$patchIndex';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: () => widget.onSelectPreset(patchIndex),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent.withValues(alpha: 0.16)
                            : ext.blockSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? accent : ext.subtleBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withValues(alpha: 0.25)
                                  : ext.panelSurface,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              patchIndex.toString().padLeft(3, '0'),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        isSelected ? accent : ext.textMuted,
                                    fontSize: 10,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: isSelected
                                        ? ext.textPrimary
                                        : (hwName != null
                                            ? ext.textPrimary
                                            : ext.textMuted),
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
