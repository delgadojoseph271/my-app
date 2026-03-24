import 'package:get_it/get_it.dart';
import 'data/home_remote_ds.dart';
import 'data/home_repository_impl.dart';
import 'domain/home_repository.dart';
import 'domain/home_usecase.dart';
import 'presentation/home_bloc.dart';

/// Registra todas las dependencias de la feature Home en GetIt.
/// Llamar desde core/di/injection.dart en setupDependencies().
void registerHomeDependencies(GetIt sl) {
  // ── Data ──────────────────────────────────────────────────────────────────
  sl.registerLazySingleton(
    () => HomeRemoteDataSource(sl()),  // sl() resuelve Dio
  );

  // ── Repository ────────────────────────────────────────────────────────────
  sl.registerLazySingleton<HomeRepository>(
    () => HomeRepositoryImpl(sl()),
  );

  // ── Use cases ─────────────────────────────────────────────────────────────
  sl.registerFactory(() => GetHomeUseCase(sl()));
  sl.registerFactory(() => GetAllHomesUseCase(sl()));

  // ── BLoC ──────────────────────────────────────────────────────────────────
  sl.registerFactory(
    () => HomeBloc(
      getAll: sl(),
      getById: sl(),
    ),
  );
}
