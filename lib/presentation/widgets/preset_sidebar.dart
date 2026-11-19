import 'package:material_ui/material_ui.dart';

import '../../core/fx200_constants.dart';
import '../../core/fx200_models.dart';
import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../core/l10n/l10n.dart';

/// Left sidebar listing all 200 FX200 presets with real hardware names,
/// live search filtering, one-click loading, copy / paste (buttons or
/// right-click menu) and drag-and-drop reordering via the row handles.
class PresetSidebar extends StatefulWidget {
  const PresetSidebar({
    super.key,
    required this.activePatchNumber,
    required this.presetNames,
    required this.onSelectPreset,
    this.isSyncing = false,
    this.canEditPresets = false,
    this.clipboardLabel,
    this.onCopyPreset,
    this.onPastePreset,
    this.onClearPreset,
    this.onMovePreset,
    this.onExportPresets,
    this.onImportPresets,
    this.opsBusy = false,
    this.opsProgress = 0,
    this.opsMessage,
    this.opsIsError = false,
    this.onDismissOpsMessage,
  });

  final int activePatchNumber;
  final Map<int, String> presetNames;
  final ValueChanged<int> onSelectPreset;
  final bool isSyncing;

  /// True when the pedal is connected and no operation is running.
  final bool canEditPresets;

  /// `"012 NAME"` of the copied preset, or null when the clipboard is empty.
  final String? clipboardLabel;
  final ValueChanged<int>? onCopyPreset;
  final ValueChanged<int>? onPastePreset;
  final ValueChanged<int>? onClearPreset;
  final void Function(int from, int to)? onMovePreset;

  /// Exports the given presets as `.pfl` files (the caller picks a folder).
  final ValueChanged<List<int>>? onExportPresets;

  /// Imports `.pfl` files into consecutive slots starting at the given one
  /// (the caller picks the files and confirms).
  final ValueChanged<int>? onImportPresets;
  final bool opsBusy;
  final double opsProgress;
  final String? opsMessage;
  final bool opsIsError;
  final VoidCallback? onDismissOpsMessage;

  @override
  State<PresetSidebar> createState() => _PresetSidebarState();
}

class _PresetSidebarState extends State<PresetSidebar> {
  String _query = '';

  String _nameOf(int i) {
    final n = widget.presetNames[i];
    return (n != null && n.isNotEmpty) ? n : Fx200Models.defaultPresetName(i);
  }

  static String _pad(int i) => i.toString().padLeft(3, '0');

  bool get _canPaste =>
      widget.canEditPresets &&
      widget.clipboardLabel != null &&
      widget.onPastePreset != null;

