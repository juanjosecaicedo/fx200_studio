import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/l10n/l10n.dart';
import 'package:fx200_studio/main.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'EditorPage renders SignalChain, ParameterPanel, Bars, and ModelBrowser',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: Fx200StudioApp()));
      await tester.pumpAndSettle();

      expect(find.text('SIGNAL CHAIN'), findsOneWidget);
      expect(find.text('MODEL BROWSER'), findsOneWidget);
      expect(find.text('PATCH 000'), findsOneWidget);
      expect(find.text('SAVE'), findsOneWidget);
      expect(find.text('120 BPM'), findsOneWidget);
    },
  );
  spanishTests();
}

class _Spanish extends LanguageNotifier {
  @override
  AppLanguage build() {
    currentLanguage = AppLanguage.es;
    return AppLanguage.es;
  }
}

void spanishTests() {
  testWidgets('EditorPage renders in Spanish without overflow', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => currentLanguage = AppLanguage.en);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [languageProvider.overrideWith(_Spanish.new)],
        child: const Fx200StudioApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CADENA DE SEÑAL'), findsOneWidget);
    expect(find.text('GUARDAR'), findsOneWidget);
    expect(find.text('ES'), findsOneWidget);
  });
}
