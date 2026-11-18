import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/presentation/widgets/preset_sidebar.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildFxEditorTheme(),
  home: Scaffold(body: Row(children: [child])),
);

void main() {
  testWidgets('drag handles only appear when presets can be edited', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PresetSidebar(
          activePatchNumber: 0,
          presetNames: const {0: 'CLEAN'},
          onSelectPreset: (_) {},
          onMovePreset: (_, _) {},
        ),
      ),
    );
    expect(find.byIcon(Icons.drag_indicator), findsNothing);

    await tester.pumpWidget(
      _host(
        PresetSidebar(
          activePatchNumber: 0,
          presetNames: const {0: 'CLEAN'},
          onSelectPreset: (_) {},
          onMovePreset: (_, _) {},
          canEditPresets: true,
        ),
      ),
    );
    expect(find.byIcon(Icons.drag_indicator), findsWidgets);
  });

  testWidgets('COPY copies the active preset; PASTE asks before writing', (
    tester,
  ) async {
    int? copied;
    int? pasted;
    await tester.pumpWidget(
      _host(
        PresetSidebar(
          activePatchNumber: 7,
          presetNames: const {7: 'LEAD'},
          onSelectPreset: (_) {},
          canEditPresets: true,
          clipboardLabel: '002 CRUNCH',
          onCopyPreset: (i) => copied = i,
          onPastePreset: (i) => pasted = i,
        ),
      ),
    );
    await tester.tap(find.text('COPY'));
    expect(copied, 7);

    await tester.tap(find.text('PASTE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Overwrite 007 "LEAD"'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(pasted, isNull);

    await tester.tap(find.text('PASTE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OVERWRITE'));
    await tester.pumpAndSettle();
    expect(pasted, 7);
  });

  testWidgets('right-click menu offers copy for any preset', (tester) async {
    int? copied;
    await tester.pumpWidget(
      _host(
        PresetSidebar(
          activePatchNumber: 0,
          presetNames: const {3: 'AMBIENT'},
          onSelectPreset: (_) {},
          canEditPresets: true,
          onCopyPreset: (i) => copied = i,
        ),
      ),
    );
    await tester.tap(find.text('AMBIENT'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy 003'));
    await tester.pumpAndSettle();
    expect(copied, 3);
  });

  testWidgets('clear asks for confirmation first', (tester) async {
    int? cleared;
    await tester.pumpWidget(
      _host(
        PresetSidebar(
          activePatchNumber: 4,
          presetNames: const {4: 'OLD'},
          onSelectPreset: (_) {},
          canEditPresets: true,
          onClearPreset: (i) => cleared = i,
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('Clear 004 "OLD"'), findsOneWidget);
    await tester.tap(find.text('CLEAR'));
    await tester.pumpAndSettle();
    expect(cleared, 4);
  });
}
