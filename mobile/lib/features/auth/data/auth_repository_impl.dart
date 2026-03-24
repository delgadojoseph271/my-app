import '../domain/auth_entity.dart';
import '../domain/auth_repository.dart';
// import 'auth_dto.dart';
import 'auth_remote_ds.dart';

/// Implementación concreta del repository.
/// Implementa la interfaz del dominio usando el datasource remoto.
/// Si mañana agregás cache local, lo hacés aquí sin tocar el dominio.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  // final AuthLocalDataSource _local; // para cache

  AuthRepositoryImpl(this._remote);

  @override
  Future<AuthEntity> getById(int id) async {
    final dto = await _remote.getById(id);
    return dto.toEntity();
  }

  @override
  Future<List<AuthEntity>> getAll() async {
    final dtos = await _remote.getAll();
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<AuthEntity> create(Map<String, dynamic> data) async {
    final dto = await _remote.create(data);
    return dto.toEntity();
  }

  @override
  Future<AuthEntity> update(int id, Map<String, dynamic> data) async {
    final dto = await _remote.update(id, data);
    return dto.toEntity();
  }

  @override
  Future<void> delete(int id) async {
    await _remote.delete(id);
  }
}
