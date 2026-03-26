# CONTEXT.md — Mobile (Flutter)

> Contexto técnico del mobile. Mantenerlo actualizado al agregar features, cambiar patrones o tomar decisiones de arquitectura.

---

## Tabla de contenidos

1. [Stack y versiones](#1-stack-y-versiones)
2. [Estructura de carpetas](#2-estructura-de-carpetas)
3. [Capa core/](#3-capa-core)
4. [Capa shared/](#4-capa-shared)
5. [Patrón de feature — Clean Architecture](#5-patrón-de-feature--clean-architecture)
6. [BLoC en detalle](#6-bloc-en-detalle)
7. [Inyección de dependencias (GetIt)](#7-inyección-de-dependencias-getit)
8. [Navegación (GoRouter)](#8-navegación-gorouter)
9. [HTTP y autenticación](#9-http-y-autenticación)
10. [Manejo de errores](#10-manejo-de-errores)
11. [Features existentes](#11-features-existentes)
12. [Generación de código](#12-generación-de-código)
13. [Testing](#13-testing)
14. [Convenciones de código](#14-convenciones-de-código)
15. [Comandos](#15-comandos)

---

## 1. Stack y versiones

| Capa | Tecnología | Versión |
|------|-----------|---------|
| Framework | Flutter | 3.x stable |
| Lenguaje | Dart | 3.x |
| Estado | flutter_bloc | ^8.1.4 |
| Comparación de estados | equatable | ^2.0.5 |
| Inyección de dependencias | get_it | ^7.6.7 |
| Navegación | go_router | ^13.0.0 |
| HTTP | dio | ^5.4.0 |
| Storage cifrado | flutter_secure_storage | ^9.0.0 |
| Preferencias simples | shared_preferences | ^2.2.2 |
| Clases inmutables | freezed_annotation | ^2.4.1 |
| Serialización JSON | json_annotation | ^4.8.1 |
| Testing de BLoC | bloc_test | ^9.1.5 |
| Mocking | mocktail | ^1.0.1 |
| Code generation | build_runner (dev) | ^2.4.8 |

### pubspec.yaml completo

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_bloc: ^8.1.4
  equatable: ^2.0.5
  get_it: ^7.6.7
  go_router: ^13.0.0
  dio: ^5.4.0
  flutter_secure_storage: ^9.0.0
  shared_preferences: ^2.2.2
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  bloc_test: ^9.1.5
  mocktail: ^1.0.1
  build_runner: ^2.4.8
  freezed: ^2.4.7
  json_serializable: ^6.7.1
  flutter_lints: ^3.0.0
```

---

## 2. Estructura de carpetas

```
mobile/lib/
│
├── core/                           ← infraestructura transversal
│   ├── di/
│   │   └── injection.dart          ← GetIt: registro global de dependencias
│   ├── network/
│   │   ├── dio_client.dart         ← Dio configurado con interceptores
│   │   └── auth_interceptor.dart   ← JWT automático + manejo de 401
│   ├── router/
│   │   └── app_router.dart         ← GoRouter con guards de autenticación
│   ├── storage/
│   │   └── secure_storage.dart     ← wrapper de FlutterSecureStorage
│   ├── theme/
│   │   └── app_theme.dart          ← colores, tipografía, ThemeData
│   └── errors/
│       └── failures.dart           ← Failure y subtipos
│
├── features/                       ← una carpeta por dominio de negocio
│   ├── auth/
│   │   ├── domain/
│   │   │   ├── auth_entity.dart    ← Dart puro, sin imports externos
│   │   │   ├── auth_repository.dart ← interfaz abstracta
│   │   │   └── auth_usecase.dart   ← LoginUseCase, RegisterUseCase, etc.
│   │   ├── data/
│   │   │   ├── auth_dto.dart       ← fromJson() + toEntity()
│   │   │   ├── auth_remote_ds.dart ← llamadas HTTP con Dio
│   │   │   └── auth_repository_impl.dart
│   │   ├── presentation/
│   │   │   ├── auth_bloc.dart      ← Eventos + Estados + BLoC
│   │   │   ├── login_page.dart
│   │   │   ├── register_page.dart
│   │   │   └── widgets/
│   │   └── auth_injection.dart     ← registerAuthDependencies(sl)
│   │
│   └── <feature>/                  ← misma estructura
│
├── shared/                         ← widgets y utils reutilizables
│   ├── widgets/
│   │   ├── app_button.dart
│   │   ├── app_text_field.dart
│   │   ├── loading_overlay.dart
│   │   └── error_view.dart
│   └── utils/
│       ├── validators.dart
│       └── extensions.dart
│
├── app.dart                        ← MaterialApp.router + MultiBlocProvider
└── main.dart                       ← solo setupDependencies() + runApp(App())
```

### Reglas de dependencia — resumen

| Carpeta | Puede importar | No puede importar |
|---------|---------------|------------------|
| `features/X/domain/` | Dart puro, `core/errors/` | Flutter, Dio, data/, presentation/ |
| `features/X/data/` | `domain/`, Dio, SecureStorage | `presentation/`, otras features |
| `features/X/presentation/` | `domain/`, Flutter, BLoC, `shared/` | `data/` directamente |
| `core/` | Librerías externas | `features/` |
| `shared/` | Flutter, `core/` | `features/` |

---

## 3. Capa core/

### injection.dart — punto de entrada de dependencias

```dart
final sl = GetIt.instance;

Future<void> setupDependencies() async {
  // Core — disponible para todas las features
  sl.registerLazySingleton<FlutterSecureStorage>(
    () => const FlutterSecureStorage(),
  );
  sl.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(sl()),
  );
  sl.registerLazySingleton<Dio>(
    () => createDioClient(sl()),
  );

  // Features — cada una registra sus propias dependencias
  registerAuthDependencies(sl);
  // registerHomeDependencies(sl);  ← agregar al crear la feature
}
```

### dio_client.dart

```dart
const _kApiUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:8000',  // Android emulator → localhost
  // iOS simulator: usar 'http://localhost:8000'
);

Dio createDioClient(SecureStorageService storage) {
  final dio = Dio(BaseOptions(
    baseUrl: _kApiUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.addAll([
    AuthInterceptor(storage),
    if (kDebugMode) LogInterceptor(requestBody: true, responseBody: true),
  ]);

  return dio;
}
```

### auth_interceptor.dart

```dart
class AuthInterceptor extends Interceptor {
  final SecureStorageService _storage;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      await _storage.deleteToken();
      // el GoRouter redirige al login automáticamente por el guard
    }
    handler.next(err);
  }
}
```

### secure_storage.dart

```dart
class SecureStorageService {
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'access_token';

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);
  Future<String?> getToken()           => _storage.read(key: _tokenKey);
  Future<void> deleteToken()           => _storage.delete(key: _tokenKey);
}
```

### app_router.dart

```dart
final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final isAuth   = authState is AuthAuthenticated;
    final isOnAuth = state.matchedLocation.startsWith('/login') ||
                     state.matchedLocation.startsWith('/register');

    if (!isAuth && !isOnAuth) return '/login';  // no autenticado → login
    if (isAuth  &&  isOnAuth) return '/home';   // autenticado + en login → home
    return null;
  },
  routes: [
    GoRoute(path: '/login',    builder: (_, __) => const LoginPage()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),
    GoRoute(path: '/home',     builder: (_, __) => const HomePage()),
    // agregar rutas nuevas aquí al crear features
  ],
);
```

---

## 4. Capa shared/

### widgets/app_button.dart

Widget de botón reutilizable. Acepta `loading: true` para mostrar spinner automáticamente.

```dart
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  // Cuando loading=true: muestra CircularProgressIndicator y deshabilita onPressed
}

// Uso:
AppButton(
  label: 'Ingresar',
  onPressed: _submit,
  loading: state is AuthLoading,
)
```

### utils/validators.dart

Funciones puras de validación para usar en `TextFormField`:

```dart
String? validateEmail(String? value)     // null = válido
String? validatePassword(String? value)  // null = válido
String? validateNotEmpty(String? value)
```

---

## 5. Patrón de feature — Clean Architecture

Cada feature tiene tres capas. Las dependencias siempre apuntan hacia adentro.

```
presentation/  →  domain/  ←  data/
```

### domain/ — la lógica de negocio

**Dart puro. Cero imports externos.**

```dart
// auth_entity.dart
class UserEntity {
  final int id;
  final String email;
  final String name;
  final String accessToken;
  final String refreshToken;
  const UserEntity({required this.id, ...});
}

// auth_repository.dart
abstract class AuthRepository {
  Future<UserEntity> login(String email, String password);
  Future<UserEntity> register(String email, String password, String name);
  Future<void> logout();
}

// auth_usecase.dart
class LoginUseCase {
  final AuthRepository _repo;
  LoginUseCase(this._repo);
  Future<UserEntity> call(String email, String password) => _repo.login(email, password);
}
```

### data/ — la implementación HTTP

```dart
// auth_dto.dart
class AuthResponseDto {
  // campos que devuelve el backend
  factory AuthResponseDto.fromJson(Map<String, dynamic> json) { ... }
  UserEntity toEntity() { ... }  // conversión DTO → Entity
}

// auth_remote_ds.dart
class AuthRemoteDataSource {
  final Dio _dio;
  Future<AuthResponseDto> login(String email, String password) async {
    final res = await _dio.post('/api/v1/auth/login', data: {...});
    return AuthResponseDto.fromJson(res.data);
  }
}

// auth_repository_impl.dart
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final SecureStorageService _storage;

  @override
  Future<UserEntity> login(String email, String password) async {
    final dto = await _remote.login(email, password);
    final entity = dto.toEntity();
    await _storage.saveToken(entity.accessToken);  // guardar JWT
    return entity;
  }
}
```

### presentation/ — la UI

```dart
// login_page.dart
class LoginPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<AuthBloc>(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget { ... }

class __LoginViewState extends State<_LoginView> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();    // siempre liberar controllers
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) context.go('/home');
        if (state is AuthError) showSnackBar(state.message);
      },
      builder: (context, state) {
        // renderizar según el estado
      },
    );
  }
}
```

---

## 6. BLoC en detalle

### Los tres componentes en un archivo

```dart
// ═══════════════════════════════
// EVENTOS — lo que el usuario hace
// ═══════════════════════════════
abstract class AuthEvent extends Equatable {
  @override List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email, password;
  const LoginRequested(this.email, this.password);
  @override List<Object?> get props => [email, password];
}
class LogoutRequested  extends AuthEvent {}
class RegisterRequested extends AuthEvent { ... }

// ═══════════════════════════════
// ESTADOS — lo que la UI muestra
// ═══════════════════════════════
abstract class AuthState extends Equatable {
  @override List<Object?> get props => [];
}

class AuthInitial         extends AuthState {}
class AuthLoading         extends AuthState {}
class AuthUnauthenticated extends AuthState {}
class AuthAuthenticated   extends AuthState {
  final UserEntity user;
  const AuthAuthenticated(this.user);
  @override List<Object?> get props => [user.id];
}
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override List<Object?> get props => [message];
}

// ═══════════════════════════════
// BLOC — conecta eventos con estados
// ═══════════════════════════════
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase    _login;
  final RegisterUseCase _register;
  final LogoutUseCase   _logout;

  AuthBloc({required ...}) : ... , super(AuthInitial()) {
    on<LoginRequested>   (_onLogin);
    on<RegisterRequested>(_onRegister);
    on<LogoutRequested>  (_onLogout);
  }

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _login(event.email, event.password);
      emit(AuthAuthenticated(user));
    } on DioException catch (e) {
      emit(AuthError(_mapDioError(e)));
    }
  }
}
```

### Cuándo usar cada widget BLoC

| Widget | Para qué | Cuándo |
|--------|---------|--------|
| `BlocBuilder` | Reconstruir UI | Solo necesitás cambiar lo que se muestra |
| `BlocListener` | Efectos secundarios | Navegar, mostrar snackbar, toast |
| `BlocConsumer` | Ambos | Lo más común — combina los dos anteriores |

### context.read vs context.watch

```dart
// read: obtiene el BLoC para emitir eventos, no reconstruye el widget
context.read<AuthBloc>().add(LoginRequested(email, pass));

