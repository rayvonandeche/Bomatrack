part of 'complete_profile_cubit.dart';

final class CompleteProfileState extends Equatable {
  final FirstName firstName;
  final LastName lastName;
  final Username username;
  final Phone phoneNumber;
  final Organization organization;
  final bool isOrganizationValidated;
  final FormzSubmissionStatus status;
  final bool isValid;
  final String? error;

  const CompleteProfileState({
    this.firstName = const FirstName.pure(),
    this.lastName = const LastName.pure(),
    this.phoneNumber = const Phone.pure(),
    this.username = const Username.pure(),
    this.organization = const Organization.pure(),
    this.isOrganizationValidated = false,
    this.isValid = false,
    this.status = FormzSubmissionStatus.initial,
    this.error,
  });

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        phoneNumber,
        username,
        isValid,
        error,
        status,
        organization,
        isOrganizationValidated
      ];

  CompleteProfileState copyWith({
    FirstName? firstName,
    LastName? lastName,
    Phone? phoneNumber,
    Username? username,
    Organization? organization,
    bool? isOrganizationValidated,
    bool? isValid,
    FormzSubmissionStatus? status,
    String? error,
  }) {
    return CompleteProfileState(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      username: username ?? this.username,
      organization: organization ?? this.organization,
      isValid: isValid ?? this.isValid,
      error: error ?? this.error,
      status: status ?? this.status,
      isOrganizationValidated: isOrganizationValidated?? this.isOrganizationValidated,
    );
  }
}
