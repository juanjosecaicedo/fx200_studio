import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/fx200_protocol.dart';
import 'editor_notifier.dart';

/// Global (not per-preset) device state: SYSTEM settings (`0xA1`) and the
/// drum machine (`0xAD`). The footswitch belongs to the preset and lives in
/// `Preset.controls` (see `EditorNotifier.editControls`).
class DeviceSettingsState {
  const DeviceSettingsState({this.global, this.drum});

  final Fx200GlobalSettings? global;

  /// Drum machine / metronome (`0xAD`), null until the pedal reports it.
  final Fx200DrumSettings? drum;

  DeviceSettingsState copyWith({
    Fx200GlobalSettings? global,
    Fx200DrumSettings? drum,
  }) {
    return DeviceSettingsState(
      global: global ?? this.global,
      drum: drum ?? this.drum,
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
  Timer? _drumSendTimer;
  DateTime? _drumSentAt;

  /// A `0xAD` arriving right after our own write is the pedal echoing it;
  /// ignoring it keeps a slider from jumping back while it is dragged.
  bool _isDrumEcho() {
    final t = _drumSentAt;
    return t != null &&
        DateTime.now().difference(t) < const Duration(milliseconds: 300);
  }

  /// Applies [next] locally and writes it to the pedal (debounced while a
  /// slider is dragged). The drum machine is global: no preset save needed.
  void updateDrum(Fx200DrumSettings next, {bool debounce = false}) {
    state = state.copyWith(drum: next);
    void write() {
      _drumSentAt = DateTime.now();
      ref.read(fx200HardwareSyncProvider).sendDrum(next);
    }

    _drumSendTimer?.cancel();
    if (debounce) {
      _drumSendTimer = Timer(_sendDebounce, write);
    } else {
      write();
    }
  }

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
      if (frame.opcode == Fx200Protocol.opCmdAd) {
        final drum = Fx200DrumSettings.decode(frame.body);
        if (drum != null && !_isDrumEcho()) state = state.copyWith(drum: drum);
        return;
      }
    });
    ref.onDispose(() {
      sub.cancel();
      _globalSendTimer?.cancel();
      _drumSendTimer?.cancel();
    });
    return DeviceSettingsState(
      global: sync.lastGlobalSettings,
      drum: sync.lastDrum,
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
}