// watch: obtiene el BLoC y se suscribe — reconstruye al cambiar el estado
final state = context.watch<AuthBloc>().state;
```

### Equatable — por qué es necesario

Sin Equatable, `AuthError('msg') == AuthError('msg')` devuelve `false` porque Dart compara por referencia. BLoC no emitiría el estado "igual" y la UI no se reconstruiría. Extender `Equatable` y definir `props` resuelve esto.

---

## 7. Inyección de dependencias (GetIt)

### Tipos de registro

| Tipo | Comportamiento | Cuándo |
|------|---------------|--------|
| `registerLazySingleton` | Una sola instancia, creada la primera vez que se pide | Dio, Repository, SecureStorage |
| `registerFactory` | Nueva instancia cada vez que se pide | BLoC, Use Cases |
| `registerSingleton` | Instancia única creada inmediatamente al registrar | Configuración global |

**Regla:** BLoC **siempre** como `registerFactory`. Si se registra como singleton, todas las pantallas comparten el mismo estado → bugs difíciles de rastrear.

### auth_injection.dart

```dart
void registerAuthDependencies(GetIt sl) {
  // Data
  sl.registerLazySingleton(() => AuthRemoteDataSource(sl<Dio>()));
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl(), sl()),  // datasource + storage
  );

  // Use Cases (factory: se crea uno nuevo al construir el BLoC)
  sl.registerFactory(() => LoginUseCase(sl()));
  sl.registerFactory(() => RegisterUseCase(sl()));
  sl.registerFactory(() => LogoutUseCase(sl()));

  // BLoC (factory: cada pantalla recibe su propio BLoC)
  sl.registerFactory(
    () => AuthBloc(login: sl(), register: sl(), logout: sl()),
  );
}
```

### Uso en la UI

```dart
// En un BlocProvider:
BlocProvider(create: (_) => sl<AuthBloc>())

