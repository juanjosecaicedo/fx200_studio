import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../core/l10n/l10n.dart';

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
    this.onSelectScene,
    this.onSaveScene,
    this.onClearScene,
    this.activeScene,
    this.filledScenes = const <String>{},
    this.activeSceneModified = false,
    this.scenesDisabledReason,
    this.scenesTooltip,
    this.onCompareScenes,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onToggleBrowser,
    this.isPresetSidebarOpen = true,
    this.onTogglePresetSidebar,
    this.onOpenSystem,
    this.onOpenFootswitch,
    this.onOpenExpPedal,
    this.onOpenDrum,
    this.onOpenIr,
    this.onOpenFirmware,
    this.language,
    this.onLanguageChanged,
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

  /// Scene mode (4 scenes, A-D) needs the custom firmware; until then this is
  /// null and the scene buttons render disabled.
  final ValueChanged<String>? onSelectScene;
  final ValueChanged<String>? onSaveScene;
  final ValueChanged<String>? onClearScene;

  /// Scene currently applied (null = none), scenes holding a sound, and
  /// whether the sound changed since the active scene was applied / saved.
  final String? activeScene;
  final Set<String> filledScenes;
  final bool activeSceneModified;

  /// Why the scene buttons are disabled (e.g. the pedal handles scenes
  /// itself); null = generic "not supported" text.
  final String? scenesDisabledReason;

  /// Tooltip of the enabled scene buttons (default: app-side scenes).
  final String? scenesTooltip;

  /// Opens the scene comparison (pedal scenes); adds a menu entry.
  final VoidCallback? onCompareScenes;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSave;
  final VoidCallback onToggleBrowser;
  final VoidCallback? onTogglePresetSidebar;
  final VoidCallback? onOpenSystem;
  final VoidCallback? onOpenFootswitch;
  final VoidCallback? onOpenExpPedal;
  final VoidCallback? onOpenDrum;
  final VoidCallback? onOpenIr;
  final VoidCallback? onOpenFirmware;

  /// Display language and its selector (Software Guide p. 4).
  final AppLanguage? language;
  final ValueChanged<AppLanguage>? onLanguageChanged;
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

  /// Highlighted only while scene mode is available.
  bool _sceneActive(String scene) =>
      widget.onSelectScene != null && widget.activeScene == scene;

  Future<void> _sceneMenu(String scene, Offset at) async {
    final filled = widget.filledScenes.contains(scene);
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        PopupMenuItem<String>(
          value: 'save',
          child: Text(tr('Save the current sound in scene {0}', [scene])),
        ),
        if (widget.onClearScene != null)
          PopupMenuItem<String>(
            value: 'clear',
            enabled: filled,
            child: Text(tr('Clear scene {0}', [scene])),
          ),
        if (widget.onCompareScenes != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: 'compare',
            child: Text(tr('Compare scenes...')),
          ),
        ],
      ],
    );
    if (choice == 'save') widget.onSaveScene?.call(scene);
    if (choice == 'clear') widget.onClearScene?.call(scene);
    if (choice == 'compare') widget.onCompareScenes?.call();
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
                  tr('PATCH {0}', [
                    widget.preset.patchNumber.toString().padLeft(3, '0'),
                  ]),
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
                tr('UNSAVED'),
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: driveColor),
              ),
            ),

          // Scenes A-D: app-side (stored on this computer, applied through
          // the module frames) or, with the FX200 Studio firmware in FS MODE
          // SCENE, the pedal's own scenes. Disabled while [onSelectScene] is
          // null.
          Tooltip(
            message: widget.onSelectScene == null
                ? (widget.scenesDisabledReason ??
                      tr('Scenes: not supported by the current FX200 firmware'))
                : (widget.scenesTooltip ??
                      tr(
                        'Scenes: click to switch (a new scene starts as a copy of the current sound). Edits stay in the active scene and are stored with Save. Right-click to copy the sound or clear',
                      )),
            child: Opacity(
              opacity: widget.onSelectScene == null ? 0.45 : 1.0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final scene in kSceneNames)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: GestureDetector(
                        onSecondaryTapUp: widget.onSelectScene == null
                            ? null
                            : (d) => _sceneMenu(scene, d.globalPosition),
                        child: InkWell(
                          onTap: widget.onSelectScene == null
                              ? null
                              : () => widget.onSelectScene!(scene),
                          borderRadius: BorderRadius.circular(6),
                          child: _SceneChip(
                            scene: scene,
                            active: _sceneActive(scene),
                            filled: widget.filledScenes.contains(scene),
                            modified:
                                _sceneActive(scene) &&
                                widget.activeSceneModified,
                            accent: delayColor,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Undo / Redo / Save / Models browser toggle
          IconButton(
            tooltip: tr('Undo'),
            icon: Icon(
              Icons.undo,
              size: 18,
              color: widget.canUndo ? ext.textPrimary : ext.textMuted,
            ),
            onPressed: widget.canUndo ? widget.onUndo : null,
          ),
          IconButton(
            tooltip: tr('Redo'),
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
            label: Text(tr('SAVE')),
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
              label: Text(tr('PRESETS')),
            ),
          OutlinedButton.icon(
            onPressed: widget.onToggleBrowser,
            icon: Icon(
              widget.isBrowserOpen
                  ? Icons.view_sidebar
                  : Icons.view_sidebar_outlined,
              size: 16,
            ),
            label: Text(tr('MODELS')),
          ),
          if (widget.onOpenFootswitch != null)
            OutlinedButton.icon(
              onPressed: widget.onOpenFootswitch,
              icon: const Icon(Icons.radio_button_checked, size: 16),
              label: Text(tr('FOOTSWITCH')),
            ),
          if (widget.onOpenExpPedal != null)
            OutlinedButton.icon(
              onPressed: widget.onOpenExpPedal,
              icon: const Icon(Icons.swap_vert, size: 16),
              label: Text(tr('EXP PEDAL')),
            ),
          if (widget.onOpenDrum != null)
            OutlinedButton.icon(
              onPressed: widget.onOpenDrum,
              icon: const Icon(Icons.music_note_outlined, size: 16),
              label: Text(tr('DRUM')),
            ),
          if (widget.onOpenIr != null)
            OutlinedButton.icon(
              onPressed: widget.onOpenIr,
              icon: const Icon(Icons.graphic_eq, size: 16),
              label: Text(tr('IR')),
            ),
          if (widget.onOpenSystem != null)
            OutlinedButton.icon(
              onPressed: widget.onOpenSystem,
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: Text(tr('SYSTEM')),
            ),
          if (widget.onOpenBackup != null)
            OutlinedButton.icon(
              onPressed: widget.onOpenBackup,
              icon: const Icon(Icons.backup_outlined, size: 16),
              label: Text(tr('BACKUP')),
            ),
          if (widget.language != null && widget.onLanguageChanged != null)
            PopupMenuButton<AppLanguage>(
              tooltip: 'Language / Idioma',
              initialValue: widget.language,
              onSelected: widget.onLanguageChanged,
              itemBuilder: (_) => [
                for (final l in AppLanguage.values)
                  PopupMenuItem<AppLanguage>(value: l, child: Text(l.label)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.translate, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      widget.language!.code,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          if (widget.onOpenFirmware != null)
            IconButton(
              tooltip: tr('Firmware update'),
              onPressed: widget.onOpenFirmware,
              icon: const Icon(Icons.system_update_alt, size: 18),
            ),
        ],
      ),
    );
  }
}

/// One scene button: highlighted when active, a small bar when it holds a
/// sound, a dot when the sound was edited after applying it.
class _SceneChip extends StatelessWidget {
  const _SceneChip({
    required this.scene,
    required this.active,
    required this.filled,
    required this.modified,
    required this.accent,
  });

  final String scene;
  final bool active;
  final bool filled;
  final bool modified;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    return AnimatedContainer(
      duration: ext.transitionDuration,
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: active ? accent.withValues(alpha: 0.24) : ext.blockSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? accent : ext.subtleBorder),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            scene,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: active || filled ? ext.textPrimary : ext.textMuted,
            ),
          ),
          if (filled)
            Positioned(
              bottom: 3,
              child: Container(
                width: 10,
                height: 2,
                color: accent.withValues(alpha: active ? 1 : 0.6),
              ),
            ),
          if (modified)
            Positioned(
              top: 3,
              right: 3,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
