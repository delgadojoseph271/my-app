import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/home_entity.dart';
import '../domain/home_usecase.dart';

// ── Eventos ───────────────────────────────────────────────────────────────────
abstract class HomeEvent {}

class LoadHomesRequested extends HomeEvent {}

class LoadHomeRequested extends HomeEvent {
  final int id;
  LoadHomeRequested(this.id);
}

// Agregá más eventos según las acciones de la feature:
// class CreateHomeRequested extends HomeEvent { ... }
// class DeleteHomeRequested extends HomeEvent { ... }

// ── Estados ───────────────────────────────────────────────────────────────────
abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomesLoaded extends HomeState {
  final List<HomeEntity> items;
  HomesLoaded(this.items);
}

class HomeLoaded extends HomeState {
  final HomeEntity item;
  HomeLoaded(this.item);
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}

// ── BLoC ──────────────────────────────────────────────────────────────────────
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetAllHomesUseCase _getAll;
  final GetHomeUseCase _getById;

  HomeBloc({
    required GetAllHomesUseCase getAll,
    required GetHomeUseCase getById,
  })  : _getAll = getAll,
        _getById = getById,
        super(HomeInitial()) {
    on<LoadHomesRequested>(_onLoadAll);
    on<LoadHomeRequested>(_onLoadOne);
  }

  Future<void> _onLoadAll(
    LoadHomesRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());
    try {
      final items = await _getAll();
      emit(HomesLoaded(items));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  Future<void> _onLoadOne(
    LoadHomeRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());
    try {
      final item = await _getById(event.id);
      emit(HomeLoaded(item));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }
}
