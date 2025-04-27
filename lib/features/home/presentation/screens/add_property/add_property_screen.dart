import 'package:bomatrack/features/home/presentation/screens/add_property/bloc/add_property_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AddPropertyScreen extends StatelessWidget {
  const AddPropertyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AddPropertyBloc(),
      child: const AddProperty(),
    );
  }
}

class AddProperty extends StatefulWidget {
  const AddProperty({super.key});

  @override
  State<AddProperty> createState() => _NewPropertyScreenState();
}

class _NewPropertyScreenState extends State<AddProperty> {
  final _formKey = GlobalKey<FormState>();

  final _propertyNameController = TextEditingController();
  final _propertyAddressController = TextEditingController();
  final _defaultRentController = TextEditingController();
  final _floorCountController = TextEditingController();
  final _unitsPerFloorController = TextEditingController();
  final _customFloorUnitsController = TextEditingController();
  final _customFloorRentController = TextEditingController();

  bool _showCustomFloorConfig = false;

  @override
  void dispose() {
    _propertyNameController.dispose();
    _propertyAddressController.dispose();
    _defaultRentController.dispose();
    _floorCountController.dispose();
    _unitsPerFloorController.dispose();
    _customFloorUnitsController.dispose();
    _customFloorRentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AddPropertyBloc, AddPropertyState>(
      listener: (context, state) {
        if (state is AddPropertySuccess) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Property added successfully')),
          );
        } else if (state is AddPropertyFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add New Property'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              // Property Information Section
              _buildCard(
                title: 'Property Information',
                description:
                    'Enter basic details about the property, such as its name and address.',
                children: [
                  _buildTextField(
                    controller: _propertyNameController,
                    label: 'Property Name',
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Property name is required'
                        : null,
                  ),
                  _buildTextField(
                    controller: _propertyAddressController,
                    label: 'Property Address',
                    helper:
                        'E.g Jamhuri Estate, Block C, Ngong Rd, Nairobi 00100',
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Property address is required'
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Floor Configuration Section
              _buildCard(
                title: 'Floor Configuration',
                description:
                    'Specify the number of floors, starting floor number, and the number of units on each floor.',
                children: [
                  _buildTextField(
                    controller: _floorCountController,
                    label: 'Number of Floors',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (int.parse(value!) < 1) return 'Must be at least 1';
                      return null;
                    },
                  ),
                  _buildTextField(
                    controller: _unitsPerFloorController,
                    label: 'Units per Floor',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value?.isEmpty ?? true) return 'Required';
                      if (int.parse(value!) < 1) return 'Must be at least 1';
                      return null;
                    },
                  ),
                  // _buildTextField(
                  //   controller: _defaultRentController,
                  //   label: 'Rent',
                  //   prefix: 'Ksh ',
                  //   keyboardType: TextInputType.number,
                  //   inputFormatters: [
                  //     FilteringTextInputFormatter.deny(RegExp(r'[^0-9]')),
                  //   ],
                  //   validator: (value) {
                  //     if (value?.isEmpty ?? true) return 'Required';
                  //     if (int.parse(value!) < 1) {
                  //       return 'Must be greater than 0';
                  //     }
                  //     return null;
                  //   },
                  // ),
                ],
              ),
              const SizedBox(height: 16),

              // Custom Floor Configuration Section
              _buildCard(
                title: 'Custom Floor Configuration',
                description:
                    'Add a custom floor with a different number of units and rent.',
                children: [
                  SwitchListTile(
                    value: _showCustomFloorConfig,
                    onChanged: (value) {
                      setState(() => _showCustomFloorConfig = value);
                    },
                    title: const Text('Add Custom Floor?'),
                  ),
                  if (_showCustomFloorConfig) ...[
                    _buildTextField(
                      controller: _customFloorUnitsController,
                      label: 'Custom Floor Units',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    _buildTextField(
                      controller: _customFloorRentController,
                      label: 'Custom Floor Rent',
                      prefix: 'Ksh ',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.singleLineFormatter
                      ],
                      validator: (value) {
                        if (value?.isEmpty ?? true) return 'Required';
                        if (int.parse(value!) < 1) {
                          return 'Must be greater than 0';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: () {
                  // Validate the form and add the property to the Bloc
                  if (_formKey.currentState!.validate()) {
                    context.read<AddPropertyBloc>().add(AddPropertyPressed(
                        propertyName: _propertyNameController.text,
                        propertyAddress: _propertyAddressController.text,
                        floorCount: _floorCountController.text,
                        unitsPerFloor: _unitsPerFloorController.text));
                  }
                },
                child: Builder(builder: (context) {
                  final state = context.read<AddPropertyBloc>().state;
                  return state is AddPropertyLoading
                      ? const CircularProgressIndicator()
                      : const Text('Submit');
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String description,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    TextInputType keyboardType = TextInputType.text,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          helperText: helper,
          labelText: label,
          prefixText: prefix,
          border: const OutlineInputBorder(),
        ),
        validator: validator,
        inputFormatters: inputFormatters,
        keyboardType: keyboardType,
      ),
    );
  }
}
