import 'package:bloc/bloc.dart';
import 'package:bomatrack/services/services.dart';
import 'package:equatable/equatable.dart';

part 'verify_page_state.dart';

class VerifyPageCubit extends Cubit<VerifyPageState> {
  final AuthRepository authRepository;
  VerifyPageCubit({required this.authRepository})
      : _authRepository = authRepository,
        super(const VerifyPageState());

  final AuthRepository _authRepository;

  Future<void> resend(String email) async {
    try {
      await _authRepository.resendOTP(email: email);
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isVerified: false));
    }
  }

  Future<void> verifyEmail(String email, String otp) async {
    try {
      await _authRepository.verifyOTP(email: email, otp: otp);
      emit(state.copyWith(isVerified: true));
    } catch (e) {
      emit(state.copyWith(error: e.toString(), isVerified: false));
    }
  }
}
