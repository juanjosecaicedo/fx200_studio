import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/data/datasources/preset_remote_datasource.dart';
import 'package:fx200_studio/data/repositories/preset_repository_impl.dart';
import 'package:fx200_studio/presentation/widgets/editor_bottom_bar.dart';
import 'package:fx200_studio/presentation/widgets/editor_top_bar.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('EditorTopBar renders scenes A-H, unsaved badge, and actions',
      (tester) async {
    final repo = PresetRepositoryImpl(
      PresetRemoteDataSource(client: http.Client()),
    );
    final preset = await repo.getPreset(0);
    String selectedScene = 'A';
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFxEditorTheme(),
        home: Scaffold(
          body: EditorTopBar(
            preset: preset,
            hasUnsavedChanges: true,
            canUndo: true,
            canRedo: false,
            isBrowserOpen: true,
            onSelectPatch: (_) {},
            onRenamePreset: (_) {},
            onSelectScene: (s) => selectedScene = s,
            onUndo: () {},
            onRedo: () {},
            onSave: () => saved = true,
            onToggleBrowser: () {},
          ),
        ),
      ),
    );

    expect(find.text('UNSAVED'), findsOneWidget);
    expect(find.text('PATCH 000'), findsOneWidget);
    for (final s in const <String>['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']) {
      expect(find.text(s), findsOneWidget);
    }

    await tester.tap(find.text('C'));
    expect(selectedScene, 'C');

    await tester.tap(find.text('SAVE'));
    expect(saved, isTrue);
  });

  testWidgets('EditorBottomBar renders output dB, BPM, and IN/OUT meters',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFxEditorTheme(),
        home: Scaffold(
          body: EditorBottomBar(
            bpm: 120,
            outputLevelDb: 0.0,
            onBpmChanged: (_) {},
            onOutputLevelChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('OUTPUT'), findsOneWidget);
    expect(find.text('0.0 dB'), findsOneWidget);
    expect(find.text('120 BPM'), findsOneWidget);
    expect(find.text('IN'), findsOneWidget);
    expect(find.text('OUT'), findsOneWidget);
  });
}
