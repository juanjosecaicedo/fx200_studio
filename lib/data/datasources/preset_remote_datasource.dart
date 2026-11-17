import 'package:http/http.dart' as http;

import '../../domain/entities/preset.dart';
import '../models/preset_model.dart';

/// Remote/mock data source accepting an injected [http.Client].
class PresetRemoteDataSource {
  PresetRemoteDataSource({required this.client});

  // Kept injected for future remote sync without changing callers.
  final http.Client client;

  final Map<int, PresetModel> _mockStorage = <int, PresetModel>{};

  Future<PresetModel> fetchPreset(int patchNumber) async {
    final existing = _mockStorage[patchNumber];
    if (existing != null) return existing;

    final seed = _buildSeedPreset(patchNumber);
    _mockStorage[patchNumber] = seed;
    return seed;
  }

  Future<void> savePreset(PresetModel model) async {
    _mockStorage[model.patchNumber] = model;
  }

  Future<List<CatalogModel>> fetchModelCatalog() async {
    return _defaultCatalog;
  }

  static PresetModel _buildSeedPreset(int patchNumber) {
    final blocks = <EffectBlockModel>[
      const EffectBlockModel(
        id: 'blk_gate',
        category: 'gate',
        modelName: 'Hard Gate',
        availableModels: <String>['Hard Gate', 'Adaptive Gate', 'Studio Noise Gate'],
        enabled: true,
        laneIndex: 0,
        slotIndex: 0,
        mode: 'Stereo',
        parameters: <BlockParameterModel>[
          BlockParameterModel(
            id: 'thresh',
            label: 'THRESHOLD',
            value: -48,
            defaultValue: -50,
            min: -90,
            max: 0,
            unit: 'dB',
            kind: 'knob',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'release',
            label: 'RELEASE',
            value: 35,
            defaultValue: 40,
            min: 5,
            max: 500,
            unit: 'ms',
            kind: 'knob',
            options: <String>[],
          ),
        ],
      ),
      const EffectBlockModel(
        id: 'blk_drive',
        category: 'drive',
        modelName: 'TS808 Overdrive',
        availableModels: <String>['TS808 Overdrive', 'Klon Centaur', 'RAT Distortion', 'BB Preamp'],
        enabled: true,
        laneIndex: 0,
        slotIndex: 1,
        mode: 'Mono',
        parameters: <BlockParameterModel>[
          BlockParameterModel(
            id: 'drive',
            label: 'DRIVE',
            value: 38,
            defaultValue: 35,
            min: 0,
            max: 100,
            unit: '%',
            kind: 'knob',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'tone',
            label: 'TONE',
            value: 56,
            defaultValue: 50,
            min: 0,
            max: 100,
            unit: '%',
            kind: 'knob',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'level',
            label: 'LEVEL',
            value: 72,
            defaultValue: 70,
            min: 0,
            max: 100,
            unit: '%',
            kind: 'knob',
            options: <String>[],
          ),
        ],
      ),
      const EffectBlockModel(
        id: 'blk_amp',
        category: 'amp',
        modelName: 'NAM A2 · FNDR BFSR Edge',
        availableModels: <String>[
          'NAM A2 · FNDR BFSR Edge',
          'NAM A2 · Brit JCM800',
          'FX200 US Deluxe 65',
          'FX200 Recto Modern',
        ],
        enabled: true,
        laneIndex: 0,
        slotIndex: 2,
        mode: 'NAM Slim 35%',
        parameters: <BlockParameterModel>[
          BlockParameterModel(
            id: 'gain',
            label: 'GAIN',
            value: 54,
            defaultValue: 50,
            min: 0,
            max: 100,
            unit: '',
            kind: 'knob',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'bass',
            label: 'BASS',
            value: 48,
            defaultValue: 50,
            min: 0,
            max: 100,
            unit: '',
            kind: 'knob',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'mid',
            label: 'MID',
            value: 62,
            defaultValue: 50,
            min: 0,
            max: 100,
            unit: '',
            kind: 'knob',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'treble',
            label: 'TREBLE',
            value: 59,
            defaultValue: 50,
            min: 0,
            max: 100,
            unit: '',
            kind: 'knob',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'presence',
            label: 'PRESENCE',
            value: 50,
            defaultValue: 50,
            min: 0,
            max: 100,
            unit: '',
            kind: 'knob',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'master',
            label: 'MASTER',
            value: 68,
            defaultValue: 65,
            min: 0,
            max: 100,
            unit: '',
            kind: 'knob',
            options: <String>[],
          ),
        ],
      ),
      const EffectBlockModel(
        id: 'blk_cab',
        category: 'cab',
        modelName: '4x12 V30 IR (1024 pts)',
        availableModels: <String>[
          '4x12 V30 IR (1024 pts)',
          '2x12 Greenback IR',
          '1x12 Twin Jensen IR',
        ],
        enabled: true,
        laneIndex: 0,
        slotIndex: 3,
        mode: '44.1kHz 24b',
        parameters: <BlockParameterModel>[
          BlockParameterModel(
            id: 'lowcut',
            label: 'LOW CUT',
            value: 85,
            defaultValue: 80,
            min: 20,
            max: 300,
            unit: 'Hz',
            kind: 'slider',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'highcut',
            label: 'HIGH CUT',
            value: 6800,
            defaultValue: 7500,
            min: 1500,
            max: 16000,
            unit: 'Hz',
            kind: 'slider',
            options: <String>[],
          ),
        ],
      ),
      const EffectBlockModel(
        id: 'blk_delay',
        category: 'delay',
        modelName: 'Analog Tape Delay',
        availableModels: <String>['Analog Tape Delay', 'Digital Ping-Pong', 'Reverse Delay'],
        enabled: true,
        laneIndex: 0,
        slotIndex: 4,
        mode: 'Stereo',
        parameters: <BlockParameterModel>[
          BlockParameterModel(
            id: 'time',
            label: 'TIME',
            value: 420,
            defaultValue: 400,
            min: 20,
            max: 1200,
            unit: 'ms',
            kind: 'knob',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'feedback',
            label: 'FEEDBACK',
            value: 34,
            defaultValue: 30,
            min: 0,
            max: 95,
            unit: '%',
            kind: 'knob',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'mix',
            label: 'MIX',
            value: 28,
            defaultValue: 25,
            min: 0,
            max: 100,
            unit: '%',
            kind: 'knob',
            options: <String>[],
          ),
        ],
      ),
      const EffectBlockModel(
        id: 'blk_reverb',
        category: 'reverb',
        modelName: 'Studio Plate',
        availableModels: <String>['Studio Plate', 'Spring 63', 'Church Hall', 'Shimmer'],
        enabled: false,
        laneIndex: 0,
        slotIndex: 5,
        mode: 'Trails ON',
        parameters: <BlockParameterModel>[
          BlockParameterModel(
            id: 'decay',
            label: 'DECAY',
            value: 45,
            defaultValue: 40,
            min: 0,
            max: 100,
            unit: '%',
            kind: 'knob',
            options: <String>[],
          ),
          BlockParameterModel(
            id: 'mix',
            label: 'MIX',
            value: 22,
            defaultValue: 20,
            min: 0,
            max: 100,
            unit: '%',
            kind: 'knob',
            options: <String>[],
          ),
        ],
      ),
    ];

    return PresetModel(
      id: 'preset_$patchNumber',
      patchNumber: patchNumber,
      name: patchNumber == 0 ? 'F Deluxe 65 · NAM A2' : 'FX200 Patch #$patchNumber',
      activeScene: 'A',
      bpm: 120.0,
      outputLevelDb: 0.0,
      parallelSplitEnabled: false,
      blocks: blocks,
    );
  }

