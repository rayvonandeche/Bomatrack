import 'package:bomatrack/features/auth/presentation/signin/cubit/sign_in_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:formz/formz.dart';

class SignInForm extends StatelessWidget {
  const SignInForm({super.key, required this.toggleView});
  final Function? toggleView;

  @override
  Widget build(BuildContext context) {
    return Align(
        alignment: const Alignment(0, -1 / 3),
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flex(
                  direction: Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image.asset(
                      'lib/assets/images/logo.png',
                      height: 200,
                    ),
                  ],
                ),
                Text(
                  'Welcome back!',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                Text(
                  'Enter your details to login to your account.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                _EmailInput(),
                const SizedBox(height: 8),
                _PasswordInput(),
                const SizedBox(height: 8),
                _SignInButton(),
                const Divider(),
                _GoogleSignInButton(),
                const SizedBox(height: 8),
                _SignUpButton(toggleView as Function()),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'lib/assets/images/brand.png',
                    width: MediaQuery.of(context).size.width / 2.2,
                  ),
                ),
              ],
            )));
  }
}

class _EmailInput extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final displayError = context.select(
      (SignInCubit cubit) => cubit.state.email.displayError,
    );

    return TextField(
      key: const Key('loginForm_emailInput_textField'),
      onChanged: (email) => context.read<SignInCubit>().emailChanged(email),
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        helperText: 'example@gmail.com',
        helperStyle: TextStyle(color: Colors.grey[600]),
        errorText: displayError != null ? 'invalid email' : null,
      ),
    );
  }
}

class _PasswordInput extends StatefulWidget {
  @override
  State<_PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<_PasswordInput> {
  bool _isPasswordVisible = true;
  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayError = context
        .select((SignInCubit cubit) => cubit.state.password.displayError);

    return TextField(
        key: const Key('loginForm_passwordInput_textfield'),
        onChanged: (email) =>
            context.read<SignInCubit>().passwordChanged(email),
        keyboardType: TextInputType.visiblePassword,
        obscureText: _isPasswordVisible,
        decoration: InputDecoration(
            labelText: 'Password',
            errorText: displayError != null ? 'invalid password' : null,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: _togglePasswordVisibility,
            )));
  }
}

class _SignInButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isInProgress = context.select(
      (SignInCubit cubit) => cubit.state.status.isInProgress,
    );

    final isValid = context.select(
      (SignInCubit cubit) => cubit.state.isValid,
    );

    return ElevatedButton(
      key: const Key('loginForm_continue_raisedButton'),
      onPressed:
          isValid ? () => context.read<SignInCubit>().signInWithEmail() : null,
      child: isInProgress
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                backgroundColor: Colors.white30,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
              ))
          : const Text('Login'),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const Key('loginForm_googleSignIn_raisedButton'),
      onPressed: () => context.read<SignInCubit>().signInWithGoogle(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('lib/assets/images/google_icon.png', height: 30),
          const Text('Sign In With Google'),
        ],
      ),
    );
  }
}

class _SignUpButton extends StatelessWidget {
  const _SignUpButton(this.toggleView);
  final VoidCallback toggleView;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: toggleView,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Don\'t have an account? ',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Create account',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    decoration: TextDecoration.underline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
