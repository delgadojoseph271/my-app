import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;

  AuthInterceptor(this._storage);

  // ── 1. ANTES de cada request ─────────────────────────
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.getToken();

    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  // ── 2. CUANDO llega un error del backend ─────────────
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token inválido o expirado — limpiar storage
      // El router va a detectar que no hay sesión y redirige al login
      await _storage.deleteToken();
    }
    // handler.next() = "dejá pasar el error hacia el datasource"
    handler.next(err);
  }
}
