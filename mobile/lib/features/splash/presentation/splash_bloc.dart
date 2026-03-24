import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/splash_entity.dart';
import '../domain/splash_usecase.dart';

// ── Eventos ───────────────────────────────────────────────────────────────────
abstract class SplashEvent {}

class LoadSplashsRequested extends SplashEvent {}

class LoadSplashRequested extends SplashEvent {
  final int id;
  LoadSplashRequested(this.id);
}

// Agregá más eventos según las acciones de la feature:
// class CreateSplashRequested extends SplashEvent { ... }
// class DeleteSplashRequested extends SplashEvent { ... }

// ── Estados ───────────────────────────────────────────────────────────────────
abstract class SplashState {}

class SplashInitial extends SplashState {}

class SplashLoading extends SplashState {}

class SplashsLoaded extends SplashState {
  final List<SplashEntity> items;
  SplashsLoaded(this.items);
}

class SplashLoaded extends SplashState {
  final SplashEntity item;
  SplashLoaded(this.item);
}

class SplashError extends SplashState {
  final String message;
  SplashError(this.message);
}

// ── BLoC ──────────────────────────────────────────────────────────────────────
class SplashBloc extends Bloc<SplashEvent, SplashState> {
  final GetAllSplashsUseCase _getAll;
  final GetSplashUseCase _getById;

  SplashBloc({
    required GetAllSplashsUseCase getAll,
    required GetSplashUseCase getById,
  })  : _getAll = getAll,
        _getById = getById,
        super(SplashInitial()) {
    on<LoadSplashsRequested>(_onLoadAll);
    on<LoadSplashRequested>(_onLoadOne);
  }

  Future<void> _onLoadAll(
    LoadSplashsRequested event,
    Emitter<SplashState> emit,
  ) async {
    emit(SplashLoading());
    try {
      final items = await _getAll();
      emit(SplashsLoaded(items));
    } catch (e) {
      emit(SplashError(e.toString()));
    }
  }

  Future<void> _onLoadOne(
    LoadSplashRequested event,
    Emitter<SplashState> emit,
  ) async {
    emit(SplashLoading());
    try {
      final item = await _getById(event.id);
      emit(SplashLoaded(item));
    } catch (e) {
      emit(SplashError(e.toString()));
    }
  }
}
