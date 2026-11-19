import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/preset.dart';
import '../../services/fx200_protocol.dart';
import 'editor_notifier.dart';

/// Expression-pedal view of the active preset for the EXPRESSION PEDAL
/// window: PEDAL 1 (internal) in EXPRESSION or VOLUME mode, PEDAL 2
/// (external jack) in EXPRESSION mode only.
///
/// The data itself lives in the preset ([PresetControls], owned by
/// [EditorNotifier]), so EXP edits share the preset's undo history and its
/// single "unsaved" state; this notifier only adapts it for the dialog.
class ExpPedalState {
  const ExpPedalState({
    this.loaded = false,
    this.pedal1Mode = Fx200ExpFrame.modeExpression,
    this.pedal1 = const <ExpAssignment>[],
    this.pedal2 = const <ExpAssignment>[],
    this.volume,
    this.unsaved = false,
  });

  /// True once the pedal has reported the preset's `0xA3` frames.
  final bool loaded;
  final int pedal1Mode;
  final List<ExpAssignment> pedal1;
  final List<ExpAssignment> pedal2;

  /// VOLUME-mode range of PEDAL 1 (`0xAE`), null until reported.
  final Fx200VolumePedalRange? volume;

  /// True while the active preset has unsaved changes (any kind).
  final bool unsaved;

  List<ExpAssignment> assignmentsFor(int pedal) =>
      pedal == Fx200ExpFrame.pedalInternal ? pedal1 : pedal2;

  ExpPedalState copyWith({
    bool? loaded,
    int? pedal1Mode,
    List<ExpAssignment>? pedal1,
    List<ExpAssignment>? pedal2,
    Fx200VolumePedalRange? volume,
    bool? unsaved,
  }) {
    return ExpPedalState(
      loaded: loaded ?? this.loaded,
      pedal1Mode: pedal1Mode ?? this.pedal1Mode,
      pedal1: pedal1 ?? this.pedal1,
      pedal2: pedal2 ?? this.pedal2,
      volume: volume ?? this.volume,
      unsaved: unsaved ?? this.unsaved,
    );
  }

  ExpPedalState withAssignments(int pedal, List<ExpAssignment> list) =>
      pedal == Fx200ExpFrame.pedalInternal
      ? copyWith(pedal1: List.unmodifiable(list))
      : copyWith(pedal2: List.unmodifiable(list));
}

final expPedalProvider = NotifierProvider<ExpPedalNotifier, ExpPedalState>(
  ExpPedalNotifier.new,
);

class ExpPedalNotifier extends Notifier<ExpPedalState> {
  @override
  ExpPedalState build() {
    final editor = ref.watch(editorProvider);
    final c = editor.preset?.controls ?? const PresetControls();
    return ExpPedalState(
      loaded: c.expKnown,
      pedal1Mode: c.exp1Mode,
      pedal1: c.exp1,
      pedal2: c.exp2,
      volume: c.volumeKnown
          ? Fx200VolumePedalRange(min: c.volumeMin, max: c.volumeMax)
          : null,
      unsaved: editor.hasUnsavedChanges,
    );
  }

  PresetControls get _controls =>
      ref.read(editorProvider).preset?.controls ?? const PresetControls();

  void _edit(PresetControls next, {bool recordHistory = true}) => ref
      .read(editorProvider.notifier)
      .editControls(next, recordHistory: recordHistory);

  /// Switches PEDAL 1 between EXPRESSION and VOLUME.
  void setPedal1Mode(int mode) {
    if (mode == _controls.exp1Mode) return;
    _edit(_controls.copyWith(exp1Mode: mode));
  }

  /// Assigns a module parameter to [pedal] (or updates it). [debounce] is
  /// used while a slider is dragged (no undo entry per step).
  void setAssignment(int pedal, ExpAssignment a, {bool debounce = false}) {
    final c = _controls;
    final list = [
      for (final x in c.assignmentsFor(pedal))
        x.sameTarget(a.moduleSlot, a.paramIndex) ? a : x,
    ];
    if (!list.any((x) => x.sameTarget(a.moduleSlot, a.paramIndex))) {
      list.add(a);
    }
    _edit(c.withAssignments(pedal, list), recordHistory: !debounce);
  }

  /// Removes an assignment (sent as heel = toe = 0, like the official editor).
  void removeAssignment(int pedal, ExpAssignment a) {
    final c = _controls;
    _edit(
      c.withAssignments(pedal, [
        for (final x in c.assignmentsFor(pedal))
          if (!x.sameTarget(a.moduleSlot, a.paramIndex)) x,
      ]),
    );
  }

  /// Sets PEDAL 1's VOLUME-mode heel/toe range (0..100 %).
  void setVolumeRange(Fx200VolumePedalRange range, {bool debounce = false}) {
    _edit(
      _controls.copyWith(
        volumeKnown: true,
        volumeMin: range.min,
        volumeMax: range.max,
      ),
      recordHistory: !debounce,
    );
  }

  /// Persists the whole preset (modules + controls) with `0xA8`.
  Future<void> saveToPreset() =>
      ref.read(editorProvider.notifier).saveCurrentPreset();
}
