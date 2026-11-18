import 'fx200_param_specs.dart';
import '../domain/entities/preset.dart';

/// Official Flamma FX200 effect module model catalogs and hardware-aligned
/// parameter definitions derived from `FX200_Manual_EN.pdf` and `captura.pcapng`.
class Fx200Models {
  Fx200Models._();

  static const List<String> defaultPresetNames = <String>[
    'F Deluxe 65',
    'F Twin 65',
    'F Bass 59',
    'Galaxy 50 Clean',
    'Galaxy 50 Lead',
    'Galaxy 50 Dist',
    'Combo 30 Clean',
    'Combo 30 Drive',
    'Brit J45 Clean',
    'Brit J45 Dist',
    'Brit J800',
    'Brit J900 Clean',
    'Brit J900 Dist',
    'Brit J410 Clean',
    'Brit J410 Dist',
    'Brit Plexi',
    'M9004 Clean',
    'M9004 Crunch',
    'M9004 Lead',
    'Fryman 50 Clean',
    'Fryman 50 Dist',
    'Fryman 50 Lead',
    'Fryman 100 CL',
    'Fryman 100 Dist',
    'Fryman 100 Lead',
    'Archean Clean',
    'Archean Lead',
    'Citrus Clean',
    'Citrus Dist',
    'Custom 100 CL',
    'Custom 100 Lead',
    'US Classic CL',
    'US Classic Dist',
    '5153 Green',
    '5153 Blue',
    '5153 Red',
    'Solo 100 Rhythm',
    'Solo 100 Lead',
    'Cali TX Clean',
    'Cali TX Drive',
    'Cali Rec Clean',
    'Cali Rec Dist',
    'Cali V Crunch',
    'Cali V Dist',
    'Shivani Clean',
    'Shivani Drive',
    'Ecstatic Green',
    'Ecstatic Blue',
    'Ecstatic Red',
    'Herbart CH2',
    'Herbart CH3',
    'Dizzy V4 Clean',
    'Dizzy V4 Crunch',
    'Dizzy V4 Dist',
    'Severe Rhythm',
    'Severe Lead',
    'Power Rhythm',
    'Power Lead',
    'Ballad Chorus',
    'Sweet Drive',
    'Pop Drive',
    'Soloist',
    '12 Strings Sim',
    'Country Road',
    'Jazz Standard',
    'Funky Groove',
    'Classic Metal',
    'Punk Boy',
    'Popular Band',
    'Blues Lead',
    'Crying Man',
    'Surf Rock',
    'Pop Rock',
    'Post Rock',
    'Fusion Lead',
    'Metal Core',
    'Prog Rock',
    'Neo Soul',
    'Slap Back',
    'Slow Gear',
    'Deep In The Sea',
    'Into The Sky',
    'Shabby Room',
    'Mountain Valley',
    'Black Hole',
    'Low Cut Riff',
    'Fake Bass',
    'ACG Drive',
    'Tremolo Clean',
    'Flanger Dist',
    'Blue Comet',
    'Deep Memories',
    'Emotional Lead',
    'Dynamic Wah',
    'Octave Lead',
    'Bittersweet',
    'Imagination',
    'OCT 1 Whammy',
    'Chorus Lead',
    'Vinyl Record',
    'EMMOTION LEAD',
    'Empty',
    'Empty',
    'AMBIENTE',
    'Worship Clean',
    'Worship Drive',
    'WORSHIP STRON',
    'WORSHIP LEAD',
    'DOTTED LEAD',
    'DIRVE WAH',
    'Empty',
    'DISTORSION WHA',
    'CLEAN',
    'DRIVE',
    'DIST',
    'H1 LEAD',
    'H1 WP',
    'H1 PHASER',
    'H1 PITCH',
    'H1 VIBE ROTARY',
    'H1 TREMOLO',
    'H1 TUNE',
    'H1 SLOW',
    'H1 PITCH MONO',
    'H1 PITCH MONO',
    'TOMALO',
    'AMBIENTE',
    'Worship Drive',
    'AC30 CLEAN',
    'AC30 DRIVE',
    'AC30 CRUNCH',
    'AC30 LEAD',
    'J45 BRIT CHORUS',
    'J45 BRIT TREMO',
    'J45 BRIT DIST',
    'J45 BRIT 8D',
    'TL MATCH DC30',
    'TL MATCH DC30 T',
    'TL MATCH DC30 C',
    'TL MATCH DC30 P',
    'J900 V1 LEAD',
    'J900 V1 LEAD CH',
    'J900 V1 LEAD TM',
    'J900 LEAD CHT',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'Empty',
    'J WORSHIP VI 1',
    'J WORSHIP CH 3',
    'J WORSHIP CH 3',
    'J WORSHIP LEAD',
    'CLEAN',
    'Empty',
  ];

