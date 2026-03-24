import 'package:get_it/get_it.dart';
import 'data/splash_remote_ds.dart';
import 'data/splash_repository_impl.dart';
import 'domain/splash_repository.dart';
import 'domain/splash_usecase.dart';
import 'presentation/splash_bloc.dart';

/// Registra todas las dependencias de la feature Splash en GetIt.
/// Llamar desde core/di/injection.dart en setupDependencies().
void registerSplashDependencies(GetIt sl) {
  // ── Data ──────────────────────────────────────────────────────────────────
  sl.registerLazySingleton(
    () => SplashRemoteDataSource(sl()),  // sl() resuelve Dio
  );

  // ── Repository ────────────────────────────────────────────────────────────
  sl.registerLazySingleton<SplashRepository>(
    () => SplashRepositoryImpl(sl()),
  );

  // ── Use cases ─────────────────────────────────────────────────────────────
  sl.registerFactory(() => GetSplashUseCase(sl()));
  sl.registerFactory(() => GetAllSplashsUseCase(sl()));

  // ── BLoC ──────────────────────────────────────────────────────────────────
  sl.registerFactory(
    () => SplashBloc(
      getAll: sl(),
      getById: sl(),
    ),
  );
}
