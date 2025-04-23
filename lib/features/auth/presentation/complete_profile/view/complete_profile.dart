import 'package:bomatrack/features/auth/presentation/complete_profile/cubit/complete_profile_cubit.dart';
import 'package:bomatrack/features/auth/presentation/complete_profile/view/complete_form.dart';
import 'package:bomatrack/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CompleteProfile extends StatelessWidget {
  const CompleteProfile({super.key});

  static Page<void> page() => const MaterialPage(child: CompleteProfile());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: BlocProvider(
      create: (context) => CompleteProfileCubit(context.read<AuthRepository>()),
      child: const CompleteForm(),
    ));
  }
}
