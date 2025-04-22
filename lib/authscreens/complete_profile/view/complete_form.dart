import 'package:bomatrack/authscreens/complete_profile/cubit/complete_profile_cubit.dart';
import 'package:bomatrack/authscreens/complete_profile/view/widgets.dart';
import 'package:bomatrack/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';

class CompleteForm extends StatelessWidget {
  const CompleteForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Spacer(),
          Text('Almost done!', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 8),
          Text('Finish up creating your account',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          if (!context.read<AuthRepository>().isGoogleSignIn)
            const Row(
              children: [
                Expanded(
                  child: FirstNameInput(),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: LastNameInput(),
                )
              ],
            ),
          const SizedBox(height: 8),
          const UserNameInput(),
          const SizedBox(height: 8),
          const PhoneInput(),
          const SizedBox(height: 8),
          OrganizationInput(
            onValidationChanged: (isValid, orgId) {
              context
                  .read<CompleteProfileCubit>()
                  .organizationValidationChanged(
                    isValid,
                  );
            },
          ),
          const SizedBox(height: 18),
          BlocBuilder<CompleteProfileCubit, CompleteProfileState>(
              builder: (_, state) {
            return SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: state.isValid && state.isOrganizationValidated
                      ? () {
                          context.read<CompleteProfileCubit>().formSubmitted();
                        }
                      : null,
                  child: state.status.isInProgress
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white,strokeWidth: 2,))
                      : const Text('Finish Up'),
                ));
          }),
          const Spacer(flex: 2),
          Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: MediaQuery.of(context).size.width / 2.1,
              child: Image.asset('lib/assets/images/brand.png'),
            ),
          ),
        ]));
  }
}