  static String defaultPresetName(int patchNumber) {
    if (patchNumber >= 0 && patchNumber < defaultPresetNames.length) {
      return defaultPresetNames[patchNumber];
    }
    return 'FX200 Patch #$patchNumber';
  }

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
    'ARCHEAN 100 CL',
    'ARCHEAN 100 DS',
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

  static const List<String> fxLoopModels = <String>['SERIAL', 'PARALLEL'];

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

  /// CAB TUBE options in the order the pedal lists them (raw 0..4).
  static const List<String> cabTubeOptions = <String>[
    'OFF',
    '6L6',
    '6V6',
    'EL34',
    'EL84',
  ];

  /// CAB LOW CUT: 0 = OFF, otherwise Hz up to 800.
  static const double cabLowCutMinHz = 20;
  static const double cabLowCutMaxHz = 800;

  /// CAB HI CUT: 0 = OFF, otherwise Hz from 3000 up to 20000.
  static const double cabHiCutMinHz = 3000;
  static const double cabHiCutMaxHz = 20000;

  static const String eqCustomModel = '4 BAND CUSTOM';

  /// Fixed band centres (Hz) of each 6-band EQ model.
  static const Map<String, List<double>> eqBandHz = <String, List<double>>{
    '6 BAND EQ 1': <double>[60, 250, 800, 2000, 4000, 8000],
    '6 BAND EQ 2': <double>[80, 300, 600, 1000, 2000, 4000],
    '6 BAND EQ 3': <double>[100, 500, 800, 2000, 4000, 6000],
  };

  /// Default FREQ 1..4 of 4 BAND CUSTOM (as shown by the pedal).
  static const List<double> eqCustomDefaultHz = <double>[100, 800, 2000, 4000];

  static bool isEqCustom(String modelName) => modelName == eqCustomModel;

  static String formatHz(double hz) {
    if (hz >= 1000) {
      final k = hz / 1000;
      return k == k.roundToDouble()
          ? '${k.round()}kHz'
          : '${k.toStringAsFixed(1)}kHz';
    }
    return '${hz.round()}Hz';
  }

  /// Words carried after the model in each `0x91..0x9A` frame (captures).
  /// Models that show fewer parameters still send all of them.
  static const Map<EffectCategory, int> frameWordCount = <EffectCategory, int>{
    EffectCategory.compressor: 4,
    EffectCategory.drive: 5,
    EffectCategory.amp: 6,
    EffectCategory.cab: 5,
    EffectCategory.volume: 3,
    EffectCategory.gate: 3,
    EffectCategory.eq: 9,
    EffectCategory.modulation: 5,
    EffectCategory.delay: 8,
    EffectCategory.reverb: 4,
  };

  /// Model list of each FX200 module.
  static List<String> modelsFor(EffectCategory category) {
    switch (category) {
      case EffectCategory.compressor:
        return fxModels;
      case EffectCategory.drive:
        return overdriveModels;
      case EffectCategory.amp:
        return ampModels;
      case EffectCategory.cab:
        return cabModels;
      case EffectCategory.volume:
        return fxLoopModels;
      case EffectCategory.gate:
        return nsModels;
      case EffectCategory.eq:
        return eqModels;
      case EffectCategory.modulation:
        return modModels;
      case EffectCategory.delay:
        return delayModels;
      case EffectCategory.reverb:
        return reverbModels;
    }
  }

  /// Parameter list for EQ model [modelName] (default values).
  static List<BlockParameter> eqParameters(String modelName) =>
      parametersForModel(EffectCategory.eq, modelName)!;

