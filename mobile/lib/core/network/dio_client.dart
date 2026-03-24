import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'auth_interceptor.dart';
import '../storage/secure_storage.dart';

// Constante que lee la URL del entorno al compilar
// flutter run --dart-define=API_URL=http://tu-servidor.com

const _kApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8000',
);

Dio createDioClient(SecureStorageService storage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _kApiUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.addAll([
    AuthInterceptor(storage),
    // LogInterceptor solo en debug — en producción sobra
    if (const bool.fromEnvironment('dart.vm.product') == false)
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (log) => debugPrint('[DIO] $log'),
      ),
  ]);

  return dio;
}
