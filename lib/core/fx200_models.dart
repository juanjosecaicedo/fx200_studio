import '../domain/entities/preset.dart';

/// Official Flamma FX200 effect module model catalogs and hardware-aligned
/// parameter definitions derived from `FX200_Manual_EN.pdf` and `captura.pcapng`.
class Fx200Models {
  Fx200Models._();

  static const List<String> fxModels = <String>[
    'CS COMP',
    'JR COMP',
    'AUTO WAH',
    '95 CRY',
    '535 CRY',
    'TALK AH',
    'TALK OH',
    'DYNAMIC WAH',
  ];

  static const List<String> overdriveModels = <String>[
    'SMOOTH BOOST',
    'CLEAN BOOST',
    'DARK RAT',
    'GOLD BOX',
    'RIOTER',
    'SCREAMER 808',
    'TUBE OD',
    'ML ZONE',
    'ML MASTER',
    'TIGHT GAIN',
    'TIGHT METAL',
    'VX SILVERY',
    'DIRECT OD',
    'OBSESSIVE OD',
    'UK SHREDDER',
    'FULL DS',
    'RED 500',
    'JIMMY DRIVE',
    'BEEBEE PREAMP',
    'BEEBEE PLUS',
    'ROUND FUZZ',
    'SILVERY FUZZ',
  ];

  static const List<String> ampModels = <String>[
    'US 65 DR',
    'US 65 TR',
    '59 BASSGUY',
    'GALAXY 50 CL',
    'GALAXY 50 OD A',
    'GALAXY 50 OD B',
    'UK COMBO CL',
    'UK COMBO OD',
    'BRIT J45 CL',
    'BRIT J45 DS',
    'BRIT J800',
    'BRIT J900 CL',
    'BRIT J900 DS',
    'BRIT J410 CL',
    'BRIT J410 DS',
    'BRIT PLEXI',
    'BRIT M9004 CL',
    'BRIT M9004 CR',
    'BRIT M9004 DS',
    'FRYMAN 50 CL',
    'FRYMAN 50 CR',
    'FRYMAN 50 DS',
    'FRYMAN 100 CL',
    'FRYMAN 100 OD',
    'FRYMAN 100 DS',
    'Archean 100 CL',
    'Archean 100 DS',
    'CITRUS 100 CL',
    'CITRUS 100 DS',
    'CUSTOM 100 CL',
    'CUSTOM 100 DS',
    'US CLASSIC CL',
    'US CLASSIC DS',
    '5153 GREEN',
    '5153 BLUE',
    '5153 RED',
    'SOLO 100 DS A',
    'SOLO 100 DS B',
    'CALI TEXAS CL',
    'CALI TEXAS OD',
    'CALI REC CL',
    'CALI REC DS',
    'CALI V CR',
    'CALI V DS',
    'SHIVANI CL',
    'SHIVANI OD',
    'ECSTATIC GREEN',
    'ECSTATIC BLUE',
    'ECSTATIC RED',
    'HERBART CH2',
    'HERBART CH3',
    'DIZZY V4 CL',
    'DIZZY V4 CR',
    'DIZZY V4 DS',
    'SEVERE DS A',
    'SEVERE DS B',
    'POWER DS A',
    'POWER DS B',
  ];

  static final List<String> cabModels = <String>[
    '65 DR 112',
    '65 TR 112',
    'BASSGUY 410',
    'GALAXY 112',
    'COMBO 212',
    '1936 212',
    '1960 412 A',
    '1960 412 B',
    'FRYMAN 112',
    'FRYMAN 412',
    'ARCHEAN 212',
    'ARCHEAN 412',
    'CITRUS 112',
    'CITRUS 212',
    'CITRUS 412',
    'CUSTOM 412',
    'US CLASSIC 212',
    '5153 412 A',
    '5153 412 B',
    'SOLO 412',
    'CALI TEXAS 212',
    'CALI REC 412 A',
    'CALI REC 412 B',
    'CALI V 412',
    'BOGNAR 412 A',
    'BOGNAR 412 B',
    'DIZZY 412 A',
    'DIZZY 412 B',
    'SEVERE 412',
    'POWER 412',
    for (var i = 31; i <= 80; i++) 'USER IR $i',
  ];

  static const List<String> nsModels = <String>[
    'SUPPRESSOR',
    'REDUCER',
    'GATE',
  ];

  static const List<String> fxLoopModels = <String>[
    'FX LOOP',
  ];

  static const List<String> eqModels = <String>[
    '6 BAND EQ 1',
    '6 BAND EQ 2',
    '6 BAND EQ 3',
    '4 BAND CUSTOM',
  ];

