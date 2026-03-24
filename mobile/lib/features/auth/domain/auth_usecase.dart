import 'auth_entity.dart';
import 'auth_repository.dart';

/// Caso de uso: obtener un Auth por id.
/// Un use case = una acción del usuario = una responsabilidad.
class GetAuthUseCase {
  final AuthRepository _repository;
  GetAuthUseCase(this._repository);

  Future<AuthEntity> call(int id) {
    return _repository.getById(id);
  }
}

/// Caso de uso: obtener todos los Auths.
class GetAllAuthsUseCase {
  final AuthRepository _repository;
  GetAllAuthsUseCase(this._repository);

  Future<List<AuthEntity>> call() {
    return _repository.getAll();
  }
}

// Agregá más use cases según las acciones de la feature:
// class CreateAuthUseCase { ... }
// class DeleteAuthUseCase { ... }
