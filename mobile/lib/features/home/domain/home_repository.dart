import 'home_entity.dart';

/// Contrato del repository — definido en domain, implementado en data.
/// El dominio solo conoce esta interfaz, nunca la implementación concreta.
abstract class HomeRepository {
  Future<HomeEntity> getById(int id);
  Future<List<HomeEntity>> getAll();
  Future<HomeEntity> create(Map<String, dynamic> data);
  Future<HomeEntity> update(int id, Map<String, dynamic> data);
  Future<void> delete(int id);
}
