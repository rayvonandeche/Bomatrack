import 'package:bomatrack/services/services.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'app_state.dart';
part 'app_event.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(AppState(userSession: authRepository.currentSession)) {
    on<AppUserSubscriptionRequested>(_onUserChanged);
    on<AppSignOutPressed>(_onLogoutRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onUserChanged(
    AppUserSubscriptionRequested event,
    Emitter<AppState> emit,
  ) {
    return emit.onEach(_authRepository.userSession,
        onData: (userSession) => emit(
              AppState(userSession: userSession),
            ),
        onError: addError);
  }

  void _onLogoutRequested(AppSignOutPressed event, Emitter<AppState> emit) {
    _authRepository.signOut();
  }
}
