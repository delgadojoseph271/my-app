#!/usr/bin/env bash
# =============================================================================
# create_feature.sh — Generador de features Flutter (Clean Architecture)
# =============================================================================
# Uso:
#   bash create_feature.sh <nombre_feature>
#   bash create_feature.sh auth
#   bash create_feature.sh profile
#   bash create_feature.sh notifications
#
# Genera en: mobile/lib/features/<nombre>/
# =============================================================================

set -e

# ── Validación ────────────────────────────────────────────────────────────────
if [ -z "$1" ]; then
  echo ""
  echo "  ✗ Falta el nombre de la feature"
  echo "  Uso: bash create_feature.sh <nombre>"
  echo "  Ej:  bash create_feature.sh auth"
  echo ""
  exit 1
fi

FEATURE_NAME="$1"
FEATURE_DIR="mobile/lib/features/${FEATURE_NAME}"

# PascalCase: auth → Auth, user_profile → UserProfile
CLASS_NAME=$(echo "$FEATURE_NAME" | sed -r 's/(^|_)([a-z])/\U\2/g')

if [ -d "$FEATURE_DIR" ]; then
  echo ""
  echo "  ✗ La feature '${FEATURE_NAME}' ya existe en ${FEATURE_DIR}"
  echo ""
  exit 1
fi

echo ""
echo "  Creando feature: ${FEATURE_NAME}"
echo "  Clase base:      ${CLASS_NAME}"
echo "  Directorio:      ${FEATURE_DIR}"
echo ""

# ── Crear directorios ─────────────────────────────────────────────────────────
mkdir -p "${FEATURE_DIR}/data"
mkdir -p "${FEATURE_DIR}/domain"
mkdir -p "${FEATURE_DIR}/presentation/widgets"

# =============================================================================
# DOMAIN
# =============================================================================

# ── domain/entity ─────────────────────────────────────────────────────────────
cat > "${FEATURE_DIR}/domain/${FEATURE_NAME}_entity.dart" << EOF
/// Entidad del dominio ${CLASS_NAME}.
/// Clase Dart pura — sin imports de Flutter, Dio ni ninguna librería externa.
/// Solo lógica de negocio.
class ${CLASS_NAME}Entity {
  final int id;
  // Agregá los campos propios de la entidad

  const ${CLASS_NAME}Entity({
    required this.id,
  });

  // Lógica de negocio pura (si aplica)
  // bool get isValid => ...
}
EOF

# ── domain/repository (interfaz abstracta) ────────────────────────────────────
cat > "${FEATURE_DIR}/domain/${FEATURE_NAME}_repository.dart" << EOF
import '${FEATURE_NAME}_entity.dart';

/// Contrato del repository — definido en domain, implementado en data.
/// El dominio solo conoce esta interfaz, nunca la implementación concreta.
abstract class ${CLASS_NAME}Repository {
  Future<${CLASS_NAME}Entity> getById(int id);
  Future<List<${CLASS_NAME}Entity>> getAll();
  Future<${CLASS_NAME}Entity> create(Map<String, dynamic> data);
  Future<${CLASS_NAME}Entity> update(int id, Map<String, dynamic> data);
  Future<void> delete(int id);
}
EOF

# ── domain/usecase ────────────────────────────────────────────────────────────
cat > "${FEATURE_DIR}/domain/${FEATURE_NAME}_usecase.dart" << EOF
import '${FEATURE_NAME}_entity.dart';
import '${FEATURE_NAME}_repository.dart';

/// Caso de uso: obtener un ${CLASS_NAME} por id.
/// Un use case = una acción del usuario = una responsabilidad.
class Get${CLASS_NAME}UseCase {
  final ${CLASS_NAME}Repository _repository;
  Get${CLASS_NAME}UseCase(this._repository);

  Future<${CLASS_NAME}Entity> call(int id) {
    return _repository.getById(id);
  }
}

/// Caso de uso: obtener todos los ${CLASS_NAME}s.
class GetAll${CLASS_NAME}sUseCase {
  final ${CLASS_NAME}Repository _repository;
  GetAll${CLASS_NAME}sUseCase(this._repository);

  Future<List<${CLASS_NAME}Entity>> call() {
    return _repository.getAll();
  }
}

