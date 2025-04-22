import 'package:bomatrack/authscreens/signup/signup.dart';
import 'package:bomatrack/authscreens/verify/verify.dart';
import 'package:bomatrack/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

class SignUpForm extends StatelessWidget {
  const SignUpForm({super.key, this.toggleView});
  final Function? toggleView;

  @override
  Widget build(BuildContext context) {
    return BlocListener<SignUpCubit, SignUpState>(
      listener: (context, state) {
        if (state.status.isSuccess && !context.read<AuthRepository>().isGoogleSignIn){
          Navigator.of(context).push(
            VerifyPage.route(state.email.value)
          );
        }
        if (state.status.isFailure) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  content: Text(state.errorMessage ?? 'Sign Up Failure')),
            );
        }
      },
      child: Align(
        alignment: const Alignment(0, -1 / 3),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Image.asset(
                  'lib/assets/images/logo.png',
                  height: 200,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Create account',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              Text(
                'Enter your details to create an account.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              _EmailInput(),
              const SizedBox(height: 8),
              _PasswordInput(),
              const SizedBox(height: 8),
              _ConfirmPasswordInput(),
              _SignUpButton(),
              const Divider(),
              _GoogleSignInButton(),
              const SizedBox(height: 8),
              _SignInButton(toggleView as Function()),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  'lib/assets/images/brand.png',
                  width: MediaQuery.of(context).size.width / 2.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmailInput extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final displayError = context.select(
      (SignUpCubit cubit) => cubit.state.email.displayError,
    );

    return TextField(
      key: const Key('loginForm_emailInput_textField'),
      onChanged: (email) => context.read<SignUpCubit>().emailChanged(email),
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
        .select((SignUpCubit cubit) => cubit.state.password.displayError);

    return TextField(
        key: const Key('loginForm_passwordInput_textfield'),
        onChanged: (email) =>
            context.read<SignUpCubit>().passwordChanged(email),
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

class _ConfirmPasswordInput extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final displayError = context.select(
      (SignUpCubit cubit) => cubit.state.confirmedPassword.displayError,
    );

    return TextField(
      key: const Key('signUpForm_confirmedPasswordInput_textField'),
      onChanged: (confirmPassword) =>
          context.read<SignUpCubit>().confirmedPasswordChanged(confirmPassword),
      obscureText: true,
      decoration: InputDecoration(
        labelText: 'confirm password',
        helperText: '',
        errorText: displayError != null ? 'passwords do not match' : null,
      ),
    );
  }
}

class _SignUpButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isInProgress = context.select(
      (SignUpCubit cubit) => cubit.state.status.isInProgress,
    );

    final isValid = context.select(
      (SignUpCubit cubit) => cubit.state.isValid,
    );

    return ElevatedButton(
      key: const Key('loginForm_continue_raisedButton'),
      onPressed: isValid
          ? () => context.read<SignUpCubit>().signUpFormSubmitted()
          : null,
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
          : const Text('Sign Up'),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: const Key('loginForm_googleSignIn_raisedButton'),
      onPressed: () => context.read<SignUpCubit>().signInWithGoogle(),
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

class _SignInButton extends StatelessWidget {
  final VoidCallback onPressed;                                     
  const _SignInButton(this.onPressed);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Already have an account?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              ' Sign In',
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
