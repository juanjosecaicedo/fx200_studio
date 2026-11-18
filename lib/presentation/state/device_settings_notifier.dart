import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/fx200_protocol.dart';
import 'editor_notifier.dart';

/// Global SYSTEM settings (`0xA1`) and the active preset's footswitch
/// assignment (`0xA4`) as last reported by the pedal.
class DeviceSettingsState {
  const DeviceSettingsState({
    this.global,
    this.footswitch,
    this.footswitchUnsaved = false,
  });

  final Fx200GlobalSettings? global;
  final Fx200FootswitchConfig? footswitch;

  /// True after a footswitch change until the preset is saved (`0xA8`).
  final bool footswitchUnsaved;

  DeviceSettingsState copyWith({
    Fx200GlobalSettings? global,
    Fx200FootswitchConfig? footswitch,
    bool? footswitchUnsaved,
  }) {
    return DeviceSettingsState(
      global: global ?? this.global,
      footswitch: footswitch ?? this.footswitch,
      footswitchUnsaved: footswitchUnsaved ?? this.footswitchUnsaved,
    );
  }
}

final deviceSettingsProvider =
    NotifierProvider<DeviceSettingsNotifier, DeviceSettingsState>(
      DeviceSettingsNotifier.new,
    );

class DeviceSettingsNotifier extends Notifier<DeviceSettingsState> {
  static const Duration _sendDebounce = Duration(milliseconds: 120);

  Timer? _globalSendTimer;

  @override
  DeviceSettingsState build() {
    final sync = ref.watch(fx200HardwareSyncProvider);
    final sub = sync.frames.listen((frame) {
      final global = Fx200Protocol.decodeGlobalSettingsFrame(
        frame.opcode,
        frame.body,
      );
      if (global != null) {
        state = state.copyWith(global: global);
        return;
      }
      if (frame.opcode == Fx200Protocol.opCmdA4 &&
          !sync.suppressEditorUpdates) {
        state = state.copyWith(
          footswitch: sync.lastFootswitch,
          footswitchUnsaved: false,
        );
      }
    });
    ref.onDispose(() {
      sub.cancel();
      _globalSendTimer?.cancel();
    });
    return DeviceSettingsState(
      global: sync.lastGlobalSettings,
      footswitch: sync.isConnected ? sync.lastFootswitch : null,
    );
  }

  /// Applies [next] locally and writes it to the pedal (debounced so that
  /// dragging a slider does not flood the USB link).
  void updateGlobal(Fx200GlobalSettings next) {
    state = state.copyWith(global: next);
    _globalSendTimer?.cancel();
    _globalSendTimer = Timer(_sendDebounce, () {
      ref.read(fx200HardwareSyncProvider).sendGlobalSettings(next);
    });
  }

  /// Sends a new footswitch mode / CTRL assignment. The BPM part of `0xA4`
  /// is owned by the editor's tempo control, so the latest value is kept.
  void updateFootswitch(Fx200FootswitchConfig next) {
    final sync = ref.read(fx200HardwareSyncProvider);
    final merged = next.copyWith(bpm: sync.lastFootswitch.bpm);
    state = state.copyWith(footswitch: merged, footswitchUnsaved: true);
    sync.sendFootswitch(merged);
  }

  /// Persists the footswitch assignment by saving the active preset (`0xA8`).
  Future<void> saveFootswitchToPreset() async {
    await ref.read(editorProvider.notifier).saveCurrentPreset();
    state = state.copyWith(footswitchUnsaved: false);
  }
}
