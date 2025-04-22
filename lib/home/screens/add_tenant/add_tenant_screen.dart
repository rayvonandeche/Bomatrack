import 'package:bomatrack/home/bloc/home_bloc.dart';
import 'package:bomatrack/home/screens/add_tenant/bloc/add_tenant_bloc.dart';
import 'package:bomatrack/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class AddTenantScreen extends StatelessWidget {
  const AddTenantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AddTenantBloc(),
      child: const AddTenant(),
    );
  }
}

class AddTenant extends StatefulWidget {
  const AddTenant({super.key});

  @override
  State<AddTenant> createState() => _NewTenantScreenState();
}

class _NewTenantScreenState extends State<AddTenant> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _depositController = TextEditingController();
  final TextEditingController _rentController = TextEditingController();
  final TextEditingController _unitSearchController = TextEditingController();

  List<Unit> _filteredUnits = [];
  final List<Unit> _selectedUnits = [];

  void _filterUnits(String query,
      {required List<Unit> units, required List<UnitTenancy> tenancies}) {
    setState(() {
      _filteredUnits = units
          .where((unit) =>
              unit.unitNumber.toLowerCase().contains(query.toLowerCase()) &&
              unit.status.toLowerCase() == 'available') // Use unit status
          .toList();
    });
  }

  void _selectUnit(Unit unit) {
    setState(() {
      if (!_selectedUnits.contains(unit)) {
        _selectedUnits.add(unit);
      }
      _unitSearchController.clear();
      _filteredUnits.clear();
    });
  }

  void _removeUnit(Unit unit) {
    setState(() {
      _selectedUnits.remove(unit);
    });
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now());
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  bool _validateFields() {
    return _formKey.currentState?.validate() ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AddTenantBloc, AddTenantState>(
      listener: (context, state) {
        if (state is AddTenantSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tenant added successfully')),
          );
          Navigator.pop(context);
        } else if (state is AddTenantError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.error}')),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('New Tenant'),
        ),
        body: Stack(
          children: [
            Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Personal Information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'First name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Last name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final emailRegex =
                              RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$');
                          if (!emailRegex.hasMatch(value)) {
                            return 'Please enter a valid email address';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Phone number is required';
                        }
                        if (value.length != 10 ||
                            int.tryParse(value) == null) {
                          return 'Phone number must be exactly 10 digits';
                        }
                        if (!value.startsWith('07') &&
                            !value.startsWith('01')) {
                          return 'Phone number must start with 07 or 01';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: 'ID Number',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'ID number is required';
                        }
                        if (!RegExp(r'^\d+$').hasMatch(value)) {
                          return 'ID number must contain only digits';
                        }
                        if (value.length != 8 && value.length != 9) {
                          return 'ID number must be 8 or 9 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emergencyContactController,
                      decoration: const InputDecoration(
                        labelText: 'Emergency Contact',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Emergency contact is required';
                        }
                        if (value.length != 10 ||
                            int.tryParse(value) == null) {
                          return 'Emergency contact must be exactly 10 digits';
                        }
                        if (!value.startsWith('07') &&
                            !value.startsWith('01')) {
                          return 'Emergency contact must start with 07 or 01';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Lease Information',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _unitSearchController,
                      decoration: const InputDecoration(
                        labelText: 'Search Units',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (query) {
                        final state = context.read<HomeBloc>().state;
                        if (state is HomeLoaded) {
                          _filterUnits(query,
                              units: state.units,
                              tenancies: state.unitTenancies);
                        }
                      },
                    ),
                    if (_filteredUnits.isNotEmpty)
                      Container(
                        height: 200,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ListView.builder(
                          itemCount: _filteredUnits.length,
                          itemBuilder: (context, index) {
                            final unit = _filteredUnits[index];
                            return ListTile(
                              title: Text(unit.unitNumber),
                              onTap: () => _selectUnit(unit),
                            );
                          },
                        ),
                      ),
                    if (_selectedUnits.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedUnits
                            .map((unit) => Chip(
                                  label: Text(unit.unitNumber),
                                  onDeleted: () => _removeUnit(unit),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rentController,
                      decoration: const InputDecoration(
                        labelText: 'Monthly Rent (Ksh)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Rent amount is required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    // const SizedBox(height: 16),
                    // TextFormField(
                    //   controller: _depositController,
                    //   decoration: const InputDecoration(
                    //     labelText: 'Deposit Amount (Ksh) (Optional)',
                    //     border: OutlineInputBorder(),
                    //   ),
                    //   keyboardType: TextInputType.number,
                    // ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateController,
                      decoration: const InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Start date is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    BlocBuilder<AddTenantBloc, AddTenantState>(
                      builder: (context, state) {
                        bool isLoading = state is AddTenantLoading;
                        return ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  if (_validateFields() &&
                                      _selectedUnits.isNotEmpty) {
                                    final homeState = context
                                        .read<HomeBloc>()
                                        .state as HomeLoaded;
                                    context.read<AddTenantBloc>().add(
                                          AddTenantPressed(
                                            firstName:
                                                _firstNameController.text.trim(),
                                            secondName:
                                                _lastNameController.text.trim(),
                                            idNumber:
                                                _idController.text.trim(),
                                            emergencyContact:
                                                _emergencyContactController
                                                    .text
                                                    .trim(),
                                            unitIds: _selectedUnits
                                                .map((e) => e.id)
                                                .toList(),
                                            phone:
                                                _phoneController.text.trim(),
                                            propertyId:
                                                homeState.selectedProperty!.id,
                                            startDate: _dateController.text,
                                            rent: int.parse(
                                                _rentController.text.trim()),
                                            deposit: _depositController
                                                    .text.isNotEmpty
                                                ? int.parse(_depositController
                                                    .text
                                                    .trim())
                                                : 0,
                                            email:
                                                _emailController.text.trim(),
                                          ),
                                        );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            isLoading ? 'Adding Tenant...' : 'Add Tenant',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            BlocBuilder<AddTenantBloc, AddTenantState>(
              builder: (context, state) {
                if (state is AddTenantLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
