import 'package:get_it/get_it.dart';
import 'data/auth_remote_ds.dart';
import 'data/auth_repository_impl.dart';
import 'domain/auth_repository.dart';
import 'domain/auth_usecase.dart';
import 'presentation/auth_bloc.dart';

/// Registra todas las dependencias de la feature Auth en GetIt.
/// Llamar desde core/di/injection.dart en setupDependencies().
void registerAuthDependencies(GetIt sl) {
  // ── Data ──────────────────────────────────────────────────────────────────
  sl.registerLazySingleton(
    () => AuthRemoteDataSource(sl()),  // sl() resuelve Dio
  );

  // ── Repository ────────────────────────────────────────────────────────────
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl()),
  );

  // ── Use cases ─────────────────────────────────────────────────────────────
  sl.registerFactory(() => GetAuthUseCase(sl()));
  sl.registerFactory(() => GetAllAuthsUseCase(sl()));

  // ── BLoC ──────────────────────────────────────────────────────────────────
  sl.registerFactory(
    () => AuthBloc(
      getAll: sl(),
      getById: sl(),
    ),
  );
}
