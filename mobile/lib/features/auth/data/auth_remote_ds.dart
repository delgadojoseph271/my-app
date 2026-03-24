import 'package:dio/dio.dart';
import 'auth_dto.dart';

/// Datasource remoto: hace las llamadas HTTP al backend.
/// Solo sabe de JSON y Dio — no sabe nada de entidades ni lógica de negocio.
class AuthRemoteDataSource {
  final Dio _dio;
  AuthRemoteDataSource(this._dio);

  Future<AuthDto> getById(int id) async {
    final response = await _dio.get('/api/v1/auths/$id');
    return AuthDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<AuthDto>> getAll() async {
    final response = await _dio.get('/api/v1/auths/');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => AuthDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AuthDto> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/auths/', data: data);
    return AuthDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AuthDto> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/api/v1/auths/$id', data: data);
    return AuthDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/api/v1/auths/$id');
  }
}