// En injection.dart para features globales:
BlocProvider(create: (_) => sl<AuthBloc>())  // en app.dart
```

---

## 8. Navegación (GoRouter)

### Agregar una ruta nueva

```dart
// core/router/app_router.dart
GoRoute(
  path: '/profile',
  builder: (context, state) => const ProfilePage(),
),
```

### Navegar desde código

```dart
context.go('/home');          // reemplaza la historia completa
context.push('/profile');     // agrega a la historia (puede volver atrás)
context.pop();                // volver atrás
```

### Guard de autenticación

El redirect global en `app_router.dart` se ejecuta antes de cada navegación. Verifica el estado del `AuthBloc` global (registrado en `app.dart` con `MultiBlocProvider`). Si no está autenticado y la ruta no es pública, redirige a `/login`.

---

## 9. HTTP y autenticación

### Flujo de un request autenticado

```
feature datasource
  → Dio.get('/api/v1/resource')
    → AuthInterceptor.onRequest()
      → leer token de SecureStorage
      → agregar header: Authorization: Bearer <token>
    → request sale al backend
  ← response llega
  ← AuthInterceptor.onError() si status 401
    → deleteToken()
    → GoRouter redirige al login
```

### URL base por plataforma

```dart
// Android emulator:  http://10.0.2.2:8000  (apunta al localhost de la máquina)
// iOS simulator:     http://localhost:8000
// Dispositivo físico: la IP local de tu máquina (ej: http://192.168.1.x:8000)
```

Se configura con `--dart-define=API_URL=http://...` al correr en dispositivo físico.

