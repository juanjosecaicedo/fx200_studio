import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/data/datasources/preset_remote_datasource.dart';
import 'package:fx200_studio/data/repositories/preset_repository_impl.dart';
import 'package:fx200_studio/presentation/widgets/signal_chain_view.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('SignalChainView renders a single serial chain', (tester) async {
    final repo = PresetRepositoryImpl(
      PresetRemoteDataSource(client: http.Client()),
    );
    final preset = await repo.getPreset(0);
    final catalog = await repo.getModelCatalog();

    String? selectedId = preset.blocks.first.id;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildFxEditorTheme(),
        home: Scaffold(
          body: SignalChainView(
            preset: preset,
            selectedBlockId: selectedId,
            catalog: catalog,
            onSelectBlock: (id) => selectedId = id,
            onToggleBypass: (_) {},
            onReorderBlock: (_, _, _) {},
            onAddFromCatalog: (_, _, _) {},
          ),
        ),
      ),
    );

    expect(find.text('INPUT'), findsOneWidget);
    expect(find.text('OUTPUT'), findsOneWidget);
    expect(find.text('AMP'), findsOneWidget);
    expect(find.textContaining('SPLIT'), findsNothing);
    expect(find.text('MERGE'), findsNothing);
  });
}
