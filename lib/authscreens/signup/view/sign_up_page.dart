
import 'package:bomatrack/authscreens/signup/signup.dart';
import 'package:bomatrack/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key, this.toggleView});
  final Function? toggleView;

  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const SignUpPage());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: BlocProvider<SignUpCubit>(
          create: (_) => SignUpCubit(context.read<AuthRepository>()),
          child:  SignUpForm(toggleView: toggleView),
        ),
      ),
    );
  }
}