### Manejo de errores HTTP en el BLoC

```dart
} on DioException catch (e) {
  emit(AuthError(_mapDioError(e)));
}

String _mapDioError(DioException e) {
  switch (e.response?.statusCode) {
    case 401: return 'Email o contraseña incorrectos';
    case 409: return 'Ya existe una cuenta con este email';
    case 422: return 'Datos inválidos';
    default:  return 'Error de conexión';
  }
}
```

---

## 10. Manejo de errores

### Failures del dominio (core/errors/failures.dart)

```dart
abstract class Failure { final String message; }
class NetworkFailure      extends Failure { ... }
class UnauthorizedFailure extends Failure { ... }
class NotFoundFailure     extends Failure { ... }
class ServerFailure       extends Failure { ... }
class ValidationFailure   extends Failure { ... }
```

### Conversión DioException → Failure

```dart
Failure dioExceptionToFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
      return const NetworkFailure('Sin conexión');
    case DioExceptionType.badResponse:
      return _statusToFailure(e.response?.statusCode);
    default:
      return const NetworkFailure('Error de conexión');
  }
}
```

---

## 11. Features existentes

| Feature | Estado | Pantallas | BLoC |
|---------|--------|-----------|------|
| `auth` | 🔄 En progreso | LoginPage, RegisterPage | AuthBloc |

