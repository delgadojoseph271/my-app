import 'package:dio/dio.dart';
import 'home_dto.dart';

/// Datasource remoto: hace las llamadas HTTP al backend.
/// Solo sabe de JSON y Dio — no sabe nada de entidades ni lógica de negocio.
class HomeRemoteDataSource {
  final Dio _dio;
  HomeRemoteDataSource(this._dio);

  Future<HomeDto> getById(int id) async {
    final response = await _dio.get('/api/v1/homes/$id');
    return HomeDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<HomeDto>> getAll() async {
    final response = await _dio.get('/api/v1/homes/');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => HomeDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<HomeDto> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/homes/', data: data);
    return HomeDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<HomeDto> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/api/v1/homes/$id', data: data);
    return HomeDto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/api/v1/homes/$id');
  }
}
