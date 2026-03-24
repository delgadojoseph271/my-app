import '../domain/home_entity.dart';

/// DTO (Data Transfer Object): convierte JSON del API → Entity del dominio.
/// Solo existe en la capa data — el dominio no sabe que existe.
class HomeDto {
  final int id;
  // Agregá los campos que devuelve el API

  const HomeDto({
    required this.id,
  });

  /// Construye el DTO desde el JSON que devuelve el backend.
  factory HomeDto.fromJson(Map<String, dynamic> json) {
    return HomeDto(
      id: json['id'] as int,
      // campo: json['campo'] as Tipo,
    );
  }

  /// Convierte el DTO a la entidad del dominio.
  HomeEntity toEntity() {
    return HomeEntity(
      id: id,
    );
  }

  /// Convierte la entidad a JSON para enviar al backend (si aplica).
  static Map<String, dynamic> toJson(HomeEntity entity) {
    return {
      'id': entity.id,
    };
  }
}