// Agregá más use cases según las acciones de la feature:
// class Create${CLASS_NAME}UseCase { ... }
// class Delete${CLASS_NAME}UseCase { ... }
EOF

# =============================================================================
# DATA
# =============================================================================

# ── data/dto ──────────────────────────────────────────────────────────────────
cat > "${FEATURE_DIR}/data/${FEATURE_NAME}_dto.dart" << EOF
import '../domain/${FEATURE_NAME}_entity.dart';

/// DTO (Data Transfer Object): convierte JSON del API → Entity del dominio.
/// Solo existe en la capa data — el dominio no sabe que existe.
class ${CLASS_NAME}Dto {
  final int id;
  // Agregá los campos que devuelve el API

  const ${CLASS_NAME}Dto({
    required this.id,
  });

  /// Construye el DTO desde el JSON que devuelve el backend.
  factory ${CLASS_NAME}Dto.fromJson(Map<String, dynamic> json) {
    return ${CLASS_NAME}Dto(
      id: json['id'] as int,
      // campo: json['campo'] as Tipo,
    );
  }

  /// Convierte el DTO a la entidad del dominio.
  ${CLASS_NAME}Entity toEntity() {
    return ${CLASS_NAME}Entity(
      id: id,
    );
  }

  /// Convierte la entidad a JSON para enviar al backend (si aplica).
  static Map<String, dynamic> toJson(${CLASS_NAME}Entity entity) {
    return {
      'id': entity.id,
    };
  }
}
EOF

# ── data/remote datasource ────────────────────────────────────────────────────
cat > "${FEATURE_DIR}/data/${FEATURE_NAME}_remote_ds.dart" << EOF
import 'package:dio/dio.dart';
import '${FEATURE_NAME}_dto.dart';

/// Datasource remoto: hace las llamadas HTTP al backend.
/// Solo sabe de JSON y Dio — no sabe nada de entidades ni lógica de negocio.
class ${CLASS_NAME}RemoteDataSource {
  final Dio _dio;
  ${CLASS_NAME}RemoteDataSource(this._dio);

