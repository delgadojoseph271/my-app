import '../domain/splash_entity.dart';

/// DTO (Data Transfer Object): convierte JSON del API → Entity del dominio.
/// Solo existe en la capa data — el dominio no sabe que existe.
class SplashDto {
  final int id;
  // Agregá los campos que devuelve el API

  const SplashDto({
    required this.id,
  });

  /// Construye el DTO desde el JSON que devuelve el backend.
  factory SplashDto.fromJson(Map<String, dynamic> json) {
    return SplashDto(
      id: json['id'] as int,
      // campo: json['campo'] as Tipo,
    );
  }

  /// Convierte el DTO a la entidad del dominio.
  SplashEntity toEntity() {
    return SplashEntity(
      id: id,
    );
  }

  /// Convierte la entidad a JSON para enviar al backend (si aplica).
  static Map<String, dynamic> toJson(SplashEntity entity) {
    return {
      'id': entity.id,
    };
  }
}
