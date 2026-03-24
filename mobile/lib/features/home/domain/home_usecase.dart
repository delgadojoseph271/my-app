import 'home_entity.dart';
import 'home_repository.dart';

/// Caso de uso: obtener un Home por id.
/// Un use case = una acción del usuario = una responsabilidad.
class GetHomeUseCase {
  final HomeRepository _repository;
  GetHomeUseCase(this._repository);

  Future<HomeEntity> call(int id) {
    return _repository.getById(id);
  }
}

/// Caso de uso: obtener todos los Homes.
class GetAllHomesUseCase {
  final HomeRepository _repository;
  GetAllHomesUseCase(this._repository);

  Future<List<HomeEntity>> call() {
    return _repository.getAll();
  }
}

// Agregá más use cases según las acciones de la feature:
// class CreateHomeUseCase { ... }
// class DeleteHomeUseCase { ... }
