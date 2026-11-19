import 'dart:typed_data';

/// Global SYSTEM settings carried by the `0xA1` frame (46-byte body).
///
/// The pedal sends this block right after `0xE0` and `FX200.exe` sends the
/// whole block back on every SYSTEM change (`sub_411f70`), so the layout is the
/// same in both directions. Byte offsets come from the SYSTEMDLG slots in
/// `FX200.exe` (`0x447880`..`0x448470`) that write into the mirror at
/// `0xE536C4`. Bytes not listed here are preserved as received.
///
/// | body | field                                             |
/// |------|---------------------------------------------------|
/// | 1    | USB MIX (0..100)                                  |
/// | 2    | USB RIGHT OUTPUT (0 = EFFECTS, 1 = DRY)           |
/// | 3    | USB LEFT OUTPUT (0 = EFFECTS, 1 = DRY)            |
/// | 4    | USB REC VOL (0..100)                              |
/// | 5    | USB PLAY VOL (0..100)                             |
/// | 6, 7 | GLOBAL CAB left / right (0/1)                     |
/// | 8    | CAB SYNC (0/1)                                    |
/// | 11   | FS MODE (0 NORMAL, 1 FAVORITE, 2 DUAL)            |
/// | 16   | INPUT LEVEL, stored dB + 1 (official editor: 0..20 dB) |
/// | 18   | BRIGHTNESS (0..100)                               |
/// | 21   | LOOPER POSITION (0 PRE, 1 POST)                   |
/// | 22   | DLY/REV SPILL-OVER (0/1)                          |
/// | 23   | MIDI port direction (0 IN, 1 OUT)                 |
/// | 25   | MIDI channel (0..15 = CH1..16, 16 = OMNI, IN only)|
/// | 27   | MIDI SYNC CLOCK (0/1)                             |
/// | 28   | GLOBAL EQ on/off                                  |
/// | 30.. | GLOBAL EQ u16 little-endian words (see getters)   |
class Fx200GlobalSettings {
  Fx200GlobalSettings._(this._raw);

  /// Wraps a received `0xA1` body. Shorter bodies are zero-padded.
  factory Fx200GlobalSettings.fromBody(List<int> body) {
    final raw = Uint8List(length);
    for (var i = 0; i < length && i < body.length; i++) {
      raw[i] = body[i] & 0xff;
    }
    return Fx200GlobalSettings._(raw);
  }

  /// Size of the `0xA1` body (`len = 0x2F` including the opcode).
  static const int length = 46;

  static const int fsModeNormal = 0;
  static const int fsModeFavorite = 1;
  static const int fsModeDual = 2;

  static const int midiChannelOmni = 16;

  /// Band gain encoding: `0..48`, `24 == 0 dB`, 0.5 dB per step (same scale
  /// as the per-preset EQ module). Inferred from captured values.
  static const int eqGainCenter = 24;
  static const int eqGainMax = 48;

  final Uint8List _raw;

  /// Copy of the raw 46-byte body (what gets sent back in `0xA1`).
  Uint8List get raw => Uint8List.fromList(_raw);

  int _u16(int offset) => _raw[offset] | (_raw[offset + 1] << 8);

  Fx200GlobalSettings _with(Map<int, int> bytes) {
    final next = Uint8List.fromList(_raw);
    bytes.forEach((offset, value) => next[offset] = value & 0xff);
    return Fx200GlobalSettings._(next);
  }

  Fx200GlobalSettings _withU16(int offset, int value) {
    return _with(<int, int>{offset: value & 0xff, offset + 1: value >> 8});
  }

  int get usbMix => _raw[1];
  bool get usbRightDry => _raw[2] != 0;
  bool get usbLeftDry => _raw[3] != 0;
  int get usbRecVol => _raw[4];
  int get usbPlayVol => _raw[5];
  bool get globalCabLeft => _raw[6] != 0;
  bool get globalCabRight => _raw[7] != 0;
  bool get cabSync => _raw[8] != 0;
  int get fsMode => _raw[11];
  int get brightness => _raw[18];

