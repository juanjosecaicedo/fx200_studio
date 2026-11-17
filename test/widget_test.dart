import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/main.dart';

void main() {
  testWidgets('EditorPage renders SignalChain, ParameterPanel, Bars, and ModelBrowser',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: Fx200StudioApp()));
    await tester.pumpAndSettle();

    expect(find.text('SIGNAL CHAIN'), findsOneWidget);
    expect(find.text('MODEL BROWSER'), findsOneWidget);
    expect(find.text('PATCH 000'), findsOneWidget);
    expect(find.text('SAVE'), findsOneWidget);
    expect(find.text('120 BPM'), findsOneWidget);
  });
}
