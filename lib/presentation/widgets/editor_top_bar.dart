import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';

/// Top hardware control bar: patch/scene selector, editable preset name,
/// unsaved indicator, undo/redo, save, and model-browser toggle.
class EditorTopBar extends StatefulWidget {
  const EditorTopBar({
    super.key,
    required this.preset,
    required this.hasUnsavedChanges,
    required this.canUndo,
    required this.canRedo,
    required this.isBrowserOpen,
    required this.onSelectPatch,
    required this.onRenamePreset,
    required this.onSelectScene,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onToggleBrowser,
    this.isPresetSidebarOpen = true,
    this.onTogglePresetSidebar,
    this.onOpenSystem,
    this.onOpenFootswitch,
    this.onOpenBackup,
  });

  final Preset preset;
  final bool hasUnsavedChanges;
  final bool canUndo;
  final bool canRedo;
  final bool isBrowserOpen;
  final bool isPresetSidebarOpen;
  final ValueChanged<int> onSelectPatch;
  final ValueChanged<String> onRenamePreset;
  final ValueChanged<String> onSelectScene;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSave;
  final VoidCallback onToggleBrowser;
  final VoidCallback? onTogglePresetSidebar;
  final VoidCallback? onOpenSystem;
  final VoidCallback? onOpenFootswitch;
  final VoidCallback? onOpenBackup;

  @override
  State<EditorTopBar> createState() => _EditorTopBarState();
}

class _EditorTopBarState extends State<EditorTopBar> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocusNode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.preset.name);
    _nameFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant EditorTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final patchChanged =
        oldWidget.preset.patchNumber != widget.preset.patchNumber;
    final nameChanged = oldWidget.preset.name != widget.preset.name;
    if ((patchChanged || (nameChanged && !_nameFocusNode.hasFocus)) &&
        _nameController.text != widget.preset.name) {
      _nameController.text = widget.preset.name;
    }
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final ampColor = ext.colorFor(EffectCategory.amp);
    final driveColor = ext.colorFor(EffectCategory.drive);
    final delayColor = ext.colorFor(EffectCategory.delay);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ext.panelSurface,
        border: Border(bottom: BorderSide(color: ext.subtleBorder)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Patch selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: ext.blockSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: ext.subtleBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 16),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.preset.patchNumber > 0
                      ? () =>
                            widget.onSelectPatch(widget.preset.patchNumber - 1)
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  'PATCH ${widget.preset.patchNumber.toString().padLeft(3, '0')}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: ext.textPrimary),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 16),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: widget.preset.patchNumber < 199
                      ? () =>
                            widget.onSelectPatch(widget.preset.patchNumber + 1)
                      : null,
                ),
              ],
            ),
          ),

          // Editable preset name (FX200 supports up to 15 ASCII characters)
          SizedBox(
            width: 220,
            child: TextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              maxLength: 15,
              onChanged: widget.onRenamePreset,
              onSubmitted: (value) {
                widget.onRenamePreset(value);
                widget.onSave();
              },
              style: Theme.of(context).textTheme.titleSmall,
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
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

          if (widget.hasUnsavedChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: driveColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: driveColor.withValues(alpha: 0.6)),
              ),
              child: Text(
                'UNSAVED',
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: driveColor),
              ),
            ),

          // Scenes A-H (Quad Cortex style)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final scene in const <String>[
                'A',
                'B',
                'C',
                'D',
                'E',
                'F',
                'G',
                'H',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    onTap: () => widget.onSelectScene(scene),
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedContainer(
                      duration: ext.transitionDuration,
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.preset.activeScene == scene
                            ? delayColor.withValues(alpha: 0.24)
                            : ext.blockSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.preset.activeScene == scene
                              ? delayColor
                              : ext.subtleBorder,
                        ),
                      ),
                      child: Text(
                        scene,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: widget.preset.activeScene == scene
                              ? ext.textPrimary
                              : ext.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Undo / Redo / Save / Models browser toggle
          IconButton(
            tooltip: 'Undo',
            icon: Icon(
              Icons.undo,
              size: 18,
              color: widget.canUndo ? ext.textPrimary : ext.textMuted,
            ),
            onPressed: widget.canUndo ? widget.onUndo : null,
          ),
          IconButton(
            tooltip: 'Redo',
            icon: Icon(
              Icons.redo,
              size: 18,
              color: widget.canRedo ? ext.textPrimary : ext.textMuted,
            ),
            onPressed: widget.canRedo ? widget.onRedo : null,
          ),
          FilledButton.icon(
            onPressed: widget.onSave,
            style: FilledButton.styleFrom(
              backgroundColor: ampColor,
              foregroundColor: ext.chassisBackground,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('SAVE'),
          ),
          if (widget.onTogglePresetSidebar != null)
            OutlinedButton.icon(
              onPressed: widget.onTogglePresetSidebar,
              icon: Icon(
                widget.isPresetSidebarOpen
                    ? Icons.list_alt
                    : Icons.list_alt_outlined,
                size: 16,
              ),
              label: const Text('PRESETS'),
            ),
          OutlinedButton.icon(
            onPressed: widget.onToggleBrowser,
            icon: Icon(
              widget.isBrowserOpen
                  ? Icons.view_sidebar
                  : Icons.view_sidebar_outlined,
              size: 16,
            ),
            label: const Text('MODELS'),
          ),
          if (widget.onOpenFootswitch != null)
            OutlinedButton.icon(
              onPressed: widget.onOpenFootswitch,
              icon: const Icon(Icons.radio_button_checked, size: 16),
              label: const Text('FOOTSWITCH'),
            ),
          if (widget.onOpenSystem != null)
            OutlinedButton.icon(
              onPressed: widget.onOpenSystem,
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('SYSTEM'),
            ),
          if (widget.onOpenBackup != null)
            OutlinedButton.icon(
              onPressed: widget.onOpenBackup,
              icon: const Icon(Icons.backup_outlined, size: 16),
              label: const Text('BACKUP'),
            ),
        ],
      ),
    );
  }
}