  static const List<String> modModels = <String>[
    '70S CHORUS',
    'TRI CHORUS',
    'ANA FLANGER',
    'JET FLANGER',
    '70S PHASER',
    'STEP PHASER',
    'HI-CUT PHASER',
    'PITCH VIBRATO',
    'VIBE ROTARY',
    'TREMOLO',
    'STAMMER',
    'DETUNE',
    'RING',
    'LOFI',
    'SLOW GEAR',
    'BAND-PASS',
    'LOW-CUT',
    'HI-CUT',
    'PITCH MONO',
    'PITCH POLY',
  ];

  static const List<String> delayModels = <String>[
    'ANALOG',
    'REAL',
    'TAPE',
    'DIGITAL',
    'PINGPONG',
    'MOD',
    'REVERSE',
    'DYNAMIC',
    'DUAL',
  ];

  static const List<String> reverbModels = <String>[
    'SPRING',
    'ROOM',
    'HALL',
    'CHURCH',
    'PLATE',
    'CAVE',
    'MOD',
  ];

  static BlockParameter _p(
    String id,
    String label,
    double value, {
    double min = 0,
    double max = 100,
    String unit = '',
  }) {
    return BlockParameter(
      id: id,
      label: label,
      value: value,
      defaultValue: value,
      min: min,
      max: max,
      unit: unit,
    );
  }

  /// Builds the 10 default FX200 signal chain blocks with hardware-matched
  /// model lists and parameter counts (`0x91`..`0x9A`).
  static List<EffectBlock> buildDefaultBlocks() {
    return <EffectBlock>[
      EffectBlock(
        id: 'fx200_fx',
        category: EffectCategory.compressor,
        modelName: fxModels.first,
        availableModels: fxModels,
        enabled: true,
        laneIndex: 0,
        slotIndex: 0,
        parameters: <BlockParameter>[
          _p('p0', 'SENS', 48),
          _p('p1', 'ATTACK', 30),
          _p('p2', 'TONE', 48),
          _p('p3', 'LEVEL', 78),
        ],
      ),
      EffectBlock(
        id: 'fx200_od',
        category: EffectCategory.drive,
        modelName: overdriveModels[3],
        availableModels: overdriveModels,
        enabled: true,
        laneIndex: 0,
        slotIndex: 1,
        parameters: <BlockParameter>[
          _p('p0', 'GAIN', 29),
          _p('p1', 'TONE', 86),
          _p('p2', 'LEVEL', 82),
          _p('p3', 'MIX', 80),
          _p('p4', 'MODE', 0, max: 10),
        ],
      ),
      EffectBlock(
        id: 'fx200_amp',
        category: EffectCategory.amp,
        modelName: ampModels.first,
        availableModels: ampModels,
        enabled: true,
        laneIndex: 0,
        slotIndex: 2,
        parameters: <BlockParameter>[
          _p('p0', 'GAIN', 55),
          _p('p1', 'BASS', 50),
          _p('p2', 'MIDDLE', 43),
          _p('p3', 'TREBLE', 64),
          _p('p4', 'PRESENCE', 57),
          _p('p5', 'MASTER', 58),
        ],
      ),
      EffectBlock(
        id: 'fx200_cab',
        category: EffectCategory.cab,
        modelName: cabModels.first,
        availableModels: cabModels,
        enabled: true,
        laneIndex: 0,
        slotIndex: 3,
        parameters: <BlockParameter>[
          _p('p0', 'MIC', 1, max: 10),
          _p('p1', 'CENTER', 0),
          _p('p2', 'DISTANCE', 0),
          _p('p3', 'LOW CUT', 0),
          _p('p4', 'LEVEL', 50),
        ],
      ),
      EffectBlock(
        id: 'fx200_fxloop',
        category: EffectCategory.volume,
        modelName: fxLoopModels.first,
        availableModels: fxLoopModels,
        enabled: false,
        laneIndex: 0,
        slotIndex: 4,
        mode: 'SERIAL',
        parameters: <BlockParameter>[
          _p('p0', 'SEND', 120, max: 132),
          _p('p1', 'RETURN', 120, max: 132),
          _p('p2', 'MIX', 0),
        ],
      ),
      EffectBlock(
        id: 'fx200_ns',
        category: EffectCategory.gate,
        modelName: nsModels.first,
        availableModels: nsModels,
        enabled: false,
        laneIndex: 0,
        slotIndex: 5,
        parameters: <BlockParameter>[
          _p('p0', 'THRES', 5),
          _p('p1', 'DECAY', 0),
          _p('p2', 'ATTACK', 0),
        ],
      ),
      EffectBlock(
        id: 'fx200_eq',
        category: EffectCategory.eq,
        modelName: eqModels.first,
        availableModels: eqModels,
        enabled: false,
        laneIndex: 0,
        slotIndex: 6,
        parameters: <BlockParameter>[
          _p('p0', '100Hz', 24, max: 48),
          _p('p1', '200Hz', 24, max: 48),
          _p('p2', '400Hz', 24, max: 48),
          _p('p3', '800Hz', 24, max: 48),
          _p('p4', '1.6kHz', 24, max: 48),
          _p('p5', '3.2kHz', 24, max: 48),
          _p('p6', 'LEVEL', 50),
          _p('p7', 'LOW CUT', 0),
          _p('p8', 'HI CUT', 0),
        ],
      ),
      EffectBlock(
        id: 'fx200_mod',
        category: EffectCategory.modulation,
        modelName: modModels.first,
        availableModels: modModels,
        enabled: false,
        laneIndex: 0,
        slotIndex: 7,
        parameters: <BlockParameter>[
          _p('p0', 'RATE', 40),
          _p('p1', 'DEPTH', 20),
          _p('p2', 'TONE', 48),
          _p('p3', 'MIX', 50, max: 255),
          _p('p4', 'FEEDBACK', 0),
        ],
      ),
      EffectBlock(
        id: 'fx200_dly',
        category: EffectCategory.delay,
        modelName: delayModels.first,
        availableModels: delayModels,
        enabled: false,
        laneIndex: 0,
        slotIndex: 8,
        parameters: <BlockParameter>[
          _p('p0', 'TIME', 430, max: 2000, unit: 'ms'),
          _p('p1', 'FEEDBACK', 50),
          _p('p2', 'SUBDIV', 6, max: 16),
          _p('p3', 'MIX', 40),
          _p('p4', 'TONE', 50),
          _p('p5', 'MOD', 0),
          _p('p6', 'TRAIL', 0, max: 1),
          _p('p7', 'PINGPONG', 0, max: 1),
        ],
      ),
      EffectBlock(
        id: 'fx200_rev',
        category: EffectCategory.reverb,
        modelName: reverbModels.first,
        availableModels: reverbModels,
        enabled: false,
        laneIndex: 0,
        slotIndex: 9,
        parameters: <BlockParameter>[
          _p('p0', 'DECAY', 64),
          _p('p1', 'MIX', 40),
          _p('p2', 'PRE-DLY', 5),
          _p('p3', 'TONE', 40),
        ],
      ),
    ];
  }

