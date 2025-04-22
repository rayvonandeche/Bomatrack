part of 'app_bloc.dart';

sealed class AppEvent {
  const AppEvent();
}

class AppUserSubscriptionRequested extends AppEvent {
  const AppUserSubscriptionRequested();
}

class AppSignOutPressed extends AppEvent {
  const AppSignOutPressed();
}