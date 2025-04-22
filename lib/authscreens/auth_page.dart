import 'package:animations/animations.dart';
import 'package:bomatrack/authscreens/signin/signin.dart';
import 'package:bomatrack/authscreens/signup/signup.dart';
import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  static Page<void> page() => const MaterialPage(child: AuthPage());

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final SharedAxisTransitionType _transitionType =
      SharedAxisTransitionType.horizontal;
  bool _isSignIn = true;

  void _toggleView() {
    setState(() {
      _isSignIn = !_isSignIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: PageTransitionSwitcher(
      transitionBuilder: (
        Widget child,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return SharedAxisTransition(
          fillColor: Colors.transparent,
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: _transitionType,
          child: child,
        );
      },
      child: _isSignIn
          ? SignInPage(toggleView: _toggleView)
          : SignUpPage(toggleView: _toggleView),
    ));
  }
}
