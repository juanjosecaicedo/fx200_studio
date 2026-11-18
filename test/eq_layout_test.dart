import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/fx200_models.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/domain/entities/preset.dart';
import 'package:fx200_studio/presentation/widgets/parametric_eq_graph.dart';
import 'package:material_ui/material_ui.dart';

EffectBlock _eq(String model, [List<double>? values]) {
  final base = Fx200Models.buildDefaultBlocks().firstWhere(
    (b) => b.category == EffectCategory.eq,
  );
  final params = Fx200Models.eqParameters(model);
  return base.copyWith(
    modelName: model,
    parameters: [
      for (var i = 0; i < params.length; i++)
        values == null ? params[i] : params[i].copyWith(value: values[i]),
    ],
  );
}

void main() {
  test('DELAY models follow the pedal pages (raw = (shown - min) / step)', () {
    final dual = Fx200Models.parametersForModel(EffectCategory.delay, 'DUAL')!;
    expect(dual.map((p) => p.label), [
      'TIME 1',
      'SUB-D 1',
      'PAN 1',
      'TIME 2',
      'SUB-D 2',
      'PAN 2',
      'F.BACK',
      'LEVEL',
    ]);
    expect(dual[0].copyWith(value: 480).displayText, '500 ms');
    expect(dual[1].options.first, 'OFF');
    expect(dual[2].copyWith(value: 0).displayText, 'L100');
    expect(dual[5].copyWith(value: 200).displayText, 'R100');
    final dyn = Fx200Models.parametersForModel(
      EffectCategory.delay,
      'DYNAMIC',
    )!;
    expect(
      dyn
          .where((p) => p.kind != BlockParameterKind.reserved)
          .map((p) => p.label),
      ['TIME', 'F.BACK', 'THRESHOLD', 'SUB-D', 'LEVEL'],
    );
    expect(dyn, hasLength(8), reason: 'the 0x99 frame carries 8 words');
  });

  test('CS COMP raw values from the USB capture read like the pedal', () {
    final p = Fx200Models.parametersForModel(
      EffectCategory.compressor,
      'CS COMP',
    )!;
    final raw = [60.0, 15.0, 2.0, 78.0]; // captura.pcapng
    expect(
      [for (var i = 0; i < 4; i++) p[i].textOf(raw[i])],
      ['-30.0 dB', '4.0:1', '2', '78'],
    );
  });

  test('every EQ model carries the 9 words of the 0x97 frame', () {
    for (final m in Fx200Models.eqModels) {
      expect(Fx200Models.eqParameters(m), hasLength(9), reason: m);
    }
  });

  test('6-band labels come from the firmware tables', () {
    final l = Fx200Models.eqParameters('6 BAND EQ 1').map((p) => p.label);
    expect(l.take(7), [
      '60Hz',
      '250Hz',
      '800Hz',
      '2kHz',
      '4kHz',
      '8kHz',
      'LEVEL',
    ]);
    final l2 = Fx200Models.eqParameters('6 BAND EQ 2').map((p) => p.label);
    expect(l2.take(6), ['80Hz', '300Hz', '600Hz', '1kHz', '2kHz', '4kHz']);
  });

  test('4 BAND CUSTOM: FREQ/GAIN pairs then LEVEL, pedal defaults', () {
    final p = Fx200Models.eqParameters('4 BAND CUSTOM');
    expect(p.map((e) => e.label), [
      'FREQ 1',
      'GAIN',
      'FREQ 2',
      'GAIN',
      'FREQ 3',
      'GAIN',
      'FREQ 4',
      'GAIN',
      'LEVEL',
    ]);
    // FREQ: 60..20000 Hz, raw = Hz - 60. GAIN: -12..12 dB in 0.5 steps.
    expect(p.map((e) => e.value), [40, 24, 740, 24, 1940, 24, 3940, 24, 50]);
    expect(p.map((e) => e.displayText), [
      '100 Hz',
      '0.0 dB',
      '800 Hz',
      '0.0 dB',
      '2000 Hz',
      '0.0 dB',
      '4000 Hz',
      '0.0 dB',
      '50',
    ]);
    final layout = eqLayoutFor(_eq('4 BAND CUSTOM'));
    expect(layout.bands, hasLength(4));
    expect(layout.bands.every((b) => b.movable), isTrue);
    expect(layout.knobs.single.label, 'LEVEL');
  });

  testWidgets('dragging a CUSTOM node changes FREQ and GAIN', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final changed = <String, double>{};
    final layout = eqLayoutFor(_eq('4 BAND CUSTOM'));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildFxEditorTheme(),
        home: Scaffold(
          body: ParametricEqGraph(
            blockId: 'eq',
            bands: layout.bands,
            extraKnobs: layout.knobs,
            accent: Colors.pink,
            onParameterChanged: (id, v, {bool recordHistory = true}) =>
                changed[id] = v,
          ),
        ),
      ),
    );
    final node = find.byKey(const ValueKey<String>('eq_node_1')); // 800 Hz
    final g = await tester.startGesture(tester.getCenter(node));
    await g.moveBy(const Offset(80, -43));
    await g.up();
    await tester.pump();
    expect(changed['p2'], greaterThan(740)); // FREQ2 moved right
    expect(changed['p3'], greaterThan(24)); // GAIN2 boosted
  });
}
