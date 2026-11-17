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
    this.searchQuery = '',
    this.categoryFilter,
    this.errorMessage,
    this.isHardwareConnected = false,
    this.hardwareStatus = 'USB OFFLINE',
  });

  final Preset? preset;
  final String? selectedBlockId;
  final List<CatalogModel> catalog;
  final List<Preset> undoStack;
  final List<Preset> redoStack;
  final bool hasUnsavedChanges;
  final bool isLoading;
  final bool isBrowserOpen;
  final String searchQuery;
  final EffectCategory? categoryFilter;
  final String? errorMessage;
  final bool isHardwareConnected;
  final String hardwareStatus;

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
    String? searchQuery,
    EffectCategory? categoryFilter,
    bool clearCategoryFilter = false,
    String? errorMessage,
    bool clearError = false,
    bool? isHardwareConnected,
    String? hardwareStatus,
  }) {
    return EditorState(
      preset: preset ?? this.preset,
      selectedBlockId:
          clearSelectedBlock ? null : (selectedBlockId ?? this.selectedBlockId),
      catalog: catalog ?? this.catalog,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
      isLoading: isLoading ?? this.isLoading,
      isBrowserOpen: isBrowserOpen ?? this.isBrowserOpen,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: clearCategoryFilter
          ? null
          : (categoryFilter ?? this.categoryFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isHardwareConnected: isHardwareConnected ?? this.isHardwareConnected,
      hardwareStatus: hardwareStatus ?? this.hardwareStatus,
    );
  }
}
