import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fx200_studio/core/theme/editor_theme.dart';
import 'package:fx200_studio/domain/entities/preset.dart';
import 'package:fx200_studio/presentation/state/device_settings_notifier.dart';
import 'package:fx200_studio/presentation/state/editor_notifier.dart';
import 'package:fx200_studio/presentation/state/editor_state.dart';
import 'package:fx200_studio/presentation/widgets/backup_dialog.dart';
import 'package:fx200_studio/presentation/widgets/footswitch_dialog.dart';
import 'package:fx200_studio/presentation/widgets/global_settings_dialog.dart';
import 'package:fx200_studio/services/fx200_protocol.dart';
import 'package:material_ui/material_ui.dart';

class _ConnectedEditor extends EditorNotifier {
  @override
  EditorState build() => const EditorState(
    preset: null,
    selectedBlockId: null,
    catalog: <CatalogModel>[],
    isHardwareConnected: true,
  );
}

class _FakeDeviceSettings extends DeviceSettingsNotifier {
  @override
  DeviceSettingsState build() => DeviceSettingsState(
    global: Fx200GlobalSettings.fromBody(
      List<int>.filled(46, 0)
        ..[18] = 100
        ..[28] = 1,
    ),
  );

  @override
  void updateGlobal(Fx200GlobalSettings next) {
    state = state.copyWith(global: next);
  }
}

Widget _host(Widget child, {List overrides = const []}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      theme: buildFxEditorTheme(),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('dialogs explain that the pedal must be connected', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final overrides = [
      editorProvider.overrideWith(() => _ConnectedEditorDisconnected()),
    ];

    await tester.pumpWidget(
      _host(const GlobalSettingsDialog(), overrides: overrides),
    );
    expect(find.textContaining('Connect the FX200'), findsOneWidget);

    await tester.pumpWidget(
      _host(const FootswitchDialog(), overrides: overrides),
    );
    expect(find.textContaining('Connect the FX200'), findsOneWidget);

    await tester.pumpWidget(_host(const BackupDialog(), overrides: overrides));
    expect(find.textContaining('Connect the FX200'), findsOneWidget);
    expect(find.text('BACKUP TO FILE...'), findsOneWidget);
  });

  testWidgets('SYSTEM dialog renders and edits the 0xA1 block', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final fake = _FakeDeviceSettings();
    final container = ProviderContainer(
      overrides: [
        editorProvider.overrideWith(_ConnectedEditor.new),
        deviceSettingsProvider.overrideWith(() => fake),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildFxEditorTheme(),
          home: const Scaffold(body: GlobalSettingsDialog()),
        ),
      ),
    );
    expect(find.text('BRIGHTNESS'), findsOneWidget);
    expect(find.text('GLOBAL EQ'), findsWidgets);

    await tester.tap(find.text('FAVORITE'));
    await tester.pump();
    expect(
      container.read(deviceSettingsProvider).global!.fsMode,
      Fx200GlobalSettings.fsModeFavorite,
    );
  });

  testWidgets('FOOTSWITCH dialog edits the preset controls', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final editor = _FootswitchEditor();
    await tester.pumpWidget(
      _host(
        const FootswitchDialog(),
        overrides: [editorProvider.overrideWith(() => editor)],
      ),
    );
    await tester.tap(find.text('MOD'));
    await tester.pump();
    expect(editor.edits.last.ctrlMask, 0x0082);
    expect(editor.edits.last.footswitchMode, 1);
    expect(find.textContaining('Not saved'), findsOneWidget);
  });
}

class _ConnectedEditorDisconnected extends EditorNotifier {
  @override
  EditorState build() => const EditorState(
    preset: null,
    selectedBlockId: null,
    catalog: <CatalogModel>[],
  );
}

/// Editor whose active preset has a known footswitch setup (CTRL, DS/OD).
class _FootswitchEditor extends EditorNotifier {
  final List<PresetControls> edits = <PresetControls>[];

  @override
  EditorState build() => const EditorState(
    preset: Preset(
      id: 'p',
      patchNumber: 0,
      name: 'Test',
      activeScene: 'A',
      bpm: 120,
      outputLevelDb: 0,
      blocks: <EffectBlock>[],
      controls: PresetControls(
        footswitchKnown: true,
        footswitchMode: 1,
        ctrlMask: 0x0002,
      ),
    ),
    selectedBlockId: null,
    catalog: <CatalogModel>[],
    isHardwareConnected: true,
  );

  @override
  void editControls(PresetControls next, {bool recordHistory = true}) {
    edits.add(next);
    state = state.copyWith(
      preset: state.preset!.copyWith(controls: next),
      hasUnsavedChanges: true,
    );
  }
}