> Actualizar esta tabla al agregar features.

---

## 12. Generación de código

### Cuándo correr build_runner

Correr después de modificar cualquier clase anotada con `@freezed` o `@JsonSerializable`:

```bash
dart run build_runner build --delete-conflicting-outputs

# En modo watch (regenera al guardar)
dart run build_runner watch --delete-conflicting-outputs
```

### Archivos generados

- `*.g.dart` — generado por json_serializable
- `*.freezed.dart` — generado por freezed

**Agregar al `.gitignore`:**
```
*.g.dart
*.freezed.dart
```

Estos archivos se regeneran en CI — no hay que commitearlos.

---

## 13. Testing

### Estructura

```
test/
├── features/
│   └── auth/
│       ├── domain/
│       │   └── auth_usecase_test.dart      ← tests unitarios puros
│       ├── data/
│       │   └── auth_repository_test.dart   ← con mock del datasource
│       └── presentation/
│           └── auth_bloc_test.dart         ← con bloc_test
└── shared/
    └── validators_test.dart
```

### Test de BLoC con bloc_test

```dart
blocTest<AuthBloc, AuthState>(
  'emite [AuthLoading, AuthAuthenticated] cuando LoginRequested es exitoso',
  build: () {
    when(() => mockLoginUseCase(any(), any())).thenAnswer((_) async => fakeUser);
    return AuthBloc(login: mockLoginUseCase, ...);
  },
  act: (bloc) => bloc.add(LoginRequested('email@test.com', 'password')),
  expect: () => [
    AuthLoading(),
    AuthAuthenticated(fakeUser),
  ],
);
```

### Mock de repositorio con mocktail

```dart
class MockAuthRepository extends Mock implements AuthRepository {}

setUp(() {
  mockRepo = MockAuthRepository();
  when(() => mockRepo.login(any(), any())).thenAnswer((_) async => fakeUser);
});
```

---

## 14. Convenciones de código

| Elemento | Convención | Ejemplo |
|----------|-----------|---------|
| Variables y funciones | camelCase | `getUserById` |
| Clases | PascalCase | `AuthBloc` |
| Archivos | snake_case | `auth_repository.dart` |
| Entidades | sufijo `Entity` | `UserEntity` |
| DTOs | sufijo `Dto` | `AuthResponseDto` |
| BLoC | un archivo, tres bloques | `auth_bloc.dart` |
| Páginas | sufijo `Page` | `LoginPage` |
| Widgets reutilizables | prefijo `App` (en shared) | `AppButton` |
| dispose() | **siempre** en controllers y subscripciones | — |
| flutter analyze | debe pasar en cero errores antes de PR | — |

### Nunca

- Llamar a Dio directamente desde el BLoC o la UI
- Importar `data/` desde `presentation/`
- Importar `features/` desde `core/` o `shared/`
- Registrar un BLoC como `registerLazySingleton`
- Olvidar `dispose()` en `TextEditingController`

---

## 15. Comandos

```bash
# Desarrollo
make flutter-run      # correr en dispositivo/emulador (elige)
make flutter-web      # correr en Chrome

# Calidad de código
make flutter-analyze  # flutter analyze (debe ser 0 errores)
make flutter-test     # flutter test

# Mantenimiento
make flutter-clean    # flutter clean + pub get
make flutter-deps     # flutter pub get

# Features
make feature name=profile      # crea feature con create_feature.sh
                                # Pasos post-script:
                                # 1. Completar entity y DTO
                                # 2. Ajustar endpoints del datasource
                                # 3. Agregar use cases específicos
                                # 4. Completar el BLoC
                                # 5. Registrar en injection.dart
                                # 6. Agregar ruta en app_router.dart

# Code generation
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
```

---

*Última actualización: ver historial de git de este archivo.*
