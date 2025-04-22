import 'package:bomatrack/app/app.dart';
import 'package:bomatrack/authscreens/auth_page.dart';
import 'package:bomatrack/authscreens/complete_profile/view/complete_profile.dart';
import 'package:bomatrack/authscreens/verify/verify.dart';
import 'package:bomatrack/home/screens/home_screen.dart';
import 'package:bomatrack/services/services.dart';
import 'package:bomatrack/utils/utils.dart';
import 'package:flow_builder/flow_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

class App extends StatelessWidget {
  const App({
    super.key,
    required AuthRepository authenticationRepository,
  }) : _authRepository = authenticationRepository;

  final AuthRepository _authRepository;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider.value(
      value: _authRepository,
      child: BlocProvider(
          lazy: false,
          create: (_) => AppBloc(authRepository: _authRepository)
            ..add(const AppUserSubscriptionRequested()),
          child: const AppView()),
    );
  }
}

class AppView extends StatelessWidget {
  const AppView({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Bomatrack Auth',
        theme: ThemeData.from(
                colorScheme: ColorScheme.fromSeed(
                    seedColor: Color.fromARGB(255, 0, 104, 136)))
            .copyWith(
          textTheme: GoogleFonts.ralewayTextTheme(
            ThemeData.light().textTheme,
          ),
        ),
        darkTheme: ThemeData.from(
                colorScheme: ColorScheme.fromSeed(
                    seedColor: Color.fromARGB(255, 0, 104, 136),
                    brightness: Brightness.dark))
            .copyWith(
          textTheme: GoogleFonts.ralewayTextTheme(
            ThemeData.dark().textTheme,
          ),
        ),
        home: FlowBuilder<AppStatus>(
          state: context.select((AppBloc bloc) => bloc.state.status),
          onGeneratePages: onGeneratePages,
        ));
  }
}

List<Page<dynamic>> onGeneratePages(
    AppStatus status, List<Page<dynamic>> pages) {
  switch (status) {
    case AppStatus.authenticated:
      return [HomeScreen.page()];
    case AppStatus.unauthenticated:
      return [AuthPage.page()];
    case AppStatus.noProfile:
      return [CompleteProfile.page()];
    case AppStatus.notVerified:
      const email = "wilcheeko@gmail.com";
      return [VerifyPage.page(email)];
    default:
      return [SplashPage.page()];
  }
}
