import '../entities/preset.dart';

/// Abstract contract for loading, saving, and browsing multi-FX presets.
abstract class PresetRepository {
  Future<Preset> getPreset(int patchNumber);
  Future<void> savePreset(Preset preset);
  Future<List<CatalogModel>> getModelCatalog();
}