  /// Parameter layout of [modelName] with default values, built from the
  /// official editor's parameter table ([fx200ParamSpecs]) and padded with
  /// hidden words up to the frame size. Null for CAB (own designer page).
  static List<BlockParameter>? parametersForModel(
    EffectCategory category,
    String modelName,
  ) {
    final table = fx200ParamSpecs[category];
    if (table == null || table.isEmpty) return null;
    final idx = modelsFor(category)
        .indexWhere((m) => m.toUpperCase() == modelName.toUpperCase());
    // Unknown model (e.g. a NAM capture): keep the block's own layout.
    if (idx < 0 || idx >= table.length) return null;
    final specs = table[idx];
    final words = frameWordCount[category] ?? specs.length;
    var bandFreq = 0;
    return <BlockParameter>[
      for (var i = 0; i < specs.length; i++)
        _fromSpec(
          'p$i',
          specs[i],
          specs[i].label.startsWith('FREQ')
              ? eqCustomDefaultHz[(bandFreq++).clamp(0, 3)]
              : null,
        ),
      for (var i = specs.length; i < words; i++) _reserved('p$i'),
    ];
  }

  /// [block] with its model's labels/ranges applied to its current values
  /// (e.g. presets saved by older versions of the app).
  static EffectBlock withModelLayout(EffectBlock block) {
    final template = parametersForModel(block.category, block.modelName);
    if (template == null) return block;
    final params = <BlockParameter>[
      for (var i = 0; i < template.length; i++)
        if (i < block.parameters.length)
          (block.parameters[i].value > template[i].max
                  ? template[i].withMax(block.parameters[i].value)
                  : template[i])
              .copyWith(value: block.parameters[i].value)
        else
          template[i],
    ];
    return block.copyWith(parameters: params);
  }

  static BlockParameter _fromSpec(
    String id,
    Fx200ParamSpec spec,
    double? displayDefault,
  ) {
    final rawMax = spec.rawMax.toDouble();
    double display;
    if (displayDefault != null) {
      display = displayDefault;
    } else if (spec.min < 0 && spec.max > 0) {
      display = 0;
    } else if (spec.unit == 'ms') {
      display = 500;
    } else if (spec.label == 'SAMPLE' || spec.label == 'BIT') {
      display = spec.max;
    } else {
      display = (spec.min + spec.max) / 2;
    }
    final raw = spec.isList
        ? 0.0
        : ((display - spec.min) / spec.step).roundToDouble().clamp(0, rawMax);
    return BlockParameter(
      id: id,
      label: spec.label,
      value: raw.toDouble(),
      defaultValue: raw.toDouble(),
      max: rawMax,
      unit: spec.unit,
      kind: spec.isList ? BlockParameterKind.mode : BlockParameterKind.knob,
      options: spec.options,
      displayMin: spec.isList ? 0 : spec.min,
      displayStep: spec.isList ? 1 : spec.step,
      // 0.5-step values show one decimal on the pedal ("0.0dB").
      decimals: spec.step < 1 && spec.decimals == 0 ? 1 : spec.decimals,
    );
  }

