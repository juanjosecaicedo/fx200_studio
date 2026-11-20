import '../../domain/entities/preset.dart';

/// Immutable UI state for the multi-FX editor screen.
class EditorState {
  const EditorState({
    required this.preset,
    required this.selectedBlockId,
    required this.catalog,
    this.undoStack = const <Preset>[],
    this.redoStack = const <Preset>[],
    this.hasUnsavedChanges = false,
    this.isLoading = false,
    this.isBrowserOpen = true,
    this.isPresetSidebarOpen = true,
    this.presetNames = const <int, String>{},
    this.searchQuery = '',
    this.categoryFilter,
    this.errorMessage,
    this.isHardwareConnected = false,
    this.isConnectingHardware = false,
    this.isSyncingPresets = false,
    this.hardwareStatus = 'USB OFFLINE',
    this.saveCount = 0,
    this.pedalScenes = false,
  });

  final Preset? preset;
  final String? selectedBlockId;
  final List<CatalogModel> catalog;
  final List<Preset> undoStack;
  final List<Preset> redoStack;
  final bool hasUnsavedChanges;
  final bool isLoading;
  final bool isBrowserOpen;
  final bool isPresetSidebarOpen;
  final Map<int, String> presetNames;
  final String searchQuery;
  final EffectCategory? categoryFilter;
  final String? errorMessage;
  final bool isHardwareConnected;
  final bool isConnectingHardware;
  final bool isSyncingPresets;
  final String hardwareStatus;

  /// Incremented every time the active preset is saved to the pedal
  /// (scenes are committed to disk on it).
  final int saveCount;

  /// The connected pedal runs the custom scenes firmware (marker in the
  /// `0x84` device string): FS MODE can be set to SCENE and the pedal
  /// stores / switches scenes itself.
  final bool pedalScenes;

  /// Scenes are handled by the pedal right now.
  bool get pedalScenesActive => isHardwareConnected && pedalScenes;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  EffectBlock? get selectedBlock {
    final p = preset;
    if (p == null || selectedBlockId == null) return null;
    for (final b in p.blocks) {
      if (b.id == selectedBlockId) return b;
    }
    return null;
  }

  EditorState copyWith({
    Preset? preset,
    String? selectedBlockId,
    bool clearSelectedBlock = false,
    List<CatalogModel>? catalog,
    List<Preset>? undoStack,
    List<Preset>? redoStack,
    bool? hasUnsavedChanges,
    bool? isLoading,
    bool? isBrowserOpen,
    bool? isPresetSidebarOpen,
    Map<int, String>? presetNames,
    String? searchQuery,
    EffectCategory? categoryFilter,
    bool clearCategoryFilter = false,
    String? errorMessage,
    bool clearError = false,
    bool? isHardwareConnected,
    bool? isConnectingHardware,
    bool? isSyncingPresets,
    String? hardwareStatus,
    int? saveCount,
    bool? pedalScenes,
  }) {
    return EditorState(
      preset: preset ?? this.preset,
      selectedBlockId: clearSelectedBlock
          ? null
          : (selectedBlockId ?? this.selectedBlockId),
      catalog: catalog ?? this.catalog,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isLoading: isLoading ?? this.isLoading,
      isBrowserOpen: isBrowserOpen ?? this.isBrowserOpen,
      isPresetSidebarOpen: isPresetSidebarOpen ?? this.isPresetSidebarOpen,
      presetNames: presetNames ?? this.presetNames,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: clearCategoryFilter
          ? null
          : (categoryFilter ?? this.categoryFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isHardwareConnected: isHardwareConnected ?? this.isHardwareConnected,
      isConnectingHardware: isConnectingHardware ?? this.isConnectingHardware,
      isSyncingPresets: isSyncingPresets ?? this.isSyncingPresets,
      hardwareStatus: hardwareStatus ?? this.hardwareStatus,
      saveCount: saveCount ?? this.saveCount,
      pedalScenes: pedalScenes ?? this.pedalScenes,
    );
  }
}
