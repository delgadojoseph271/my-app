import 'auth_entity.dart';

/// Contrato del repository — definido en domain, implementado en data.
/// El dominio solo conoce esta interfaz, nunca la implementación concreta.
abstract class AuthRepository {
  Future<AuthEntity> getById(int id);
  Future<List<AuthEntity>> getAll();
  Future<AuthEntity> create(Map<String, dynamic> data);
  Future<AuthEntity> update(int id, Map<String, dynamic> data);
  Future<void> delete(int id);
}
