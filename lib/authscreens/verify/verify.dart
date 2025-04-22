import 'package:bomatrack/authscreens/verify/cubit/verify_page_cubit.dart';
import 'package:bomatrack/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import 'dart:async';

class VerifyPage extends StatelessWidget {
  final String email;
  const VerifyPage({super.key, required this.email});

  static Page<void> page(String email) => const MaterialPage(
        child: VerifyPage(
          email: '',
        ),
      );

  static Route<void> route(String email) => MaterialPageRoute(
      builder: (_) => VerifyPage(
            email: email,
          ));

  @override
  Widget build(BuildContext context) {
    return BlocProvider<VerifyPageCubit>(
        create: (context) => VerifyPageCubit(
              authRepository: context.read<AuthRepository>(),
            ),
        child: VerifyView(email: email));
  }
}

class VerifyView extends StatefulWidget {
  final String email;

  const VerifyView({super.key, required this.email});

  static Page<void> page() => const MaterialPage(
        child: VerifyView(
          email: '',
        ),
      );

  static Route<void> route(String email) => MaterialPageRoute(
      builder: (_) => VerifyView(
            email: email,
          ));

  @override
  State<VerifyView> createState() => _VerifyViewState();
}

class _VerifyViewState extends State<VerifyView> {
  late Timer _timer;
  int _countdown = 60;

  @override
  void initState() {
    super.initState();
    startCountdown();
  }

  void startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
        width: 40,
        height: 50,
        textStyle: const TextStyle(fontSize: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey),
        ));

    return Scaffold(
        body: BlocListener<VerifyPageCubit, VerifyPageState>(
      listener: (context, state) {
        if (state.error!.isNotEmpty) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  content: Text(state.error ?? 'Verification Failure')),
            );
        }
        if (state.isVerified) {
          Navigator.of(context).pop();
        }
      },
      child: Stack(children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  'Verify your email',
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 14),
                Text(
                  'We have sent you a verification code to your email ${widget.email}. Use it to fill below',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                Center(
                  child: Pinput(
                    length: 6,
                    defaultPinTheme: defaultPinTheme,
                    focusedPinTheme: defaultPinTheme.copyWith(),
                    onCompleted: (value) {
                      context
                          .read<VerifyPageCubit>()
                          .verifyEmail(widget.email, value);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Didn\'t receive the code??',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextButton(
                      onPressed: _countdown > 0
                          ? null
                          : () {
                              context
                                  .read<VerifyPageCubit>()
                                  .resend(widget.email);
                              startCountdown();
                            },
                      child: Text(
                        _countdown > 0
                            ? 'Resend code in ${_countdown}s'
                            : 'Resend code',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              decoration: TextDecoration.underline,
                              color: _countdown > 0
                                  ? Colors.grey
                                  : Theme.of(context).primaryColor,
                            ),
                      ),
                    )
                  ],
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 1.8,
                      child: Image.asset('lib/assets/images/brand.png'),
                    ),
                  ),
                )
              ])),
        )
      ]),
    ));
  }
}
