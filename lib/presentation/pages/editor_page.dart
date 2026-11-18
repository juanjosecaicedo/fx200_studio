import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/editor_theme.dart';
import '../../domain/entities/preset.dart';
import '../../ui/home_page.dart';
import '../state/editor_notifier.dart';
import '../state/preset_ops_notifier.dart';
import '../widgets/backup_dialog.dart';
import '../widgets/editor_bottom_bar.dart';
import '../widgets/editor_top_bar.dart';
import '../widgets/footswitch_dialog.dart';
import '../widgets/global_settings_dialog.dart';
import '../widgets/model_browser.dart';
import '../widgets/parameter_panel.dart';
import '../widgets/preset_sidebar.dart';
import '../widgets/signal_chain_view.dart';

/// Main hardware-style Multi-FX Editor screen.
class EditorPage extends ConsumerStatefulWidget {
  const EditorPage({super.key});

  @override
  ConsumerState<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends ConsumerState<EditorPage> {
  bool _showHardwareStudio = false;

  @override
  Widget build(BuildContext context) {
    if (_showHardwareStudio) {
      return Scaffold(
        body: Column(
          children: [
            _ModeSwitcherBar(
              showHardware: true,
              isUsbConnected: false,
              usbStatus: 'TOOLS',
              onToggleUsb: () {},
              onToggle: () => setState(() => _showHardwareStudio = false),
            ),
            const Expanded(child: Fx200HomePage()),
          ],
        ),
      );
    }

    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final state = ref.watch(editorProvider);
    final notifier = ref.read(editorProvider.notifier);
    final preset = state.preset;
    final ops = ref.watch(presetOpsProvider);
    final opsNotifier = ref.read(presetOpsProvider.notifier);
    final clip = ops.clipboard;

    if (preset == null) {
      return Scaffold(
        backgroundColor: ext.chassisBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: ext.chassisBackground,
      body: Column(
        children: [
          _ModeSwitcherBar(
            showHardware: false,
            isUsbConnected: state.isHardwareConnected,
            isBusy: state.isConnectingHardware || state.isSyncingPresets,
            usbStatus: state.hardwareStatus,
            onToggleUsb: notifier.toggleHardwareConnection,
            onToggle: () => setState(() => _showHardwareStudio = true),
          ),
          EditorTopBar(
            preset: preset,
            hasUnsavedChanges: state.hasUnsavedChanges,
            canUndo: state.canUndo,
            canRedo: state.canRedo,
            isBrowserOpen: state.isBrowserOpen,
            onSelectPatch: notifier.loadPreset,
            onRenamePreset: notifier.renamePreset,
            onSelectScene: notifier.selectScene,
            onUndo: notifier.undo,
            onRedo: notifier.redo,
            onSave: notifier.saveCurrentPreset,
            onToggleBrowser: notifier.toggleBrowser,
            isPresetSidebarOpen: state.isPresetSidebarOpen,
            onTogglePresetSidebar: notifier.togglePresetSidebar,
            onOpenFootswitch: () => showFootswitchDialog(context),
            onOpenSystem: () => showGlobalSettingsDialog(context),
            onOpenBackup: () => showBackupDialog(context),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: ext.transitionDuration,
                  curve: Curves.easeOutCubic,
                  child: state.isPresetSidebarOpen
                      ? PresetSidebar(
                          activePatchNumber: preset.patchNumber,
                          presetNames: state.presetNames,
                          isSyncing: state.isSyncingPresets,
                          onSelectPreset: notifier.loadPreset,
                          canEditPresets:
                              state.isHardwareConnected &&
                              !state.isSyncingPresets &&
                              !ops.isBusy,
                          clipboardLabel: clip == null
                              ? null
                              : '${clip.index.toString().padLeft(3, '0')} '
                                    '${clip.name}',
                          onCopyPreset: opsNotifier.copy,
                          onPastePreset: opsNotifier.paste,
                          onClearPreset: opsNotifier.clear,
                          onMovePreset: opsNotifier.move,
                          opsBusy: ops.isBusy,
                          opsProgress: ops.progress,
                          opsMessage: ops.message,
                          opsIsError: ops.isError,
                          onDismissOpsMessage: opsNotifier.clearMessage,
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SignalChainView(
                          preset: preset,
                          selectedBlockId: state.selectedBlockId,
                          catalog: state.catalog,
                          onSelectBlock: notifier.selectBlock,
                          onToggleBypass: notifier.toggleBypass,
                          onReorderBlock: (id, lane, slot) =>
                              notifier.reorderBlock(
                                blockId: id,
                                targetLane: lane,
                                targetSlot: slot,
                              ),
                          onAddFromCatalog: (model, lane, slot) =>
                              notifier.addBlockFromCatalog(
                                model,
                                targetLane: lane,
                                targetSlot: slot,
                              ),
                          onToggleParallelSplit: notifier.toggleParallelSplit,
                          onRemoveBlock: notifier.removeBlock,
                        ),
                        const SizedBox(height: 14),
                        ParameterPanel(
                          block: state.selectedBlock,
                          onParameterChanged:
                              (paramId, value, {bool recordHistory = true}) {
                                final blockId = state.selectedBlockId;
                                if (blockId == null) return;
                                notifier.updateParameter(
                                  blockId: blockId,
                                  parameterId: paramId,
                                  value: value,
                                  recordHistory: recordHistory,
                                );
                              },
                          onToggleBypass: () {
                            final blockId = state.selectedBlockId;
                            if (blockId != null) notifier.toggleBypass(blockId);
                          },
                          onModelChanged: (modelName) {
                            final blockId = state.selectedBlockId;
                            if (blockId != null) {
                              notifier.changeBlockModel(blockId, modelName);
                            }
                          },
                          onModeChanged: (mode) {
                            final blockId = state.selectedBlockId;
                            if (blockId != null) {
                              notifier.changeBlockMode(blockId, mode);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: ext.transitionDuration,
                  curve: Curves.easeOutCubic,
                  child: state.isBrowserOpen
                      ? ModelBrowser(
                          catalog: state.catalog,
                          searchQuery: state.searchQuery,
                          categoryFilter: state.categoryFilter,
                          onSearchChanged: notifier.setSearchQuery,
                          onCategoryChanged: notifier.setCategoryFilter,
                          onAddModel: notifier.addBlockFromCatalog,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          EditorBottomBar(
            bpm: preset.bpm,
            outputLevelDb: preset.outputLevelDb,
            onBpmChanged: notifier.setBpm,
            onOutputLevelChanged: notifier.setOutputLevelDb,
          ),
        ],
      ),
    );
  }
}

class _ModeSwitcherBar extends StatelessWidget {
  const _ModeSwitcherBar({
    required this.showHardware,
    required this.isUsbConnected,
    required this.usbStatus,
    required this.onToggleUsb,
    required this.onToggle,
    this.isBusy = false,
  });

  final bool showHardware;
  final bool isUsbConnected;
  final bool isBusy;
  final String usbStatus;
  final VoidCallback onToggleUsb;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FxEditorThemeExtension>()!;
    final ampColor = ext.colorFor(EffectCategory.amp);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: ext.chassisBackground,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'FX200 STUDIO · CORTEX/AMPERO EDITOR',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(width: 8),
          if (!showHardware) ...[
            InkWell(
              onTap: onToggleUsb,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isUsbConnected
                      ? ampColor.withValues(alpha: 0.18)
                      : ext.blockSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isUsbConnected ? ampColor : ext.subtleBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isBusy)
                      SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isUsbConnected ? ampColor : ext.textPrimary,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.usb,
                        size: 13,
                        color: isUsbConnected ? ampColor : ext.textMuted,
                      ),
                    const SizedBox(width: 5),
                    Text(
                      usbStatus,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isUsbConnected ? ampColor : ext.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          TextButton.icon(
            onPressed: onToggle,
            icon: Icon(
              showHardware ? Icons.tune : Icons.settings_input_component,
              size: 14,
            ),
            label: Text(
              showHardware ? 'BACK TO EDITOR' : 'NAM A2 / IR TOOLS',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: ext.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
