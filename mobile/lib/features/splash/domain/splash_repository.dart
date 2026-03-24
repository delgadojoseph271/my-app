import 'splash_entity.dart';

/// Contrato del repository — definido en domain, implementado en data.
/// El dominio solo conoce esta interfaz, nunca la implementación concreta.
abstract class SplashRepository {
  Future<SplashEntity> getById(int id);
  Future<List<SplashEntity>> getAll();
  Future<SplashEntity> create(Map<String, dynamic> data);
  Future<SplashEntity> update(int id, Map<String, dynamic> data);
  Future<void> delete(int id);
}
