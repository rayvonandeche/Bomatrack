import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bomatrack/features/auth/presentation/form_inputs/form_inputs.dart';
import 'package:bomatrack/services/services.dart';
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

part 'complete_profile_state.dart';

class CompleteProfileCubit extends Cubit<CompleteProfileState> {
  CompleteProfileCubit(this._authRepository)
      : super(const CompleteProfileState());

  final AuthRepository _authRepository;

  void firstNameChanged(String value) {
    final firstName = FirstName.dirty(value);
    emit(state.copyWith(
      firstName: firstName,
      isValid: _authRepository.isGoogleSignIn
          ? true
          : Formz.validate([
              firstName,
              state.lastName,
              state.phoneNumber,
              state.username,
              state.organization,
            ]),
    ));
  }

  void lastNameChanged(String value) {
    final lastName = LastName.dirty(value);
    emit(state.copyWith(
      lastName: lastName,
      isValid: _authRepository.isGoogleSignIn
          ? true
          : Formz.validate([
              state.firstName,
              lastName,
              state.phoneNumber,
              state.username,
              state.organization,
            ]),
    ));
  }

  void phoneNumberChanged(String value) {
    final phoneNumber = Phone.dirty(value);
    emit(state.copyWith(
      phoneNumber: phoneNumber,
      isValid: _authRepository.isGoogleSignIn
          ? Formz.validate([
              phoneNumber,
              state.organization,
              state.username,
            ])
          : Formz.validate([
              state.firstName,
              state.lastName,
              phoneNumber,
              state.organization,
              state.username,
            ]),
    ));
  }

  void usernameChanged(String value) {
    final userName = Username.dirty(value);
    emit(state.copyWith(
      username: userName,
      isValid: _authRepository.isGoogleSignIn
          ? Formz.validate([
              state.phoneNumber,
              userName,
              state.organization,
            ])
          : Formz.validate([
              state.firstName,
              state.lastName,
              state.phoneNumber,
              userName,
              state.organization,
            ]),
    ));
  }

  void orgChanged(String value) {
    final org = Organization.dirty(value);
    emit(state.copyWith(
      organization: org,
      isValid: _authRepository.isGoogleSignIn
          ? Formz.validate([
              state.phoneNumber,
              state.username,
              org,
            ])
          : Formz.validate([
              state.firstName,
              state.lastName,
              state.phoneNumber,
              state.username,
              org,
            ]),
    ));
  }

  void organizationValidationChanged(bool isValid) {
    emit(state.copyWith(isValid: isValid, isOrganizationValidated: isValid));
  }

  Future<void> formSubmitted() async {
    if (!state.isValid) return;
    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));
    try {
      await _authRepository.completeProfile(
          firstName: state.firstName.value,
          lastName: state.lastName.value,
          username: state.username.value,
          phoneNumber: state.phoneNumber.value,
          organization: state.organization.value);
      emit(state.copyWith(status: FormzSubmissionStatus.success));
    } catch (e) {
      emit(state.copyWith(
        error: e.toString(),
        status: FormzSubmissionStatus.failure,
      ));
    }
  }
}
