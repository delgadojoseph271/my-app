import 'splash_entity.dart';
import 'splash_repository.dart';

/// Caso de uso: obtener un Splash por id.
/// Un use case = una acción del usuario = una responsabilidad.
class GetSplashUseCase {
  final SplashRepository _repository;
  GetSplashUseCase(this._repository);

  Future<SplashEntity> call(int id) {
    return _repository.getById(id);
  }
}

/// Caso de uso: obtener todos los Splashs.
class GetAllSplashsUseCase {
  final SplashRepository _repository;
  GetAllSplashsUseCase(this._repository);

  Future<List<SplashEntity>> call() {
    return _repository.getAll();
  }
}

// Agregá más use cases según las acciones de la feature:
// class CreateSplashUseCase { ... }
// class DeleteSplashUseCase { ... }