  Future<${CLASS_NAME}Dto> getById(int id) async {
    final response = await _dio.get('/api/v1/${FEATURE_NAME}s/\$id');
    return ${CLASS_NAME}Dto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<${CLASS_NAME}Dto>> getAll() async {
    final response = await _dio.get('/api/v1/${FEATURE_NAME}s/');
    final list = response.data as List<dynamic>;
    return list
        .map((item) => ${CLASS_NAME}Dto.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<${CLASS_NAME}Dto> create(Map<String, dynamic> data) async {
    final response = await _dio.post('/api/v1/${FEATURE_NAME}s/', data: data);
    return ${CLASS_NAME}Dto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<${CLASS_NAME}Dto> update(int id, Map<String, dynamic> data) async {
    final response = await _dio.patch('/api/v1/${FEATURE_NAME}s/\$id', data: data);
    return ${CLASS_NAME}Dto.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(int id) async {
    await _dio.delete('/api/v1/${FEATURE_NAME}s/\$id');
  }
}
EOF

# ── data/repository (implementación) ─────────────────────────────────────────
cat > "${FEATURE_DIR}/data/${FEATURE_NAME}_repository_impl.dart" << EOF
import '../domain/${FEATURE_NAME}_entity.dart';
import '../domain/${FEATURE_NAME}_repository.dart';
import '${FEATURE_NAME}_dto.dart';
import '${FEATURE_NAME}_remote_ds.dart';

/// Implementación concreta del repository.
/// Implementa la interfaz del dominio usando el datasource remoto.
/// Si mañana agregás cache local, lo hacés aquí sin tocar el dominio.
class ${CLASS_NAME}RepositoryImpl implements ${CLASS_NAME}Repository {
  final ${CLASS_NAME}RemoteDataSource _remote;
  // final ${CLASS_NAME}LocalDataSource _local; // para cache

  ${CLASS_NAME}RepositoryImpl(this._remote);

  @override
  Future<${CLASS_NAME}Entity> getById(int id) async {
    final dto = await _remote.getById(id);
    return dto.toEntity();
  }

  @override
  Future<List<${CLASS_NAME}Entity>> getAll() async {
    final dtos = await _remote.getAll();
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<${CLASS_NAME}Entity> create(Map<String, dynamic> data) async {
    final dto = await _remote.create(data);
    return dto.toEntity();
  }

  @override
  Future<${CLASS_NAME}Entity> update(int id, Map<String, dynamic> data) async {
    final dto = await _remote.update(id, data);
    return dto.toEntity();
  }

  @override
  Future<void> delete(int id) async {
    await _remote.delete(id);
  }
}
EOF

# =============================================================================
# PRESENTATION
# =============================================================================

# ── presentation/bloc ─────────────────────────────────────────────────────────
cat > "${FEATURE_DIR}/presentation/${FEATURE_NAME}_bloc.dart" << EOF
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/${FEATURE_NAME}_entity.dart';
import '../domain/${FEATURE_NAME}_usecase.dart';

// ── Eventos ───────────────────────────────────────────────────────────────────
abstract class ${CLASS_NAME}Event {}

class Load${CLASS_NAME}sRequested extends ${CLASS_NAME}Event {}

class Load${CLASS_NAME}Requested extends ${CLASS_NAME}Event {
  final int id;
  Load${CLASS_NAME}Requested(this.id);
}

// Agregá más eventos según las acciones de la feature:
// class Create${CLASS_NAME}Requested extends ${CLASS_NAME}Event { ... }
// class Delete${CLASS_NAME}Requested extends ${CLASS_NAME}Event { ... }

// ── Estados ───────────────────────────────────────────────────────────────────
abstract class ${CLASS_NAME}State {}

class ${CLASS_NAME}Initial extends ${CLASS_NAME}State {}

class ${CLASS_NAME}Loading extends ${CLASS_NAME}State {}

class ${CLASS_NAME}sLoaded extends ${CLASS_NAME}State {
  final List<${CLASS_NAME}Entity> items;
  ${CLASS_NAME}sLoaded(this.items);
}

class ${CLASS_NAME}Loaded extends ${CLASS_NAME}State {
  final ${CLASS_NAME}Entity item;
  ${CLASS_NAME}Loaded(this.item);
}

class ${CLASS_NAME}Error extends ${CLASS_NAME}State {
  final String message;
  ${CLASS_NAME}Error(this.message);
}

// ── BLoC ──────────────────────────────────────────────────────────────────────
class ${CLASS_NAME}Bloc extends Bloc<${CLASS_NAME}Event, ${CLASS_NAME}State> {
  final GetAll${CLASS_NAME}sUseCase _getAll;
  final Get${CLASS_NAME}UseCase _getById;

  ${CLASS_NAME}Bloc({
    required GetAll${CLASS_NAME}sUseCase getAll,
    required Get${CLASS_NAME}UseCase getById,
  })  : _getAll = getAll,
        _getById = getById,
        super(${CLASS_NAME}Initial()) {
    on<Load${CLASS_NAME}sRequested>(_onLoadAll);
    on<Load${CLASS_NAME}Requested>(_onLoadOne);
  }

  Future<void> _onLoadAll(
    Load${CLASS_NAME}sRequested event,
    Emitter<${CLASS_NAME}State> emit,
  ) async {
    emit(${CLASS_NAME}Loading());
    try {
      final items = await _getAll();
      emit(${CLASS_NAME}sLoaded(items));
    } catch (e) {
      emit(${CLASS_NAME}Error(e.toString()));
    }
  }

  Future<void> _onLoadOne(
    Load${CLASS_NAME}Requested event,
    Emitter<${CLASS_NAME}State> emit,
  ) async {
    emit(${CLASS_NAME}Loading());
    try {
      final item = await _getById(event.id);
      emit(${CLASS_NAME}Loaded(item));
    } catch (e) {
      emit(${CLASS_NAME}Error(e.toString()));
    }
  }
}
EOF

# ── presentation/page ─────────────────────────────────────────────────────────
cat > "${FEATURE_DIR}/presentation/${FEATURE_NAME}_page.dart" << EOF
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '${FEATURE_NAME}_bloc.dart';

class ${CLASS_NAME}Page extends StatelessWidget {
  const ${CLASS_NAME}Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => context.read<${CLASS_NAME}Bloc>()
        ..add(Load${CLASS_NAME}sRequested()),
      child: const _${CLASS_NAME}View(),
    );
  }
}

class _${CLASS_NAME}View extends StatelessWidget {
  const _${CLASS_NAME}View();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('${CLASS_NAME}')),
      body: BlocBuilder<${CLASS_NAME}Bloc, ${CLASS_NAME}State>(
        builder: (context, state) {
          if (state is ${CLASS_NAME}Loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ${CLASS_NAME}Error) {
            return Center(child: Text('Error: \${state.message}'));
          }
          if (state is ${CLASS_NAME}sLoaded) {
            return ListView.builder(
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return ListTile(title: Text('ID: \${item.id}'));
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
EOF

# ── presentation/widgets placeholder ─────────────────────────────────────────
cat > "${FEATURE_DIR}/presentation/widgets/${FEATURE_NAME}_widgets.dart" << EOF
// Widgets específicos de la feature ${CLASS_NAME}.
// Separalos en archivos individuales cuando crezcan.
//
// Ejemplos:
//   ${FEATURE_NAME}_card.dart
//   ${FEATURE_NAME}_form.dart
//   ${FEATURE_NAME}_empty_state.dart
EOF

# ── injection ─────────────────────────────────────────────────────────────────
cat > "${FEATURE_DIR}/${FEATURE_NAME}_injection.dart" << EOF
import 'package:get_it/get_it.dart';
import 'data/${FEATURE_NAME}_remote_ds.dart';
import 'data/${FEATURE_NAME}_repository_impl.dart';
import 'domain/${FEATURE_NAME}_repository.dart';
import 'domain/${FEATURE_NAME}_usecase.dart';
import 'presentation/${FEATURE_NAME}_bloc.dart';

/// Registra todas las dependencias de la feature ${CLASS_NAME} en GetIt.
/// Llamar desde core/di/injection.dart en setupDependencies().
void register${CLASS_NAME}Dependencies(GetIt sl) {
  // ── Data ──────────────────────────────────────────────────────────────────
  sl.registerLazySingleton(
    () => ${CLASS_NAME}RemoteDataSource(sl()),  // sl() resuelve Dio
  );

  // ── Repository ────────────────────────────────────────────────────────────
  sl.registerLazySingleton<${CLASS_NAME}Repository>(
    () => ${CLASS_NAME}RepositoryImpl(sl()),
  );

  // ── Use cases ─────────────────────────────────────────────────────────────
  sl.registerFactory(() => Get${CLASS_NAME}UseCase(sl()));
  sl.registerFactory(() => GetAll${CLASS_NAME}sUseCase(sl()));

  // ── BLoC ──────────────────────────────────────────────────────────────────
  sl.registerFactory(
    () => ${CLASS_NAME}Bloc(
      getAll: sl(),
      getById: sl(),
    ),
  );
}
EOF

# =============================================================================
# INSTRUCCIONES
# =============================================================================
echo "  ✓ Archivos creados:"
echo ""
find "${FEATURE_DIR}" -type f | sort | sed 's/^/    /'
echo ""
echo "  ─────────────────────────────────────────────────────────"
echo "  Pasos siguientes:"
echo ""
echo "  1. Registrar dependencias en mobile/lib/core/di/injection.dart:"
echo ""
echo "       import 'package:features/${FEATURE_NAME}/${FEATURE_NAME}_injection.dart';"
echo "       register${CLASS_NAME}Dependencies(sl);"
echo ""
echo "  2. Agregar la ruta en mobile/lib/core/router/app_router.dart:"
echo ""
echo "       GoRoute("
echo "         path: '/${FEATURE_NAME}s',"
echo "         builder: (context, state) => const ${CLASS_NAME}Page(),"
echo "       ),"
echo ""
echo "  3. Completar los campos en:"
echo "       ${FEATURE_DIR}/domain/${FEATURE_NAME}_entity.dart"
echo "       ${FEATURE_DIR}/data/${FEATURE_NAME}_dto.dart"
echo ""
echo "  4. Ajustar los endpoints en:"
echo "       ${FEATURE_DIR}/data/${FEATURE_NAME}_remote_ds.dart"
echo "       (actualmente apunta a /api/v1/${FEATURE_NAME}s/)"
echo ""
echo "  ─────────────────────────────────────────────────────────"
echo ""
