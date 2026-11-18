// GENERATED from the parameter resource embedded in the official FX200
// editor (FX200.exe, zlib XML "resources"). Each entry is
// `min_max_step_decimals_unit` (type 0) or an option list (type 1).
// Raw value on the wire = round((display - min) / step).
// Do not edit by hand; regenerate from the XML if it changes.

import '../domain/entities/preset.dart';

/// Display definition of one module parameter.
class Fx200ParamSpec {
  const Fx200ParamSpec(
    this.label, {
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.decimals = 0,
    this.unit = '',
    this.options = const <String>[],
  });

  final String label;
  final double min;
  final double max;
  final double step;
  final int decimals;
  final String unit;

  /// Non-empty for list parameters (raw = option index).
  final List<String> options;

  bool get isList => options.isNotEmpty;

  /// Highest raw value.
  int get rawMax => isList ? options.length - 1 : ((max - min) / step).round();
}

/// Parameter layout per model (1-based model number - 1), per category.
/// The CAB block is not listed: its page is handled by `CabDesigner`.
const Map<EffectCategory, List<List<Fx200ParamSpec>>>
fx200ParamSpecs = <EffectCategory, List<List<Fx200ParamSpec>>>{
  EffectCategory.compressor: <List<Fx200ParamSpec>>[
    // 1: CS COMP
    <Fx200ParamSpec>[
      Fx200ParamSpec('THRESHOLD', min: -60, max: 0, step: 0.5, unit: 'dB'),
      Fx200ParamSpec(
        'RATIO',
        min: 1,
        max: 10,
        step: 0.2,
        decimals: 1,
        unit: ':1',
      ),
      Fx200ParamSpec('ATTACK'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 2: JR COMP
    <Fx200ParamSpec>[
      Fx200ParamSpec('THRESHOLD', min: -60, max: 0, step: 0.5, unit: 'dB'),
      Fx200ParamSpec(
        'RATIO',
        min: 1,
        max: 10,
        step: 0.2,
        decimals: 1,
        unit: ':1',
      ),
      Fx200ParamSpec('ATTACK'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 3: AUTO WAH
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('RANGE'),
      Fx200ParamSpec('PEAK'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 4: 95 CRY
    <Fx200ParamSpec>[
      Fx200ParamSpec('Q', min: 0.3, max: 5, step: 0.1, decimals: 1),
      Fx200ParamSpec('POSITION'),
      Fx200ParamSpec('PEAK'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 5: 535 CRY
    <Fx200ParamSpec>[
      Fx200ParamSpec('Q', min: 0.3, max: 5, step: 0.1, decimals: 1),
      Fx200ParamSpec('POSITION'),
      Fx200ParamSpec('PEAK'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 6: TALK AH
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('RANGE'),
      Fx200ParamSpec('PEAK'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 7: TALK OH
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('RANGE'),
      Fx200ParamSpec('PEAK'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 8: DYNAMIC WAH
    <Fx200ParamSpec>[
      Fx200ParamSpec('ATTACK'),
      Fx200ParamSpec('SENS'),
      Fx200ParamSpec('PEAK'),
      Fx200ParamSpec('LEVEL'),
    ],
  ],
  EffectCategory.drive: <List<Fx200ParamSpec>>[
    // 1: SMOOTH BOOST
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 2: CLEAN BOOST
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 3: DARK RAT
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 4: GOLD BOX
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 5: RIOTER
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 6: SCREAMER 808
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 7: TUBE OD
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 8: ML ZONE
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 9: ML MASTER
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 10: TIGHT GAIN
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 11: TIGHT METAL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 12: VX SILVERY
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 13: DIRECT OD
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 14: OBSESSIVE OD
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 15: UK SHREDDER
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 16: FULL DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 17: RED 500
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 18: JIMMY DRIVE
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 19: BEEBEE PREAMP
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 20: BEEBEE PLUS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 21: ROUND FUZZ
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
    // 22: SILVERY FUZZ
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('VOLUME'),
    ],
  ],
  EffectCategory.amp: <List<Fx200ParamSpec>>[
    // 1: US 65 DR
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 2: US 65 TR
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 3: 59 BASSGUY
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 4: GALAXY 50 CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 5: GALAXY 50 OD A
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 6: GALAXY 50 OD B
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 7: UK COMBO CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 8: UK COMBO OD
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 9: BRIT J45 CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 10: BRIT J45 DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 11: BRIT J800
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 12: BRIT J900 CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 13: BRIT J900 DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 14: BRIT J410 CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 15: BRIT J410 DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 16: BRIT PLEXI
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 17: BRIT M9004 CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 18: BRIT M9004 CR
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 19: BRIT M9004 DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 20: FRYMAN 50 CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 21: FRYMAN 50 CR
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 22: FRYMAN 50 DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 23: FRYMAN 100 CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 24: FRYMAN 100 OD
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 25: FRYMAN 100 DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 26: ARCHEAN 100 CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 27: ARCHEAN 100 DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 28: CITRUS 100 CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 29: CITRUS 100 DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 30: CUSTOM 100 CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 31: CUSTOM 100 DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 32: US CLASSIC CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 33: US CLASSIC DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 34: 5153 GREEN
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 35: 5153 BLUE
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 36: 5153 RED
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 37: SOLO 100 DS A
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 38: SOLO 100 DS B
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 39: CALI TEXAS CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 40: CALI TEXAS OD
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 41: CALI REC CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 42: CALI REC DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 43: CALI V CR
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 44: CALI V DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 45: SHIVANI CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 46: SHIVANI OD
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 47: ECSTATIC GREEN
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 48: ECSTATIC BLUE
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 49: ECSTATIC RED
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 50: HERBART CH2
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 51: HERBART CH3
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 52: DIZZY V4 CL
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 53: DIZZY V4 CR
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 54: DIZZY V4 DS
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 55: SEVERE DS A
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 56: SEVERE DS B
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 57: POWER DS A
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
    // 58: POWER DS B
    <Fx200ParamSpec>[
      Fx200ParamSpec('GAIN'),
      Fx200ParamSpec('BASS'),
      Fx200ParamSpec('MIDDLE'),
      Fx200ParamSpec('TREBLE'),
      Fx200ParamSpec('PRESENCE'),
      Fx200ParamSpec('MASTER'),
    ],
  ],
  EffectCategory.volume: <List<Fx200ParamSpec>>[
    // 1: SERIAL
    <Fx200ParamSpec>[
      Fx200ParamSpec('SEND LEVEL', min: -60, max: 6, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('RETURN LEVEL', min: -60, max: 6, step: 0.5, unit: 'dB'),
    ],
    // 2: PARALLEL
    <Fx200ParamSpec>[
      Fx200ParamSpec('SEND LEVEL', min: -60, max: 6, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('RETURN LEVEL', min: -60, max: 6, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('MIX'),
    ],
  ],
  EffectCategory.gate: <List<Fx200ParamSpec>>[
    // 1: SUPPRESSOR
    <Fx200ParamSpec>[Fx200ParamSpec('THRESHOLD')],
    // 2: REDUCER
    <Fx200ParamSpec>[Fx200ParamSpec('SENSITIVITY')],
    // 3: GATE
    <Fx200ParamSpec>[
      Fx200ParamSpec('ATTACK'),
      Fx200ParamSpec('RELEASE'),
      Fx200ParamSpec('THRESHOLD'),
    ],
  ],
  EffectCategory.eq: <List<Fx200ParamSpec>>[
    // 1: 6 BAND EQ 1
    <Fx200ParamSpec>[
      Fx200ParamSpec('60Hz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('250Hz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('800Hz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('2kHz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('4kHz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('8kHz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 2: 6 BAND EQ 2
    <Fx200ParamSpec>[
      Fx200ParamSpec('80Hz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('300Hz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('600Hz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('1kHz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('2kHz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('4kHz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 3: 6 BAND EQ 3
    <Fx200ParamSpec>[
      Fx200ParamSpec('100Hz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('500Hz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('800Hz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('2kHz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('4kHz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('6kHz', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 4: 4 BAND CUSTOM
    <Fx200ParamSpec>[
      Fx200ParamSpec('FREQ 1', min: 60, max: 20000, unit: 'Hz'),
      Fx200ParamSpec('GAIN', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('FREQ 2', min: 60, max: 20000, unit: 'Hz'),
      Fx200ParamSpec('GAIN', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('FREQ 3', min: 60, max: 20000, unit: 'Hz'),
      Fx200ParamSpec('GAIN', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('FREQ 4', min: 60, max: 20000, unit: 'Hz'),
      Fx200ParamSpec('GAIN', min: -12, max: 12, step: 0.5, unit: 'dB'),
      Fx200ParamSpec('LEVEL'),
    ],
  ],
  EffectCategory.modulation: <List<Fx200ParamSpec>>[
    // 1: 70S CHORUS
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('DEPTH'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 2: TRI CHORUS
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('DEPTH'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 3: ANA FLANGER
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('FEEDBACK'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 4: JET FLANGER
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('FEEDBACK'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 5: 70S PHASER
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('DEPTH'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 6: STEP PHASER
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('DEPTH'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 7: HI-CUT PHASER
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('DEPTH'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 8: PITCH VIBRATO
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('DEPTH'),
      Fx200ParamSpec('TONE'),
    ],
    // 9: VIBE ROTARY
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 10: TREMOLO
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('DEPTH'),
      Fx200ParamSpec('TONE'),
    ],
    // 11: STAMMER
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('DEPTH'),
      Fx200ParamSpec('TONE'),
    ],
    // 12: DETUNE
    <Fx200ParamSpec>[
      Fx200ParamSpec('PITCH', min: -100, unit: 'Cent'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 13: RING
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('DEPTH'),
      Fx200ParamSpec('TONE'),
    ],
    // 14: LOFI
    <Fx200ParamSpec>[
      Fx200ParamSpec('SAMPLE', min: 12000, max: 44100, unit: 'Hz'),
      Fx200ParamSpec('BIT', min: 1, max: 16, unit: 'BIT'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 15: SLOW GEAR
    <Fx200ParamSpec>[Fx200ParamSpec('ATTACK'), Fx200ParamSpec('LEVEL')],
    // 16: BAND-PASS
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('Q', min: 0.3, max: 5, step: 0.1),
      Fx200ParamSpec('DEPTH'),
    ],
    // 17: LOW-CUT
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('RANGE'),
      Fx200ParamSpec('DEPTH'),
    ],
    // 18: HI-CUT
    <Fx200ParamSpec>[
      Fx200ParamSpec('RATE'),
      Fx200ParamSpec('RANGE'),
      Fx200ParamSpec('DEPTH'),
    ],
    // 19: PITCH MONO
    <Fx200ParamSpec>[
      Fx200ParamSpec('PITCH', min: -12, max: 12, step: 0.1, decimals: 1),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('MIX'),
    ],
    // 20: PITCH POLY
    <Fx200ParamSpec>[
      Fx200ParamSpec('PITCH', min: -12, max: 12, step: 0.1, decimals: 1),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('MIX'),
    ],
  ],
  EffectCategory.delay: <List<Fx200ParamSpec>>[
    // 1: ANALOG
    <Fx200ParamSpec>[
      Fx200ParamSpec('TIME', min: 20, max: 2000, unit: 'ms'),
      Fx200ParamSpec('F.BACK'),
      Fx200ParamSpec(
        'SUB-D',
        options: <String>[
          'OFF',
          '1/4',
          '1/4T',
          '1/4D',
          '1/8',
          '1/8T',
          '1/8D',
          '1/16',
          '1/16T',
          '1/16D',
        ],
      ),
      Fx200ParamSpec('LEVEL'),
    ],
    // 2: REAL
    <Fx200ParamSpec>[
      Fx200ParamSpec('TIME', min: 20, max: 2000, unit: 'ms'),
      Fx200ParamSpec('F.BACK'),
      Fx200ParamSpec(
        'SUB-D',
        options: <String>[
          'OFF',
          '1/4',
          '1/4T',
          '1/4D',
          '1/8',
          '1/8T',
          '1/8D',
          '1/16',
          '1/16T',
          '1/16D',
        ],
      ),
      Fx200ParamSpec('LEVEL'),
    ],
    // 3: TAPE
    <Fx200ParamSpec>[
      Fx200ParamSpec('TIME', min: 20, max: 2000, unit: 'ms'),
      Fx200ParamSpec('F.BACK'),
      Fx200ParamSpec(
        'SUB-D',
        options: <String>[
          'OFF',
          '1/4',
          '1/4T',
          '1/4D',
          '1/8',
          '1/8T',
          '1/8D',
          '1/16',
          '1/16T',
          '1/16D',
        ],
      ),
      Fx200ParamSpec('LEVEL'),
    ],
    // 4: DIGITAL
    <Fx200ParamSpec>[
      Fx200ParamSpec('TIME', min: 20, max: 2000, unit: 'ms'),
      Fx200ParamSpec('F.BACK'),
      Fx200ParamSpec(
        'SUB-D',
        options: <String>[
          'OFF',
          '1/4',
          '1/4T',
          '1/4D',
          '1/8',
          '1/8T',
          '1/8D',
          '1/16',
          '1/16T',
          '1/16D',
        ],
      ),
      Fx200ParamSpec('LEVEL'),
    ],
    // 5: PINGPONG
    <Fx200ParamSpec>[
      Fx200ParamSpec('TIME', min: 20, max: 2000, unit: 'ms'),
      Fx200ParamSpec('F.BACK'),
      Fx200ParamSpec(
        'SUB-D',
        options: <String>[
          'OFF',
          '1/4',
          '1/4T',
          '1/4D',
          '1/8',
          '1/8T',
          '1/8D',
          '1/16',
          '1/16T',
          '1/16D',
        ],
      ),
      Fx200ParamSpec('LEVEL'),
    ],
    // 6: MOD
    <Fx200ParamSpec>[
      Fx200ParamSpec('TIME', min: 20, max: 2000, unit: 'ms'),
      Fx200ParamSpec('F.BACK'),
      Fx200ParamSpec(
        'SUB-D',
        options: <String>[
          'OFF',
          '1/4',
          '1/4T',
          '1/4D',
          '1/8',
          '1/8T',
          '1/8D',
          '1/16',
          '1/16T',
          '1/16D',
        ],
      ),
      Fx200ParamSpec('LEVEL'),
    ],
    // 7: REVERSE
    <Fx200ParamSpec>[
      Fx200ParamSpec('TIME', min: 20, max: 2000, unit: 'ms'),
      Fx200ParamSpec('F.BACK'),
      Fx200ParamSpec(
        'SUB-D',
        options: <String>[
          'OFF',
          '1/4',
          '1/4T',
          '1/4D',
          '1/8',
          '1/8T',
          '1/8D',
          '1/16',
          '1/16T',
          '1/16D',
        ],
      ),
      Fx200ParamSpec('LEVEL'),
    ],
    // 8: DYNAMIC
    <Fx200ParamSpec>[
      Fx200ParamSpec('TIME', min: 20, max: 2000, unit: 'ms'),
      Fx200ParamSpec('F.BACK'),
      Fx200ParamSpec('THRESHOLD'),
      Fx200ParamSpec(
        'SUB-D',
        options: <String>[
          'OFF',
          '1/4',
          '1/4T',
          '1/4D',
          '1/8',
          '1/8T',
          '1/8D',
          '1/16',
          '1/16T',
          '1/16D',
        ],
      ),
      Fx200ParamSpec('LEVEL'),
    ],
    // 9: DUAL
    <Fx200ParamSpec>[
      Fx200ParamSpec('TIME 1', min: 20, max: 2000, unit: 'ms'),
      Fx200ParamSpec(
        'SUB-D 1',
        options: <String>[
          'OFF',
          '1/4',
          '1/4T',
          '1/4D',
          '1/8',
          '1/8T',
          '1/8D',
          '1/16',
          '1/16T',
          '1/16D',
        ],
      ),
      Fx200ParamSpec('PAN 1', min: -100),
      Fx200ParamSpec('TIME 2', min: 20, max: 2000, unit: 'ms'),
      Fx200ParamSpec(
        'SUB-D 2',
        options: <String>[
          'OFF',
          '1/4',
          '1/4T',
          '1/4D',
          '1/8',
          '1/8T',
          '1/8D',
          '1/16',
          '1/16T',
          '1/16D',
        ],
      ),
      Fx200ParamSpec('PAN 2', min: -100),
      Fx200ParamSpec('F.BACK'),
      Fx200ParamSpec('LEVEL'),
    ],
  ],
  EffectCategory.reverb: <List<Fx200ParamSpec>>[
    // 1: SPRING
    <Fx200ParamSpec>[
      Fx200ParamSpec('PRE DELAY', max: 200, unit: 'ms'),
      Fx200ParamSpec('DECAY'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 2: ROOM
    <Fx200ParamSpec>[
      Fx200ParamSpec('PRE DELAY', max: 200, unit: 'ms'),
      Fx200ParamSpec('DECAY'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 3: HALL
    <Fx200ParamSpec>[
      Fx200ParamSpec('PRE DELAY', max: 200, unit: 'ms'),
      Fx200ParamSpec('DECAY'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 4: CHURCH
    <Fx200ParamSpec>[
      Fx200ParamSpec('PRE DELAY', max: 200, unit: 'ms'),
      Fx200ParamSpec('DECAY'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 5: PLATE
    <Fx200ParamSpec>[
      Fx200ParamSpec('PRE DELAY', max: 200, unit: 'ms'),
      Fx200ParamSpec('DECAY'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 6: CAVE
    <Fx200ParamSpec>[
      Fx200ParamSpec('PRE DELAY', max: 200, unit: 'ms'),
      Fx200ParamSpec('DECAY'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
    // 7: MOD
    <Fx200ParamSpec>[
      Fx200ParamSpec('PRE DELAY', max: 200, unit: 'ms'),
      Fx200ParamSpec('DECAY'),
      Fx200ParamSpec('TONE'),
      Fx200ParamSpec('LEVEL'),
    ],
  ],
};
