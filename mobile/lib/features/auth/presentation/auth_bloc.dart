import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/auth_entity.dart';
import '../domain/auth_usecase.dart';

// ── Eventos ───────────────────────────────────────────────────────────────────
abstract class AuthEvent {}

class LoadAuthsRequested extends AuthEvent {}

class LoadAuthRequested extends AuthEvent {
  final int id;
  LoadAuthRequested(this.id);
}

// Agregá más eventos según las acciones de la feature:
// class CreateAuthRequested extends AuthEvent { ... }
// class DeleteAuthRequested extends AuthEvent { ... }

// ── Estados ───────────────────────────────────────────────────────────────────
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthsLoaded extends AuthState {
  final List<AuthEntity> items;
  AuthsLoaded(this.items);
}

class AuthLoaded extends AuthState {
  final AuthEntity item;
  AuthLoaded(this.item);
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

// ── BLoC ──────────────────────────────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final GetAllAuthsUseCase _getAll;
  final GetAuthUseCase _getById;

  AuthBloc({
    required GetAllAuthsUseCase getAll,
    required GetAuthUseCase getById,
  })  : _getAll = getAll,
        _getById = getById,
        super(AuthInitial()) {
    on<LoadAuthsRequested>(_onLoadAll);
    on<LoadAuthRequested>(_onLoadOne);
  }

  Future<void> _onLoadAll(
    LoadAuthsRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final items = await _getAll();
      emit(AuthsLoaded(items));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLoadOne(
    LoadAuthRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final item = await _getById(event.id);
      emit(AuthLoaded(item));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
