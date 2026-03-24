// core/di/injection.dart
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/auth_injection.dart';
import '../../features/splash/splash_injection.dart';
import '../../features/home/home_injection.dart';

final sl = GetIt.instance;

Future<void> setupDependencies() async {
  // Core — las dependencias que todos necesitan
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  sl.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(sl()),
  );
  sl.registerLazySingleton<Dio>(() => createDioClient(sl()));

  // Features — cada una registra sus propias dependencias
  registerAuthDependencies(sl);
  registerSplashDependencies(sl);
  registerHomeDependencies(sl);

  // registerHomeDependencies(sl);  ← agregar cuando la crees
}