  Future<bool> _confirm(String title, String body, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('CANCEL')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _paste(int target) async {
    if (!_canPaste) return;
    final ok = await _confirm(
      tr('Paste preset'),
      tr('Overwrite {0} "{1}" on the pedal with {2}?', [
        _pad(target),
        _nameOf(target),
        widget.clipboardLabel,
      ]),
      'OVERWRITE',
    );
    if (ok) widget.onPastePreset!(target);
  }

  bool get _canClear => widget.canEditPresets && widget.onClearPreset != null;

  Future<void> _clear(int index) async {
    if (!_canClear) return;
    final ok = await _confirm(
      tr('Clear preset'),
      tr(
        'Clear {0} "{1}" on the pedal?\n\nAll modules are switched off, the chain order and footswitch are reset, the EXP assignment is removed and it is renamed "Empty". Copy it first if you may want it back.',
        [_pad(index), _nameOf(index)],
      ),
      'CLEAR',
    );
    if (ok) widget.onClearPreset!(index);
  }

  Future<void> _move(int from, int to) async {
    if (from == to || widget.onMovePreset == null) return;
    final count = (from - to).abs() + 1;
    final seconds = (count * 1.4).ceil();
    final shift = from < to
        ? tr('Presets {0}–{1} move up one slot.', [_pad(from + 1), _pad(to)])
        : tr('Presets {0}–{1} move down one slot.', [_pad(to), _pad(from - 1)]);
    final ok = await _confirm(
      tr('Move preset'),
      tr(
        'Move {0} "{1}" to position {2}?\n\n{3} This reads and rewrites {4} presets on the pedal (about {5} s). Do not unplug the pedal meanwhile.',
        [_pad(from), _nameOf(from), _pad(to), shift, count, seconds],
      ),
      'MOVE',
    );
    if (ok) widget.onMovePreset!(from, to);
  }

  bool get _canTransfer => widget.canEditPresets;

  /// Multi-selection of presets to export (Software Guide p. 12: CTRL-click
  /// several presets and drag them to the computer area).
  Future<void> _pickPresetsToExport() async {
    final selected = <int>{widget.activePatchNumber};
    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(tr('Export presets (.pfl)')),
          content: SizedBox(
            width: 360,
            height: 420,
            child: Column(
              children: [
                Row(
                  children: [
                    Text(tr('{0} selected', [selected.length])),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setLocal(() {
                        selected.addAll(
                          List<int>.generate(
                            Fx200Constants.presetPatchCount,
                            (i) => i,
                          ),
                        );
                      }),
                      child: Text(tr('ALL')),
                    ),
                    TextButton(
                      onPressed: () => setLocal(selected.clear),
                      child: Text(tr('NONE')),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: Fx200Constants.presetPatchCount,
                    itemBuilder: (_, i) => CheckboxListTile(
                      dense: true,
                      value: selected.contains(i),
                      title: Text('${_pad(i)}  ${_nameOf(i)}'),
                      onChanged: (v) => setLocal(() {
                        if (v ?? false) {
                          selected.add(i);
                        } else {
                          selected.remove(i);
                        }
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('CANCEL')),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(ctx).pop(selected.toList()..sort()),
              child: Text(tr('EXPORT...')),
            ),
          ],
        ),
      ),
    );
    if (result != null && result.isNotEmpty) {
      widget.onExportPresets?.call(result);
    }
  }

  Future<void> _showContextMenu(Offset globalPosition, int index) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy',
          enabled: widget.canEditPresets && widget.onCopyPreset != null,
          child: Text(tr('Copy {0}', [_pad(index)])),
        ),
        PopupMenuItem<String>(
          value: 'paste',
          enabled: _canPaste,
          child: Text(
            widget.clipboardLabel == null
                ? tr('Paste here')
                : tr('Paste {0} here', [widget.clipboardLabel]),
          ),
        ),
        PopupMenuItem<String>(
          value: 'clear',
          enabled: _canClear,
          child: Text(tr('Clear {0}...', [_pad(index)])),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'export',
          enabled: _canTransfer && widget.onExportPresets != null,
          child: Text(tr('Export {0} to .pfl...', [_pad(index)])),
        ),
        PopupMenuItem<String>(
          value: 'import',
          enabled: _canTransfer && widget.onImportPresets != null,
          child: Text(tr('Import .pfl here...')),
        ),
      ],
    );
    if (selected == 'export') widget.onExportPresets?.call(<int>[index]);
    if (selected == 'import') widget.onImportPresets?.call(index);
    if (selected == 'clear') await _clear(index);
    if (selected == 'copy') widget.onCopyPreset?.call(index);
    if (selected == 'paste') await _paste(index);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final accent = ext.colorFor(EffectCategory.amp);
    final q = _query.trim().toLowerCase();

