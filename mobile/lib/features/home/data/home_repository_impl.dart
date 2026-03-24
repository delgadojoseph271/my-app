import '../domain/home_entity.dart';
import '../domain/home_repository.dart';
// import 'home_dto.dart';
import 'home_remote_ds.dart';

/// Implementación concreta del repository.
/// Implementa la interfaz del dominio usando el datasource remoto.
/// Si mañana agregás cache local, lo hacés aquí sin tocar el dominio.
class HomeRepositoryImpl implements HomeRepository {
  final HomeRemoteDataSource _remote;
  // final HomeLocalDataSource _local; // para cache

  HomeRepositoryImpl(this._remote);

  @override
  Future<HomeEntity> getById(int id) async {
    final dto = await _remote.getById(id);
    return dto.toEntity();
  }

  @override
  Future<List<HomeEntity>> getAll() async {
    final dtos = await _remote.getAll();
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<HomeEntity> create(Map<String, dynamic> data) async {
    final dto = await _remote.create(data);
    return dto.toEntity();
  }

  @override
  Future<HomeEntity> update(int id, Map<String, dynamic> data) async {
    final dto = await _remote.update(id, data);
    return dto.toEntity();
  }

  @override
  Future<void> delete(int id) async {
    await _remote.delete(id);
  }
}
