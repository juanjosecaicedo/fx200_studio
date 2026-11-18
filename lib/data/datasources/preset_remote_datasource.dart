import 'package:http/http.dart' as http;

import '../../core/fx200_models.dart';
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
    return Fx200Models.buildCatalog();
  }

  static PresetModel _buildSeedPreset(int patchNumber) {
    final entity = Preset(
      id: 'preset_$patchNumber',
      patchNumber: patchNumber,
      name: Fx200Models.defaultPresetName(patchNumber),
      activeScene: 'A',
      bpm: 120.0,
      outputLevelDb: 0.0,
      parallelSplitEnabled: false,
      blocks: Fx200Models.buildDefaultBlocks(),
    );
    return PresetModel.fromEntity(entity);
  }
}
