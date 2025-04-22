import 'dart:async';

import 'package:bomatrack/authscreens/complete_profile/cubit/complete_profile_cubit.dart';
import 'package:bomatrack/config/config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class OrganizationInput extends StatefulWidget {
  final Function(bool isValid, String? orgId) onValidationChanged;

  const OrganizationInput({super.key, required this.onValidationChanged});

  @override
  State<OrganizationInput> createState() => _OrganizationInputState();
}

class _OrganizationInputState extends State<OrganizationInput> {
  static const int _initialOrgsLimit = 5;
  List<Map<String, dynamic>> _organizations = [];
  List<Map<String, dynamic>> _displayedOrganizations = [];
  String? _selectedOrganizationId;
  bool _isCodeLoading = false;
  bool _isCodeValid = false;
  final _codeController = TextEditingController();
  final _organizationController = TextEditingController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchOrganizations();
  }

  Future<void> _fetchOrganizations() async {
    try {
      final orgs = await SupabaseConfig.supabase.from('organizations').select();
      setState(() {
        _organizations = orgs;
        // Initially show only first 10 organizations
        _displayedOrganizations = orgs.take(_initialOrgsLimit).toList();
      });
    } catch (e) {
      debugPrint('Failed to fetch organizations: $e');
    }
  }

  void _filterOrganizations(String query) {
    setState(() {
      _displayedOrganizations = _organizations
          .where((org) => org['name']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _verifyCode(String code) async {
    if (code.length != 6) {
      widget.onValidationChanged(false, null);
      return;
    }

    setState(() => _isCodeLoading = true);

    try {
      final result = await SupabaseConfig.supabase
          .from('organizations')
          .select()
          .eq('id', _selectedOrganizationId!)
          .eq('code', code)
          .single();

      setState(() {
        _isCodeValid = result != null;
        _isCodeLoading = false;
      });

      widget.onValidationChanged(_isCodeValid, _selectedOrganizationId);

      if (_isCodeValid) {
        context.read<CompleteProfileCubit>().orgChanged(result['id']);
      }
    } catch (e) {
      setState(() {
        _isCodeValid = false;
        _isCodeLoading = false;
      });

      widget.onValidationChanged(false, null);
    }
  }

  void _showOrganizationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search Organizations',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _displayedOrganizations = _organizations
                                  .take(_initialOrgsLimit)
                                  .toList();
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() {
                    _filterOrganizations(value);
                  });
                },
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _displayedOrganizations.length,
                  itemBuilder: (context, index) {
                    final org = _displayedOrganizations[index];
                    return ListTile(
                      title: Text(org['name']),
                      onTap: () {
                        // Update both controllers
                        _organizationController.text = org['name'];

                        setState(() {
                          _selectedOrganizationId = org['id'] as String;
                        });

                        // Reset code verification when organization changes
                        _codeController.clear();
                        _isCodeValid = false;

                        // Notify parent about validation reset
                        widget.onValidationChanged(false, null);

                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
              actions: _displayedOrganizations.length < _organizations.length
                  ? [
                      TextButton(
                        onPressed: () {
                          // Show all organizations when user wants to see more
                          setState(() {
                            _displayedOrganizations = _organizations;
                          });
                        },
                        child: const Text('Show All Organizations'),
                      )
                    ]
                  : null,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Organization Selection TextField
        TextField(
          controller: _organizationController,
          decoration: InputDecoration(
            labelText: 'Organization',
            hintText: 'Select Organization',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: _showOrganizationDialog,
            ),
            border: const OutlineInputBorder(),
          ),
          readOnly: true,
          onTap: _showOrganizationDialog,
        ),

        const SizedBox(height: 16),

        // Organization Code Input
        // if (_selectedOrganizationId != null) ...[
          TextField(
            controller: _codeController,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            ],
            decoration: InputDecoration(
              labelText: 'Organization Code',
              hintText: 'Enter 6-digit code',
              suffixIcon: _isCodeLoading
                  ? const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _isCodeValid
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
              errorText: _codeController.text.length == 6 && !_isCodeValid
                  ? 'Invalid organization code'
                  : null,
            ),
            onChanged: (value) {
              if (value.length == 6) {
                _verifyCode(value);
              } else {
                setState(() => _isCodeValid = false);
                // Notify parent about validation reset
                widget.onValidationChanged(false, null);
              }
            },
          ),
        // ],

        // Contact message
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'If you do not see your organization or cannot verify the code, please contact the Bomatrack team.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _organizationController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}

// INPUTS
class _NewOrgInput extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const TextField(
        key: Key('new_org_input'),
        decoration: InputDecoration(
          labelText: 'New Organization',
          hintText: 'Enter organization name',
        ));
  }
}

class FirstNameInput extends StatelessWidget {
  const FirstNameInput({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CompleteProfileCubit, CompleteProfileState>(
      builder: (context, state) => TextField(
          key: const Key('first_name_input'),
          onChanged: (value) =>
              context.read<CompleteProfileCubit>().firstNameChanged(value),
          keyboardType: TextInputType.name,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
          ],
          decoration: InputDecoration(
            labelText: 'First Name',
            hintText: 'Enter your first name',
            errorText: state.firstName.displayError != null
                ? "Enter a valid name"
                : null,
          )),
    );
  }
}

class LastNameInput extends StatelessWidget {
  const LastNameInput({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CompleteProfileCubit, CompleteProfileState>(
      builder: (context, state) => TextField(
          key: const Key('last_name_input'),
          onChanged: (value) =>
              context.read<CompleteProfileCubit>().lastNameChanged(value),
          keyboardType: TextInputType.name,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
          ],
          decoration: InputDecoration(
            labelText: 'Last Name',
            hintText: 'Enter your last name',
            errorText: state.lastName.displayError,
          )),
    );
  }
}

class UserNameInput extends StatelessWidget {
  const UserNameInput({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CompleteProfileCubit, CompleteProfileState>(
      builder: (context, state) => TextField(
          key: const Key('username_input'),
          onChanged: (value) =>
              context.read<CompleteProfileCubit>().usernameChanged(value),
          keyboardType: TextInputType.name,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
          ],
          decoration: InputDecoration(
            labelText: 'Username',
            hintText: 'Enter your username',
            errorText: state.username.displayError,
          )),
    );
  }
}

class PhoneInput extends StatelessWidget {
  const PhoneInput({super.key});
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CompleteProfileCubit, CompleteProfileState>(
      builder: (context, state) => TextField(
          key: const Key('phone_input'),
          onChanged: (value) =>
              context.read<CompleteProfileCubit>().phoneNumberChanged(value),
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
          ],
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: 'Enter your phone number',
            errorText: state.phoneNumber.displayError,
          )),
    );
  }
}