  static BlockParameter _reserved(String id) => BlockParameter(
    id: id,
    label: 'RESERVED',
    value: 0,
    defaultValue: 0,
    max: 65535,
    kind: BlockParameterKind.reserved,
  );

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
        parameters: parametersForModel(
          EffectCategory.compressor,
          fxModels.first,
        )!,
      ),
      EffectBlock(
        id: 'fx200_od',
        category: EffectCategory.drive,
        modelName: overdriveModels[3],
        availableModels: overdriveModels,
        enabled: true,
        laneIndex: 0,
        slotIndex: 1,
        parameters: parametersForModel(
          EffectCategory.drive,
          overdriveModels[3],
        )!,
      ),
      EffectBlock(
        id: 'fx200_amp',
        category: EffectCategory.amp,
        modelName: ampModels.first,
        availableModels: ampModels,
        enabled: true,
        laneIndex: 0,
        slotIndex: 2,
        parameters: parametersForModel(EffectCategory.amp, ampModels.first)!,
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
          // Real CAB page of the pedal: TUBE, LOW CUT, HI CUT, SPACE, LEVEL.
          // LOW/HI CUT travel as Hz (0 = OFF); verified on all 200 presets.
          const BlockParameter(
            id: 'p0',
            label: 'TUBE',
            value: 1,
            defaultValue: 1,
            max: 4,
            kind: BlockParameterKind.mode,
            options: cabTubeOptions,
          ),
          _p('p1', 'LOW CUT', 0, max: cabLowCutMaxHz, unit: 'Hz'),
          _p('p2', 'HI CUT', 0, max: cabHiCutMaxHz, unit: 'Hz'),
          _p('p3', 'SPACE', 0),
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
        parameters: parametersForModel(
          EffectCategory.volume,
          fxLoopModels.first,
        )!,
      ),
      EffectBlock(
        id: 'fx200_ns',
        category: EffectCategory.gate,
        modelName: nsModels.first,
        availableModels: nsModels,
        enabled: false,
        laneIndex: 0,
        slotIndex: 5,
        parameters: parametersForModel(EffectCategory.gate, nsModels.first)!,
      ),
      EffectBlock(
        id: 'fx200_eq',
        category: EffectCategory.eq,
        modelName: eqModels.first,
        availableModels: eqModels,
        enabled: false,
        laneIndex: 0,
        slotIndex: 6,
        parameters: eqParameters(eqModels.first),
      ),
      EffectBlock(
        id: 'fx200_mod',
        category: EffectCategory.modulation,
        modelName: modModels.first,
        availableModels: modModels,
        enabled: false,
        laneIndex: 0,
        slotIndex: 7,
        parameters: parametersForModel(
          EffectCategory.modulation,
          modModels.first,
        )!,
      ),
      EffectBlock(
        id: 'fx200_dly',
        category: EffectCategory.delay,
        modelName: delayModels.first,
        availableModels: delayModels,
        enabled: false,
        laneIndex: 0,
        slotIndex: 8,
        parameters: parametersForModel(
          EffectCategory.delay,
          delayModels.first,
        )!,
      ),
      EffectBlock(
        id: 'fx200_rev',
        category: EffectCategory.reverb,
        modelName: reverbModels.first,
        availableModels: reverbModels,
        enabled: false,
        laneIndex: 0,
        slotIndex: 9,
        parameters: parametersForModel(
          EffectCategory.reverb,
          reverbModels.first,
        )!,
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
          defaultParameters: parametersForModel(
            EffectCategory.compressor,
            name,
          )!,
        ),
      for (final name in overdriveModels)
        CatalogModel(
          id: 'od_$name',
          name: name,
          category: EffectCategory.drive,
          description: 'FX200 Overdrive / Distortion',
          defaultParameters: parametersForModel(EffectCategory.drive, name)!,
        ),
      for (final name in ampModels)
        CatalogModel(
          id: 'amp_$name',
          name: name,
          category: EffectCategory.amp,
          description: 'FX200 Preamp Model',
          defaultParameters: parametersForModel(EffectCategory.amp, name)!,
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
          defaultParameters: parametersForModel(EffectCategory.gate, name)!,
        ),
      for (final name in eqModels)
        CatalogModel(
          id: 'eq_$name',
          name: name,
          category: EffectCategory.eq,
          description: 'FX200 Equalizer',
          defaultParameters: eqParameters(name),
        ),
      for (final name in modModels)
        CatalogModel(
          id: 'mod_$name',
          name: name,
          category: EffectCategory.modulation,
          description: 'FX200 Modulation',
          defaultParameters: parametersForModel(
            EffectCategory.modulation,
            name,
          )!,
        ),
      for (final name in delayModels)
        CatalogModel(
          id: 'dly_$name',
          name: name,
          category: EffectCategory.delay,
          description: 'FX200 Delay',
          defaultParameters: parametersForModel(EffectCategory.delay, name)!,
        ),
      for (final name in reverbModels)
        CatalogModel(
          id: 'rev_$name',
          name: name,
          category: EffectCategory.reverb,
          description: 'FX200 Reverb',
          defaultParameters: parametersForModel(EffectCategory.reverb, name)!,
        ),
    ];
  }
}