  static const List<CatalogModel> _defaultCatalog = <CatalogModel>[
    CatalogModel(
      id: 'cat_amp_nam_jcm',
      name: 'NAM A2 · Brit JCM800',
      category: EffectCategory.amp,
      description: 'High-gain British stack capture (Slim 35%)',
      defaultParameters: <BlockParameter>[
        BlockParameter(id: 'gain', label: 'GAIN', value: 65, defaultValue: 50),
        BlockParameter(id: 'bass', label: 'BASS', value: 52, defaultValue: 50),
        BlockParameter(id: 'mid', label: 'MID', value: 60, defaultValue: 50),
        BlockParameter(id: 'treble', label: 'TREBLE', value: 64, defaultValue: 50),
        BlockParameter(id: 'master', label: 'MASTER', value: 60, defaultValue: 60),
      ],
    ),
    CatalogModel(
      id: 'cat_drive_klon',
      name: 'Klon Centaur',
      category: EffectCategory.drive,
      description: 'Transparent overdrive & mid boost',
      defaultParameters: <BlockParameter>[
        BlockParameter(id: 'drive', label: 'GAIN', value: 42, defaultValue: 40, unit: '%'),
        BlockParameter(id: 'tone', label: 'TREBLE', value: 55, defaultValue: 50, unit: '%'),
        BlockParameter(id: 'level', label: 'OUTPUT', value: 70, defaultValue: 70, unit: '%'),
      ],
    ),
    CatalogModel(
      id: 'cat_mod_chorus',
      name: 'Analog Tri-Chorus',
      category: EffectCategory.modulation,
      description: 'Lush stereo BBD chorus',
      defaultParameters: <BlockParameter>[
        BlockParameter(id: 'rate', label: 'RATE', value: 32, defaultValue: 30, unit: '%'),
        BlockParameter(id: 'depth', label: 'DEPTH', value: 48, defaultValue: 50, unit: '%'),
        BlockParameter(id: 'mix', label: 'MIX', value: 40, defaultValue: 40, unit: '%'),
      ],
    ),
    CatalogModel(
      id: 'cat_eq_para',
      name: '4-Band Parametric EQ',
      category: EffectCategory.eq,
      description: 'Surgical tone shaping',
      defaultParameters: <BlockParameter>[
        BlockParameter(id: 'low', label: 'LOW', value: 0, defaultValue: 0, min: -12, max: 12, unit: 'dB'),
        BlockParameter(id: 'mid', label: 'MID', value: 2, defaultValue: 0, min: -12, max: 12, unit: 'dB'),
        BlockParameter(id: 'high', label: 'HIGH', value: 1.5, defaultValue: 0, min: -12, max: 12, unit: 'dB'),
      ],
    ),
    CatalogModel(
      id: 'cat_delay_pp',
      name: 'Digital Ping-Pong',
      category: EffectCategory.delay,
      description: 'Synced stereo ping-pong delay',
      defaultParameters: <BlockParameter>[
        BlockParameter(id: 'time', label: 'TIME', value: 375, defaultValue: 400, min: 20, max: 1200, unit: 'ms'),
        BlockParameter(id: 'feedback', label: 'FEEDBACK', value: 40, defaultValue: 35, unit: '%'),
        BlockParameter(id: 'mix', label: 'MIX', value: 30, defaultValue: 25, unit: '%'),
      ],
    ),
    CatalogModel(
      id: 'cat_rev_hall',
      name: 'Church Hall',
      category: EffectCategory.reverb,
      description: 'Wide ambient hall reverb',
      defaultParameters: <BlockParameter>[
        BlockParameter(id: 'decay', label: 'DECAY', value: 64, defaultValue: 50, unit: '%'),
        BlockParameter(id: 'mix', label: 'MIX', value: 30, defaultValue: 25, unit: '%'),
      ],
    ),
  ];
}
