import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/data/datasources/preset_remote_datasource.dart';
import 'package:fx200_studio/data/repositories/preset_repository_impl.dart';
import 'package:fx200_studio/domain/entities/preset.dart';
import 'package:fx200_studio/presentation/state/editor_notifier.dart';
import 'package:fx200_studio/presentation/state/editor_state.dart';
import 'package:fx200_studio/presentation/state/exp_pedal_notifier.dart';
import 'package:fx200_studio/presentation/widgets/exp_pedal_dialog.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

class _Editor extends EditorNotifier {
  _Editor(this.preset);
  final Preset preset;

  @override
  EditorState build() => EditorState(
    preset: preset,
    selectedBlockId: null,
    catalog: const <CatalogModel>[],
    isHardwareConnected: true,
  );
}

class _FakeExp extends ExpPedalNotifier {
  _FakeExp(this.initial);
  final ExpPedalState initial;
  final List<String> calls = <String>[];

  @override
  ExpPedalState build() => initial;

  @override
  void setPedal1Mode(int mode) {
    calls.add('mode $mode');
    state = state.copyWith(pedal1Mode: mode, unsaved: true);
  }

  @override
  void setAssignment(int pedal, ExpAssignment a, {bool debounce = false}) {
    calls.add('set $pedal ${a.moduleSlot}:${a.paramIndex} ${a.min}-${a.max}');
    final list = [
      for (final x in state.assignmentsFor(pedal))
        if (!x.sameTarget(a.moduleSlot, a.paramIndex)) x,
      a,
    ];
    state = state.withAssignments(pedal, list).copyWith(unsaved: true);
  }

  @override
  void removeAssignment(int pedal, ExpAssignment a) {
    calls.add('remove $pedal ${a.moduleSlot}:${a.paramIndex}');
    state = state
        .withAssignments(pedal, [
          for (final x in state.assignmentsFor(pedal))
            if (!x.sameTarget(a.moduleSlot, a.paramIndex)) x,
        ])
        .copyWith(unsaved: true);
  }
}

void main() {
  group('0xA3 / 0xAE codec', () {
    test('decodes the pedal default "nothing assigned" frame', () {
      final f = Fx200ExpFrame.decode(const [0, 0, 1, 0, 0, 0, 0, 0, 0, 0])!;
      expect(f.pedal, Fx200ExpFrame.pedalInternal);
      expect(f.mode, Fx200ExpFrame.modeExpression);
      expect(f.moduleSlot, 0);
      expect(f.assigned, isFalse);
    });

    test('round-trips an assignment (max before min, flag last)', () {
      const f = Fx200ExpFrame(
        pedal: 1,
        mode: 0,
        moduleSlot: 2,
        paramIndex: 3,
        min: 10,
        max: 300,
        assigned: true,
      );
      expect(f.encode(), [1, 0, 3, 3, 0x01, 0x2c, 0, 10, 0, 1]);
      final back = Fx200ExpFrame.decode(f.encode())!;
      expect(
        (back.moduleSlot, back.paramIndex, back.min, back.max, back.assigned),
        (2, 3, 10, 300, true),
      );
    });

    test('heel = toe = 0 is sent as "not assigned"', () {
      const f = Fx200ExpFrame(
        pedal: 0,
        mode: 0,
        moduleSlot: 1,
        paramIndex: 0,
        min: 0,
        max: 0,
        assigned: true,
      );
      expect(f.encode().sublist(8), [0, 0]);
    });

    test('volume range uses [0, toe, 0, heel]', () {
      final r = Fx200VolumePedalRange.decode(const [0, 0x64, 0, 0])!;
      expect((r.min, r.max), (0, 100));
      expect(const Fx200VolumePedalRange(min: 20, max: 90).encode(), [
        0,
        90,
        0,
        20,
      ]);
      final packet = Fx200Protocol.buildVolumePedalRangePacket(r);
      expect(packet.sublist(5, 10), [0xae, 0, 100, 0, 0]);
    });
  });

  testWidgets('EXP dialog edits assignments and PEDAL 1 mode', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final preset = await tester.runAsync(
      () =>
          PresetRepositoryImpl(PresetRemoteDataSource(client: http.Client()))
              .getPreset(0),
    );
    final amp = preset!.blocks.firstWhere(
      (b) => b.category == EffectCategory.amp,
    );
    final fake = _FakeExp(
      ExpPedalState(
        loaded: true,
        pedal1: [
          ExpAssignment(
            moduleSlot: 2,
            paramIndex: 0,
            min: 0,
            max: amp.parameters[0].max.round(),
          ),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        editorProvider.overrideWith(() => _Editor(preset)),
        expPedalProvider.overrideWith(() => fake),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildFxEditorTheme(),
          home: const Scaffold(body: ExpPedalDialog()),
        ),
      ),
    );

    expect(find.text('EXPRESSION PEDAL'), findsOneWidget);
    expect(find.text('HEEL'), findsOneWidget);
    expect(find.text('TOE'), findsOneWidget);
    expect(find.textContaining(amp.parameters[0].label), findsWidgets);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pump();
    expect(fake.calls.last, 'remove 0 2:0');
    expect(find.text('HEEL'), findsNothing);
    expect(find.text('SAVE TO PRESET'), findsOneWidget);
    expect(find.textContaining('Not saved'), findsOneWidget);

    await tester.tap(find.text('VOLUME'));
    await tester.pump();
    expect(fake.calls.last, 'mode ${Fx200ExpFrame.modeVolume}');
    expect(find.textContaining('output volume'), findsOneWidget);

    await tester.tap(find.text('PEDAL 2 · EXTERNAL'));
    await tester.pump();
    expect(find.textContaining('cannot work in VOLUME'), findsOneWidget);
    expect(find.textContaining('Nothing assigned'), findsOneWidget);
  });
}
