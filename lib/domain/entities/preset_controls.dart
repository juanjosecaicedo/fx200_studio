/// One module parameter driven by an expression pedal: [min] at heel down,
/// [max] at toe down, both in the parameter's raw units.
class ExpAssignment {
  const ExpAssignment({
    required this.moduleSlot,
    required this.paramIndex,
    required this.min,
    required this.max,
  });

  final int moduleSlot;
  final int paramIndex;
  final int min;
  final int max;

  bool sameTarget(int slot, int param) =>
      moduleSlot == slot && paramIndex == param;

  ExpAssignment copyWith({int? min, int? max}) => ExpAssignment(
    moduleSlot: moduleSlot,
    paramIndex: paramIndex,
    min: min ?? this.min,
    max: max ?? this.max,
  );

  @override
  bool operator ==(Object other) =>
      other is ExpAssignment &&
      other.moduleSlot == moduleSlot &&
      other.paramIndex == paramIndex &&
      other.min == min &&
      other.max == max;

  @override
  int get hashCode => Object.hash(moduleSlot, paramIndex, min, max);
}

/// The per-preset controller setup the FX200 stores with every preset
/// besides its modules (all saved together by `0xA8`):
///
/// * footswitch mode + CTRL modules (`0xA4`, the BPM part lives in
///   `Preset.bpm`);
/// * expression pedals: PEDAL 1 mode and the assignments of both pedals
///   (`0xA3`);
/// * PEDAL 1 VOLUME range (`0xAE`).
///
/// Each part is "known" only once the pedal reported it, so the UI can wait
/// instead of showing defaults that are not on the pedal.
class PresetControls {
  const PresetControls({
    this.footswitchKnown = false,
    this.footswitchMode = 0,
    this.ctrlMask = 0,
    this.expKnown = false,
    this.exp1Mode = 0,
    this.exp1 = const <ExpAssignment>[],
    this.exp2 = const <ExpAssignment>[],
    this.volumeKnown = false,
    this.volumeMin = 0,
    this.volumeMax = 100,
  });

  final bool footswitchKnown;
  final int footswitchMode;
  final int ctrlMask;

  final bool expKnown;

  /// PEDAL 1 mode: 0 = EXPRESSION, 1 = VOLUME.
  final int exp1Mode;
  final List<ExpAssignment> exp1;
  final List<ExpAssignment> exp2;

  final bool volumeKnown;
  final int volumeMin;
  final int volumeMax;

  List<ExpAssignment> assignmentsFor(int pedal) => pedal == 0 ? exp1 : exp2;

  PresetControls withAssignments(int pedal, List<ExpAssignment> list) =>
      pedal == 0
      ? copyWith(exp1: List.unmodifiable(list))
      : copyWith(exp2: List.unmodifiable(list));

  PresetControls copyWith({
    bool? footswitchKnown,
    int? footswitchMode,
    int? ctrlMask,
    bool? expKnown,
    int? exp1Mode,
    List<ExpAssignment>? exp1,
    List<ExpAssignment>? exp2,
    bool? volumeKnown,
    int? volumeMin,
    int? volumeMax,
  }) {
    return PresetControls(
      footswitchKnown: footswitchKnown ?? this.footswitchKnown,
      footswitchMode: footswitchMode ?? this.footswitchMode,
      ctrlMask: ctrlMask ?? this.ctrlMask,
      expKnown: expKnown ?? this.expKnown,
      exp1Mode: exp1Mode ?? this.exp1Mode,
      exp1: exp1 ?? this.exp1,
      exp2: exp2 ?? this.exp2,
      volumeKnown: volumeKnown ?? this.volumeKnown,
      volumeMin: volumeMin ?? this.volumeMin,
      volumeMax: volumeMax ?? this.volumeMax,
    );
  }
}
