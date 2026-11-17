import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/data/datasources/preset_remote_datasource.dart';
import 'package:fx200_studio/data/models/preset_model.dart';
import 'package:fx200_studio/data/repositories/preset_repository_impl.dart';
import 'package:fx200_studio/domain/entities/preset.dart';
import 'package:fx200_studio/domain/usecases/preset_usecases.dart';
import 'package:fx200_studio/presentation/state/editor_notifier.dart';
import 'package:http/http.dart' as http;

void main() {
  test('PresetModel round-trips fromJson/toJson cleanly', () async {
    final ds = PresetRemoteDataSource(client: http.Client());
    final model = await ds.fetchPreset(0);
    final json = model.toJson();
    final restored = PresetModel.fromJson(json);

    expect(restored.id, model.id);
    expect(restored.name, model.name);
    expect(restored.blocks.length, model.blocks.length);
  });

  test(
    'UseCases update parameter, toggle bypass, and reorder blocks',
    () async {
      final repo = PresetRepositoryImpl(
        PresetRemoteDataSource(client: http.Client()),
      );
      final preset = await GetPresetUseCase(repo)(0);

      final updated = const UpdateBlockParameterUseCase()(
        preset: preset,
        blockId: 'blk_amp',
        parameterId: 'gain',
        value: 82.0,
      );
      final amp = updated.blocks.firstWhere((b) => b.id == 'blk_amp');
      expect(amp.parameters.firstWhere((p) => p.id == 'gain').value, 82.0);

      final bypassed = const ToggleBlockBypassUseCase()(
        preset: updated,
        blockId: 'blk_amp',
      );
      expect(
        bypassed.blocks.firstWhere((b) => b.id == 'blk_amp').enabled,
        isFalse,
      );

      final reordered = const ReorderBlocksUseCase()(
        preset: bypassed,
        blockId: 'blk_delay',
        targetLane: 0,
        targetSlot: 0,
      );
      expect(reordered.blocks.first.id, 'blk_delay');
      expect(reordered.blocks.first.slotIndex, 0);
    },
  );

  test('EditorNotifier supports undo and redo with ThemeExtension', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(editorProvider.notifier).loadPreset(0);
    final notifier = container.read(editorProvider.notifier);

    notifier.toggleBypass('blk_amp');
    expect(container.read(editorProvider).canUndo, isTrue);
    expect(container.read(editorProvider).hasUnsavedChanges, isTrue);

    notifier.undo();
    expect(container.read(editorProvider).canRedo, isTrue);

    notifier.redo();
    final amp = container
        .read(editorProvider)
        .preset!
        .blocks
        .firstWhere((b) => b.id == 'blk_amp');
    expect(amp.enabled, isFalse);

    final theme = buildFxEditorTheme();
    final ext = theme.extension<FxEditorThemeExtension>();
    expect(ext, isNotNull);
    expect(ext!.colorFor(EffectCategory.amp), isNotNull);
  });
}