    final visibleIndices = <int>[];
    for (var i = 0; i < Fx200Constants.presetPatchCount; i++) {
      final name = widget.presetNames[i] ?? Fx200Models.defaultPresetName(i);
      final numStr = i.toString().padLeft(3, '0');
      if (q.isEmpty || name.toLowerCase().contains(q) || numStr.contains(q)) {
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
                Expanded(
                  child: Text(
                    tr('PRESETS'),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (widget.onExportPresets != null)
                  IconButton(
                    tooltip: tr('Export presets to .pfl files'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 26,
                      height: 26,
                    ),
                    iconSize: 16,
                    onPressed: _canTransfer ? _pickPresetsToExport : null,
                    icon: const Icon(Icons.file_download_outlined),
                  ),
                if (widget.onImportPresets != null)
                  IconButton(
                    tooltip: tr(
                      'Import .pfl files into the active slot onwards',
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 26,
                      height: 26,
                    ),
                    iconSize: 16,
                    onPressed: _canTransfer
                        ? () =>
                              widget.onImportPresets!(widget.activePatchNumber)
                        : null,
                    icon: const Icon(Icons.file_upload_outlined),
                  ),
                const SizedBox(width: 4),
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
                hintText: tr('Search presets...'),
                prefixIcon: Icon(Icons.search, size: 16, color: ext.textMuted),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: _smallButton,
                    onPressed:
                        widget.canEditPresets && widget.onCopyPreset != null
                        ? () => widget.onCopyPreset!(widget.activePatchNumber)
                        : null,
                    icon: const Icon(Icons.copy, size: 14),
                    label: Text(tr('COPY')),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton.icon(
                    style: _smallButton,
                    onPressed: _canPaste
                        ? () => _paste(widget.activePatchNumber)
                        : null,
                    icon: const Icon(Icons.content_paste, size: 14),
                    label: Text(tr('PASTE')),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: tr('Clear the active preset'),
                  child: OutlinedButton(
                    style: _smallButton.copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(34, 30)),
                    ),
                    onPressed: _canClear
                        ? () => _clear(widget.activePatchNumber)
                        : null,
                    child: const Icon(Icons.delete_sweep_outlined, size: 16),
                  ),
                ),
              ],
            ),
          ),
          if (widget.clipboardLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Text(
                tr('Clipboard: {0}', [widget.clipboardLabel]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: ext.textMuted, fontSize: 10),
              ),
            ),
          if (widget.opsBusy || widget.opsMessage != null)
            _OpsStatus(
              busy: widget.opsBusy,
              progress: widget.opsProgress,
              message: widget.opsMessage ?? '',
              isError: widget.opsIsError,
              onDismiss: widget.onDismissOpsMessage,
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              itemCount: visibleIndices.length,
              // newIndex is already adjusted for the removed item.
              onReorderItem: (oldIndex, newIndex) {
                if (newIndex == oldIndex) return;
                _move(visibleIndices[oldIndex], visibleIndices[newIndex]);
              },
              itemBuilder: (context, idx) {
                final patchIndex = visibleIndices[idx];
                final canDrag =
                    widget.canEditPresets && widget.onMovePreset != null;
                final isSelected = patchIndex == widget.activePatchNumber;
                final hwName = widget.presetNames[patchIndex];
                final displayName = (hwName != null && hwName.isNotEmpty)
                    ? hwName
                    : Fx200Models.defaultPresetName(patchIndex);

                return Padding(
                  key: ValueKey<int>(patchIndex),
                  padding: const EdgeInsets.only(bottom: 4),
                  child: GestureDetector(
                    onSecondaryTapDown: (d) =>
                        _showContextMenu(d.globalPosition, patchIndex),
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
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: isSelected
                                          ? accent
                                          : ext.textMuted,
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
                                style: Theme.of(context).textTheme.bodySmall
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
                            if (canDrag)
                              ReorderableDragStartListener(
                                index: idx,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: Tooltip(
                                    message: tr('Drag to move this preset'),
                                    waitDuration: const Duration(
                                      milliseconds: 600,
                                    ),
                                    child: Icon(
                                      Icons.drag_indicator,
                                      size: 16,
                                      color: ext.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
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

final ButtonStyle _smallButton = OutlinedButton.styleFrom(
  visualDensity: VisualDensity.compact,
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  textStyle: const TextStyle(fontSize: 11),
);

class _OpsStatus extends StatelessWidget {
  const _OpsStatus({
    required this.busy,
    required this.progress,
    required this.message,
    required this.isError,
    this.onDismiss,
  });

  final bool busy;
  final double progress;
  final String message;
  final bool isError;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final color = isError
        ? ext.meterPeak
        : (busy ? ext.textPrimary : ext.meterLow);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: LinearProgressIndicator(
                minHeight: 3,
                value: progress > 0 ? progress : null,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: color, fontSize: 10),
                ),
              ),
              if (!busy && onDismiss != null)
                InkWell(
                  onTap: onDismiss,
                  child: Icon(Icons.close, size: 12, color: ext.textMuted),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
