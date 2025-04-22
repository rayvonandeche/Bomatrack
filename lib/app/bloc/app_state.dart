part of 'app_bloc.dart';

enum AppStatus { authenticated, unauthenticated, noProfile, notVerified }

final class AppState extends Equatable {
  final AppStatus status;
  final Session userSession;

  const AppState._({
    required this.status,
    required this.userSession,
  });

  AppState({Session? userSession})
      : this._(
            status: userSession != null ? _determineStatus(userSession) : AppStatus.unauthenticated,
            userSession: userSession ??
                Session(
                    accessToken: '',
                    tokenType: '',
                    user: const User(
                        id: '',
                        appMetadata: {},
                        userMetadata: {},
                        aud: '',
                        createdAt: '')));

  static AppStatus _determineStatus(Session? session) {
    final userMetadata = session?.user.userMetadata;
    bool verified =  session?.user.emailConfirmedAt != null;
    bool isProfileComplete = userMetadata != null &&
        userMetadata['first_name'] != null &&
        userMetadata['last_name'] != null &&
        userMetadata['phone_number'] != null &&
        userMetadata['username'] != null &&
        userMetadata['organization'] != null;

    if (session != null && !verified) {
      return AppStatus.notVerified;
    } else if (session != null && !isProfileComplete && verified) {
      return AppStatus.noProfile;
    } else if (session != null && isProfileComplete && verified) {
      return AppStatus.authenticated;
    } else {
      return AppStatus.unauthenticated;
    }
  }

  @override
  List<Object> get props => [status, userSession];
}
