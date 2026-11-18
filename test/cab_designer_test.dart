import 'dart:math' show log;

import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/fx200_models.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/domain/entities/preset.dart';
import 'package:fx200_studio/presentation/widgets/cab_designer.dart';
import 'package:material_ui/material_ui.dart';

EffectBlock _cab({double low = 0, double hi = 0, double space = 0}) {
  final base = Fx200Models.buildDefaultBlocks().firstWhere(
    (b) => b.category == EffectCategory.cab,
  );
  final p = base.parameters;
  return base.copyWith(
    parameters: [
      p[0],
      p[1].copyWith(value: low),
      p[2].copyWith(value: hi),
      p[3].copyWith(value: space),
      p[4],
    ],
  );
}

Future<Map<String, double>> _pump(
  WidgetTester tester,
  EffectBlock block,
) async {
  tester.view.physicalSize = const Size(1200, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final committed = <String, double>{};
  await tester.pumpWidget(
    MaterialApp(
      theme: buildFxEditorTheme(),
      home: Scaffold(
        body: CabDesigner(
          block: block,
          accent: Colors.teal,
          onParameterChanged: (id, v, {bool recordHistory = true}) {
            if (recordHistory) committed[id] = v;
          },
        ),
      ),
    ),
  );
  return committed;
}

void main() {
  test('CAB parameters match the pedal page', () {
    final labels = _cab().parameters.map((p) => p.label).toList();
    expect(labels, ['TUBE', 'LOW CUT', 'HI CUT', 'SPACE', 'LEVEL']);
    expect(_cab().parameters[0].options, ['OFF', '6L6', '6V6', 'EL34', 'EL84']);
  });

  testWidgets('dragging LC into the plot turns it on, back to the edge = OFF', (
    tester,
  ) async {
    final committed = await _pump(tester, _cab());
    final lcLabel = find.text('LC OFF');
    expect(lcLabel, findsNothing, reason: 'labels are painted, not widgets');

    // Response plot is the second 380×180 box; LC is parked near its left.
    final plot = tester.getRect(
      find.byKey(const ValueKey<String>('cab_response')),
    );
    final start = Offset(plot.left + 30 + 2, plot.bottom - 22 - 14);
    final g = await tester.startGesture(start);
    await g.moveTo(Offset(plot.left + 140, start.dy));
    await g.up();
    await tester.pump();
    expect(committed['p1'], inInclusiveRange(20, 800));
    expect(committed['p1'], greaterThan(60));
  });

  testWidgets('dragging an active LC past the left edge turns it OFF', (
    tester,
  ) async {
    final committed = await _pump(tester, _cab(low: 300));
    final plot = tester.getRect(
      find.byKey(const ValueKey<String>('cab_response')),
    );
    final y = plot.bottom - 22 - 14;
    final t = (log(300) - log(14)) / (log(24000) - log(14));
    final g2 = await tester.startGesture(
      Offset(plot.left + 30 + t * (plot.width - 40), y),
    );
    await g2.moveTo(Offset(plot.left + 5, y));
    await g2.up();
    await tester.pump();
    expect(committed['p1'], 0, reason: 'past the 20 Hz edge = OFF');
  });

  testWidgets('HI CUT stays within 3 kHz..20 kHz or OFF', (tester) async {
    final committed = await _pump(tester, _cab(hi: 16971));
    final plot = tester.getRect(
      find.byKey(const ValueKey<String>('cab_response')),
    );
    // 16.97 kHz handle → drag far left: clamps at 3 kHz.
    final y = plot.bottom - 22 - 14;
    double xFor(double hz) {
      const lo = 14.0, hi = 24000.0;
      final t = (log(hz) - log(lo)) / (log(hi) - log(lo));
      return plot.left + 30 + t * (plot.width - 40);
    }

    final g = await tester.startGesture(Offset(xFor(16971), y));
    await g.moveTo(Offset(plot.left + 40, y));
    await g.up();
    await tester.pump();
    expect(committed['p2'], Fx200Models.cabHiCutMinHz);
  });

  testWidgets('TUBE selector and SPACE room drag', (tester) async {
    final committed = await _pump(tester, _cab(space: 10));
    await tester.tap(find.text('EL34'));
    await tester.pump();
    expect(committed['p0'], 3);

    final room = tester.getRect(find.byKey(const ValueKey<String>('cab_room')));
    final g = await tester.startGesture(room.center);
    await g.moveBy(const Offset(0, -90)); // half the room height up
    await g.up();
    await tester.pump();
    expect(committed['p3'], closeTo(60, 2));
  });
}
