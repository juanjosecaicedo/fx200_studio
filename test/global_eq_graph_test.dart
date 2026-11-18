import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/presentation/widgets/global_eq_graph.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';
import 'package:material_ui/material_ui.dart';

Fx200GlobalSettings _flat() =>
    Fx200GlobalSettings.fromBody(List<int>.filled(46, 0))
        .withGlobalEqEnabled(true)
        .withEqLowFreqHz(100)
        .withEqLowGain(24)
        .withEqMidFreqHz(1000)
        .withEqMidGain(24)
        .withEqHighFreqHz(8000)
        .withEqHighGain(24)
        .withEqLowCutHz(40)
        .withEqHighCutHz(20000);

Future<List<Fx200GlobalSettings>> _pump(
  WidgetTester tester,
  Fx200GlobalSettings settings, {
  bool enabled = true,
}) async {
  final changes = <Fx200GlobalSettings>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildFxEditorTheme(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 600,
            child: StatefulBuilder(
              builder: (context, setState) => GlobalEqGraph(
                settings: changes.isEmpty ? settings : changes.last,
                enabled: enabled,
                onChanged: (s) => setState(() => changes.add(s)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return changes;
}

void main() {
  testWidgets('dragging the MID node up raises its gain and moves its freq', (
    tester,
  ) async {
    final changes = await _pump(tester, _flat());
    final box = tester.getRect(find.byType(GlobalEqGraph));
    // MID node sits at 1 kHz / 0 dB. Plot: left pad 34, right pad 12,
    // 20 Hz..20 kHz log → 1 kHz is ~56.6 % across; 0 dB is mid-height.
    final plotW = box.width - 34 - 12;
    final start = Offset(
      box.left + 34 + plotW * 0.5663,
      box.top + 12 + (box.height - 12 - 22) / 2,
    );
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(0, -10));
    await gesture.moveBy(const Offset(40, -40));
    await gesture.up();
    await tester.pump();

    expect(changes, isNotEmpty);
    final last = changes.last;
    expect(Fx200GlobalSettings.gainToDb(last.eqMidGain), greaterThan(2));
    expect(last.eqMidFreqHz, greaterThan(1000));
    expect(last.eqLowGain, 24, reason: 'other bands untouched');
    expect(last.eqHighGain, 24);
  });

  testWidgets('double-tapping a band resets it to 0 dB', (tester) async {
    final boosted = _flat().withEqMidGain(40);
    final changes = await _pump(tester, boosted);
    final box = tester.getRect(find.byType(GlobalEqGraph));
    final plotW = box.width - 34 - 12;
    final plotH = box.height - 12 - 22;
    final db = Fx200GlobalSettings.gainToDb(40); // +8 dB on a ±15 dB scale
    final pos = Offset(
      box.left + 34 + plotW * 0.5663,
      box.top + 12 + (15 - db) / 30 * plotH,
    );
    await tester.tapAt(pos);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(pos);
    await tester.pumpAndSettle();
    expect(changes.last.eqMidGain, 24);
  });

  testWidgets('is read-only while GLOBAL EQ is off', (tester) async {
    final changes = await _pump(tester, _flat(), enabled: false);
    final box = tester.getRect(find.byType(GlobalEqGraph));
    await tester.dragFrom(box.center, const Offset(30, -40));
    await tester.pump();
    expect(changes, isEmpty);
  });
}