  /// Builds the Model Browser catalog from the real FX200 models.
  static List<CatalogModel> buildCatalog() {
    final defaults = buildDefaultBlocks();
    List<BlockParameter> paramsFor(EffectCategory cat) =>
        defaults.firstWhere((b) => b.category == cat).parameters;

    return <CatalogModel>[
      for (final name in fxModels)
        CatalogModel(
          id: 'fx_$name',
          name: name,
          category: EffectCategory.compressor,
          description: 'FX200 FX / Compressor / Wah',
          defaultParameters: paramsFor(EffectCategory.compressor),
        ),
      for (final name in overdriveModels)
        CatalogModel(
          id: 'od_$name',
          name: name,
          category: EffectCategory.drive,
          description: 'FX200 Overdrive / Distortion',
          defaultParameters: paramsFor(EffectCategory.drive),
        ),
      for (final name in ampModels)
        CatalogModel(
          id: 'amp_$name',
          name: name,
          category: EffectCategory.amp,
          description: 'FX200 Preamp Model',
          defaultParameters: paramsFor(EffectCategory.amp),
        ),
      for (final name in cabModels.take(30))
        CatalogModel(
          id: 'cab_$name',
          name: name,
          category: EffectCategory.cab,
          description: 'FX200 Cabinet 1024pts IR',
          defaultParameters: paramsFor(EffectCategory.cab),
        ),
      for (final name in nsModels)
        CatalogModel(
          id: 'ns_$name',
          name: name,
          category: EffectCategory.gate,
          description: 'FX200 Noise Suppressor',
          defaultParameters: paramsFor(EffectCategory.gate),
        ),
      for (final name in eqModels)
        CatalogModel(
          id: 'eq_$name',
          name: name,
          category: EffectCategory.eq,
          description: 'FX200 Equalizer',
          defaultParameters: paramsFor(EffectCategory.eq),
        ),
      for (final name in modModels)
        CatalogModel(
          id: 'mod_$name',
          name: name,
          category: EffectCategory.modulation,
          description: 'FX200 Modulation',
          defaultParameters: paramsFor(EffectCategory.modulation),
        ),
      for (final name in delayModels)
        CatalogModel(
          id: 'dly_$name',
          name: name,
          category: EffectCategory.delay,
          description: 'FX200 Delay',
          defaultParameters: paramsFor(EffectCategory.delay),
        ),
      for (final name in reverbModels)
        CatalogModel(
          id: 'rev_$name',
          name: name,
          category: EffectCategory.reverb,
          description: 'FX200 Reverb',
          defaultParameters: paramsFor(EffectCategory.reverb),
        ),
    ];
  }
}
