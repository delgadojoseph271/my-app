import '../domain/splash_entity.dart';
import '../domain/splash_repository.dart';
// import 'splash_dto.dart';
import 'splash_remote_ds.dart';

/// Implementación concreta del repository.
/// Implementa la interfaz del dominio usando el datasource remoto.
/// Si mañana agregás cache local, lo hacés aquí sin tocar el dominio.
class SplashRepositoryImpl implements SplashRepository {
  final SplashRemoteDataSource _remote;
  // final SplashLocalDataSource _local; // para cache

  SplashRepositoryImpl(this._remote);

  @override
  Future<SplashEntity> getById(int id) async {
    final dto = await _remote.getById(id);
    return dto.toEntity();
  }

  @override
  Future<List<SplashEntity>> getAll() async {
    final dtos = await _remote.getAll();
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<SplashEntity> create(Map<String, dynamic> data) async {
    final dto = await _remote.create(data);
    return dto.toEntity();
  }

  @override
  Future<SplashEntity> update(int id, Map<String, dynamic> data) async {
    final dto = await _remote.update(id, data);
    return dto.toEntity();
  }

  @override
  Future<void> delete(int id) async {
    await _remote.delete(id);
  }
}
