import 'package:dio/dio.dart';
import 'splash_dto.dart';

/// Datasource remoto: hace las llamadas HTTP al backend.
/// Solo sabe de JSON y Dio — no sabe nada de entidades ni lógica de negocio.
class SplashRemoteDataSource {
  final Dio _dio;
  SplashRemoteDataSource(this._dio);

  Future<SplashDto> getById(int id) async {
    final response = await _dio.get('/api/v1/splashs/$id');
    return SplashDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SplashDto>> getAll() async {
    final response = await _dio.get('/api/v1/splashs/');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => SplashDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SplashDto> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/splashs/', data: data);
    return SplashDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<SplashDto> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/api/v1/splashs/$id', data: data);
    return SplashDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/api/v1/splashs/$id');
  }
}