  /// INPUT LEVEL in dB as the official editor shows it (slider 0..20 dB,
  /// stored as dB + 1: `0x44bdfc` reads `value - 1`, `0x447a7d` writes
  /// `slider + 1`; `captura-input-level.pcapng` changes only this byte).
  int get inputLevelDb => (_raw[16] - 1).clamp(0, 20);
  bool get looperPost => _raw[21] != 0;
  bool get spillOver => _raw[22] != 0;
  bool get midiOut => _raw[23] != 0;
  int get midiChannel => _raw[25];
  bool get midiClockSync => _raw[27] != 0;
  bool get globalEqEnabled => _raw[28] != 0;
  int get eqLowFreqHz => _u16(30);
  int get eqLowGain => _u16(32);
  int get eqMidFreqHz => _u16(34);
  int get eqMidGain => _u16(36);
  int get eqHighFreqHz => _u16(38);
  int get eqHighGain => _u16(40);
  int get eqHighCutHz => _u16(42);
  int get eqLowCutHz => _u16(44);

  static double gainToDb(int raw) => (raw - eqGainCenter) / 2.0;
  static int dbToGain(double db) =>
      (db * 2.0).round().clamp(-eqGainCenter, eqGainCenter) + eqGainCenter;

  Fx200GlobalSettings withUsbMix(int v) => _with({1: v.clamp(0, 100)});
  Fx200GlobalSettings withUsbRightDry(bool v) => _with({2: v ? 1 : 0});
  Fx200GlobalSettings withUsbLeftDry(bool v) => _with({3: v ? 1 : 0});
  Fx200GlobalSettings withUsbRecVol(int v) => _with({4: v.clamp(0, 100)});
  Fx200GlobalSettings withUsbPlayVol(int v) => _with({5: v.clamp(0, 100)});
  Fx200GlobalSettings withGlobalCabLeft(bool v) => _with({6: v ? 1 : 0});
  Fx200GlobalSettings withGlobalCabRight(bool v) => _with({7: v ? 1 : 0});
  Fx200GlobalSettings withCabSync(bool v) => _with({8: v ? 1 : 0});
  Fx200GlobalSettings withFsMode(int v) =>
      _with({11: v.clamp(fsModeNormal, fsModeDual)});
  Fx200GlobalSettings withBrightness(int v) => _with({18: v.clamp(0, 100)});
  Fx200GlobalSettings withInputLevelDb(int db) =>
      _with({16: db.clamp(0, 20) + 1});
  Fx200GlobalSettings withLooperPost(bool v) => _with({21: v ? 1 : 0});
  Fx200GlobalSettings withSpillOver(bool v) => _with({22: v ? 1 : 0});

  /// Switching the MIDI port direction resets the channel to CH1, like
  /// `FX200.exe` does (`0x448451`), because OMNI only exists in IN mode.
  Fx200GlobalSettings withMidiOut(bool v) => _with({23: v ? 1 : 0, 25: 0});

  Fx200GlobalSettings withMidiChannel(int v) =>
      _with({25: v.clamp(0, midiOut ? 15 : midiChannelOmni)});
  Fx200GlobalSettings withMidiClockSync(bool v) => _with({27: v ? 1 : 0});
  Fx200GlobalSettings withGlobalEqEnabled(bool v) => _with({28: v ? 1 : 0});
  Fx200GlobalSettings withEqLowFreqHz(int v) =>
      _withU16(30, v.clamp(40, 20000));
  Fx200GlobalSettings withEqLowGain(int v) =>
      _withU16(32, v.clamp(0, eqGainMax));
  Fx200GlobalSettings withEqMidFreqHz(int v) =>
      _withU16(34, v.clamp(40, 20000));
  Fx200GlobalSettings withEqMidGain(int v) =>
      _withU16(36, v.clamp(0, eqGainMax));
  Fx200GlobalSettings withEqHighFreqHz(int v) =>
      _withU16(38, v.clamp(40, 20000));
  Fx200GlobalSettings withEqHighGain(int v) =>
      _withU16(40, v.clamp(0, eqGainMax));
  Fx200GlobalSettings withEqHighCutHz(int v) =>
      _withU16(42, v.clamp(3000, 20000));
  Fx200GlobalSettings withEqLowCutHz(int v) => _withU16(44, v.clamp(40, 1000));

