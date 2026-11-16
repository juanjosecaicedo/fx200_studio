import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/main.dart';

void main() {
  testWidgets('FX200 Studio renders USB, Signal Chain, and NAM Inspector', (tester) async {
    await tester.pumpWidget(const Fx200StudioApp());

    expect(find.text('FX200 Studio · NAM A2'), findsOneWidget);
    expect(find.text('Scan FX200 USB'), findsOneWidget);
    expect(find.text('AMP (NAM A2)'), findsOneWidget);
    expect(find.text('Name: TONE3000 Demo Crunch A2'), findsOneWidget);
  });
}
