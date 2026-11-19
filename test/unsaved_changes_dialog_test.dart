import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/presentation/widgets/unsaved_changes_dialog.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<UnsavedChangesChoice?> pick(
    WidgetTester tester,
    String? button,
  ) async {
    UnsavedChangesChoice? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFxEditorTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await showUnsavedChangesDialog(
                context,
                presetLabel: '053 "Lead"',
                targetLabel: '035 "Clean"',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.textContaining('053 "Lead"'), findsOneWidget);
    if (button == null) {
      await tester.tapAt(const Offset(5, 5)); // click outside
    } else {
      await tester.tap(find.text(button));
    }
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('each button returns its choice', (tester) async {
    expect(await pick(tester, 'SAVE & SWITCH'), UnsavedChangesChoice.save);
    expect(await pick(tester, "DON'T SAVE"), UnsavedChangesChoice.discard);
    expect(await pick(tester, 'KEEP EDITING'), UnsavedChangesChoice.stay);
  });

  testWidgets('dismissing the dialog keeps editing', (tester) async {
    expect(await pick(tester, null), UnsavedChangesChoice.stay);
  });
}