  @override
  bool operator ==(Object other) {
    if (other is! Fx200GlobalSettings) return false;
    for (var i = 0; i < length; i++) {
      if (_raw[i] != other._raw[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_raw);
}

/// Per-preset footswitch assignment carried by `0xA4`
/// (`[fsMode, ctrlMask u16BE, bpm u16BE]`).
///
/// `FX200.exe` toggles bit *i* of the mask for CTRL list item *i*
/// (`0x439d10`), so several modules can be assigned at once. The list items
/// follow the module slot order (FX, DS/OD, AMP, CAB, FX LOOP, NS, EQ, MOD,
/// DLY, REV). Like on the pedal, the assignment must be saved to the preset
/// (`0xA8`) to persist.
class Fx200FootswitchConfig {
  const Fx200FootswitchConfig({
    required this.mode,
    required this.ctrlMask,
    required this.bpm,
  });

  static const int modeOff = 0;
  static const int modeCtrl = 1;
  static const int modeTap = 2;

  static const List<String> ctrlModuleNames = <String>[
    'FX',
    'DS / OD',
    'AMP',
    'CAB',
    'FX LOOP',
    'NS',
    'EQ',
    'MOD',
    'DLY',
    'REV',
  ];

  final int mode;
  final int ctrlMask;
  final int bpm;

  bool isCtrlAssigned(int slot) => (ctrlMask >> slot) & 1 == 1;

  Fx200FootswitchConfig withCtrlAssigned(int slot, bool assigned) {
    final bit = 1 << slot;
    return copyWith(ctrlMask: assigned ? (ctrlMask | bit) : (ctrlMask & ~bit));
  }

  Fx200FootswitchConfig copyWith({int? mode, int? ctrlMask, int? bpm}) {
    return Fx200FootswitchConfig(
      mode: mode ?? this.mode,
      ctrlMask: (ctrlMask ?? this.ctrlMask) & 0xffff,
      bpm: (bpm ?? this.bpm).clamp(40, 260),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Fx200FootswitchConfig &&
      other.mode == mode &&
      other.ctrlMask == ctrlMask &&
      other.bpm == bpm;

  @override
  int get hashCode => Object.hash(mode, ctrlMask, bpm);
}

/// One expression-pedal assignment carried by `0xA3` (10-byte body):
///
/// | body | field                                                         |
/// |------|---------------------------------------------------------------|
/// | 0    | pedal: 0 = PEDAL 1 (internal), 1 = PEDAL 2 (external jack)    |
/// | 1    | mode of that pedal: 0 = EXPRESSION, 1 = VOLUME (PEDAL 1 only) |
/// | 2    | module slot + 1 (FX, DS/OD, AMP, CAB, FX LOOP, NS, EQ, ...)   |
/// | 3    | parameter index inside the module (`0x91..0x9A` order)        |
/// | 4, 5 | value at toe down (maximum), u16 big-endian, raw units        |
/// | 6, 7 | value at heel down (minimum), u16 big-endian                  |
/// | 8, 9 | assigned flag, u16 big-endian (1 while min or max is non-zero) |
///
/// From `FX200.exe`: the sender is `0x411d50`, the receiver `0x42c290`; the
/// PEDALDLG slots `slot_minExpValueChanged` (`0x43c200`) and
/// `slot_maxExpValueChanged` (`0x43c770`) fill the min and max tables, and the
/// flag drops to 0 when both are 0 (which is how an assignment is deleted).
/// One frame carries one module parameter; a preset may hold several.
class Fx200ExpFrame {
  const Fx200ExpFrame({
    required this.pedal,
    required this.mode,
    required this.moduleSlot,
    required this.paramIndex,
    required this.min,
    required this.max,
    required this.assigned,
  });

  static const int pedalInternal = 0;
  static const int pedalExternal = 1;
  static const int modeExpression = 0;
  static const int modeVolume = 1;

  final int pedal;
  final int mode;
  final int moduleSlot;
  final int paramIndex;
  final int min;
  final int max;
  final bool assigned;

  static Fx200ExpFrame? decode(List<int> body) {
    if (body.length < 10) return null;
    final module = body[2] & 0xff;
    return Fx200ExpFrame(
      pedal: body[0] & 0xff,
      mode: body[1] & 0xff,
      // The pedal (like FX200.exe at 0x42d6a4) treats 0 as the first module.
      moduleSlot: module == 0 ? 0 : module - 1,
      paramIndex: body[3] & 0xff,
      max: (body[4] & 0xff) << 8 | (body[5] & 0xff),
      min: (body[6] & 0xff) << 8 | (body[7] & 0xff),
      assigned: ((body[8] & 0xff) << 8 | (body[9] & 0xff)) != 0,
    );
  }

  List<int> encode() {
    final lo = min.clamp(0, 0xffff);
    final hi = max.clamp(0, 0xffff);
    final flag = assigned && (lo != 0 || hi != 0) ? 1 : 0;
    return <int>[
      pedal & 0xff,
      mode & 0xff,
      (moduleSlot + 1) & 0xff,
      paramIndex & 0xff,
      hi >> 8,
      hi & 0xff,
      lo >> 8,
      lo & 0xff,
      0,
      flag,
    ];
  }
}

/// Range of PEDAL 1 in VOLUME mode, carried by `0xAE`
/// (`[0, max, 0, min]`, 0..100 %). `FX200.exe` builds it at `0x411eb0` from
/// the PEDALDLG volume slots (`0x43aba0`..`0x43aec3`); the pedal reports
/// `00 64 00 00` (heel 0 %, toe 100 %) by default.
class Fx200VolumePedalRange {
  const Fx200VolumePedalRange({required this.min, required this.max});

  static const Fx200VolumePedalRange standard = Fx200VolumePedalRange(
    min: 0,
    max: 100,
  );

  final int min;
  final int max;

  static Fx200VolumePedalRange? decode(List<int> body) {
    if (body.length < 4) return null;
    return Fx200VolumePedalRange(
      min: (body[3] & 0xff).clamp(0, 100),
      max: (body[1] & 0xff).clamp(0, 100),
    );
  }

  List<int> encode() => <int>[0, max.clamp(0, 100), 0, min.clamp(0, 100)];

  Fx200VolumePedalRange copyWith({int? min, int? max}) =>
      Fx200VolumePedalRange(min: min ?? this.min, max: max ?? this.max);

  @override
  bool operator ==(Object other) =>
      other is Fx200VolumePedalRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);
}

/// Drum machine / metronome state carried by `0xAD` (10-byte body, global):
///
/// | body | field                                                        |
/// |------|--------------------------------------------------------------|
/// | 1    | on/off (0/1)                                                 |
/// | 3    | style: 1..8 = RHYTHM styles, 9 = METRONOME                   |
/// | 5    | rhythm type inside the style ("TEMPO" in the manual), 1..10  |
/// | 6, 7 | BPM, u16 big-endian (40..260)                                |
/// | 9    | volume (0..100)                                              |
///
/// From `FX200.exe`: sender `0x411cc0`, receiver `0x42c250`; DRUMDLG switches
/// to METRONOME by writing style 9 / type 1 (`0x447411`) and back to RHYTHM
/// with style 1 / type 1 (`0x4472ca`). Bytes 0, 2, 4 and 8 are always 0.
class Fx200DrumSettings {
  const Fx200DrumSettings({
    required this.on,
    required this.style,
    required this.groove,
    required this.bpm,
    required this.volume,
  });

  static const int rhythmStyleCount = 8;
  static const int metronomeStyle = 9;
  static const int grooveCount = 10;
  static const int minBpm = 40;
  static const int maxBpm = 260;

  final bool on;
  final int style;
  final int groove;
  final int bpm;
  final int volume;

  bool get isMetronome => style == metronomeStyle;

  static Fx200DrumSettings? decode(List<int> body) {
    if (body.length < 10) return null;
    return Fx200DrumSettings(
      on: (body[1] & 0xff) != 0,
      style: (body[3] & 0xff).clamp(1, metronomeStyle),
      groove: (body[5] & 0xff).clamp(1, grooveCount),
      bpm: ((body[6] & 0xff) << 8 | (body[7] & 0xff)).clamp(minBpm, maxBpm),
      volume: (body[9] & 0xff).clamp(0, 100),
    );
  }

  List<int> encode() {
    final b = bpm.clamp(minBpm, maxBpm);
    return <int>[
      0,
      on ? 1 : 0,
      0,
      style.clamp(1, metronomeStyle),
      0,
      groove.clamp(1, grooveCount),
      b >> 8,
      b & 0xff,
      0,
      volume.clamp(0, 100),
    ];
  }

  /// Switches between RHYTHM (style 1) and METRONOME (style 9) like the
  /// official editor, which also resets the rhythm type to 1.
  Fx200DrumSettings withMetronome(bool metronome) =>
      copyWith(style: metronome ? metronomeStyle : 1, groove: 1);

  Fx200DrumSettings copyWith({
    bool? on,
    int? style,
    int? groove,
    int? bpm,
    int? volume,
  }) {
    return Fx200DrumSettings(
      on: on ?? this.on,
      style: style ?? this.style,
      groove: groove ?? this.groove,
      bpm: bpm ?? this.bpm,
      volume: volume ?? this.volume,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Fx200DrumSettings &&
      other.on == on &&
      other.style == style &&
      other.groove == groove &&
      other.bpm == bpm &&
      other.volume == volume;

  @override
  int get hashCode => Object.hash(on, style, groove, bpm, volume);
}
