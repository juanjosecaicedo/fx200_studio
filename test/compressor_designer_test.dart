import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/fx200_models.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/domain/entities/preset.dart';
import 'package:fx200_studio/presentation/widgets/compressor_designer.dart';
import 'package:material_ui/material_ui.dart';

EffectBlock _comp(String model, List<double> raw) {
  final base = Fx200Models.buildDefaultBlocks().firstWhere(
    (b) => b.category == EffectCategory.compressor,
  );
  final p = Fx200Models.parametersForModel(EffectCategory.compressor, model)!;
  return base.copyWith(
    modelName: model,
    parameters: [for (var i = 0; i < 4; i++) p[i].copyWith(value: raw[i])],
  );
}

Future<Map<String, double>> _pump(WidgetTester tester, EffectBlock b) async {
  tester.view.physicalSize = const Size(1000, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final committed = <String, double>{};
  await tester.pumpWidget(
    MaterialApp(
      theme: buildFxEditorTheme(),
      home: Scaffold(
        body: CompressorDesigner(
          block: b,
          accent: Colors.green,
          onParameterChanged: (id, v, {bool recordHistory = true}) {
            if (recordHistory) committed[id] = v;
          },
        ),
      ),
    ),
  );
  return committed;
}

// Plot geometry of the transfer curve (see _TransferCurveState).
Offset _at(Rect r, double inDb, double outDb) => Offset(
  r.left + 30 + (inDb + 60) / 60 * 240,
  r.top + 10 + (0 - outDb) / 60 * 240,
);

void main() {
  test('supports CS COMP and JR COMP only', () {
    expect(
      CompressorDesigner.supports(_comp('CS COMP', [60, 15, 2, 78])),
      isTrue,
    );
    expect(
      CompressorDesigner.supports(_comp('JR COMP', [60, 15, 2, 78])),
      isTrue,
    );
    final wah = Fx200Models.buildDefaultBlocks()
        .firstWhere((b) => b.category == EffectCategory.compressor)
        .copyWith(
          modelName: 'AUTO WAH',
          parameters: Fx200Models.parametersForModel(
            EffectCategory.compressor,
            'AUTO WAH',
          ),
        );
    expect(CompressorDesigner.supports(wah), isFalse);
  });

  testWidgets('dragging T moves THRESHOLD along the unity line', (
    tester,
  ) async {
    // raw 60 = -30 dB, raw 15 = 4.0:1
    final c = await _pump(tester, _comp('CS COMP', [60, 15, 2, 78]));
    final r = tester.getRect(find.byKey(const ValueKey<String>('comp_curve')));
    final g = await tester.startGesture(_at(r, -30, -30));
    await g.moveTo(_at(r, -20, -20));
    await g.up();
    await tester.pump();
    expect(c['p0'], 80); // -20 dB → (−20 + 60) / 0.5
  });

  testWidgets('dragging R sets RATIO from the output at 0 dB', (tester) async {
    final c = await _pump(tester, _comp('CS COMP', [60, 15, 2, 78]));
    final r = tester.getRect(find.byKey(const ValueKey<String>('comp_curve')));
    // T = -30, R = 4 → R node at out = -22.5 dB. Move to out = -15 → 2:1.
    final g = await tester.startGesture(_at(r, 0, -22.5));
    await g.moveTo(_at(r, 0, -15));
    await g.up();
    await tester.pump();
    expect(c['p1'], 5); // 2.0:1 → (2.0 - 1.0) / 0.2
  });
}
