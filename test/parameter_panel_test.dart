import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/domain/entities/preset.dart';
import 'package:fx200_studio/presentation/widgets/parameter_panel.dart';
import 'package:fx200_studio/presentation/widgets/rotary_knob.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('RotaryKnob supports vertical drag and double-tap reset', (
    tester,
  ) async {
    var current = 50.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFxEditorTheme(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return RotaryKnob(
                label: 'GAIN',
                value: current,
                defaultValue: 25.0,
                min: 0,
                max: 100,
                accentColor: Theme.of(context)
                    .extension<FxEditorThemeExtension>()!
                    .colorFor(EffectCategory.amp),
                onChanged: (v) => setState(() => current = v),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('50'), findsOneWidget);
    await tester.drag(find.byType(RotaryKnob), const Offset(0, -40));
    await tester.pump();
    expect(current, greaterThan(50.0));

    // Double-tap resets to defaultValue (25.0)
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    expect(current, 25.0);
  });

  testWidgets('ParameterPanel renders knobs, model selector, and bypass', (
    tester,
  ) async {
    const block = EffectBlock(
      id: 'blk_amp',
      category: EffectCategory.amp,
      modelName: 'NAM A2 · FNDR BFSR Edge',
      availableModels: <String>['NAM A2 · FNDR BFSR Edge', 'Brit JCM800'],
      enabled: true,
      laneIndex: 0,
      slotIndex: 0,
      parameters: <BlockParameter>[
        BlockParameter(id: 'gain', label: 'GAIN', value: 54, defaultValue: 50),
      ],
    );

    var bypassed = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFxEditorTheme(),
        home: Scaffold(
          body: ParameterPanel(
            block: block,
            onParameterChanged: (_, _, {bool recordHistory = true}) {},
            onToggleBypass: () => bypassed = true,
            onModelChanged: (_) {},
            onModeChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(RotaryKnob), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    expect(bypassed, isTrue);
  });
}
