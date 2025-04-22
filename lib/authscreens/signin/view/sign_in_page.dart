import 'package:bomatrack/authscreens/signin/signin.dart';
import 'package:bomatrack/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key, this.toggleView});
  final Function? toggleView;

  static Page<void> page() => const MaterialPage(child: SignInPage());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocProvider(
        create: (_) => SignInCubit(context.read<AuthRepository>()),
        child: BlocListener<SignInCubit, SignInState>(
          listener: (context, state) {
            if (state.errorMessage != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    content: Text(state.errorMessage ?? 'Error')),
                );
            }
          },
          child: SignInForm(toggleView: toggleView),
        ),
      ),
    );
  }
}
