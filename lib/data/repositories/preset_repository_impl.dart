import '../../domain/entities/preset.dart';
import '../../domain/repositories/preset_repository.dart';
import '../datasources/preset_remote_datasource.dart';
import '../models/preset_model.dart';

class PresetRepositoryImpl implements PresetRepository {
  const PresetRepositoryImpl(this._remoteDataSource);

  final PresetRemoteDataSource _remoteDataSource;

  @override
  Future<Preset> getPreset(int patchNumber) async {
    final model = await _remoteDataSource.fetchPreset(patchNumber);
    return model.toEntity();
  }

  @override
  Future<void> savePreset(Preset preset) {
    return _remoteDataSource.savePreset(PresetModel.fromEntity(preset));
  }

  @override
  Future<List<CatalogModel>> getModelCatalog() {
    return _remoteDataSource.fetchModelCatalog();
  }
}
