import '../domain/auth_entity.dart';

/// DTO (Data Transfer Object): convierte JSON del API → Entity del dominio.
/// Solo existe en la capa data — el dominio no sabe que existe.
class AuthDto {
  final int id;
  // Agregá los campos que devuelve el API

  const AuthDto({
    required this.id,
  });

  /// Construye el DTO desde el JSON que devuelve el backend.
  factory AuthDto.fromJson(Map<String, dynamic> json) {
    return AuthDto(
      id: json['id'] as int,
      // campo: json['campo'] as Tipo,
    );
  }

  /// Convierte el DTO a la entidad del dominio.
  AuthEntity toEntity() {
    return AuthEntity(
      id: id,
    );
  }

  /// Convierte la entidad a JSON para enviar al backend (si aplica).
  static Map<String, dynamic> toJson(AuthEntity entity) {
    return {
      'id': entity.id,
    };
  }
}
