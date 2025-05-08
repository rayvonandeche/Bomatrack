import 'package:bomatrack/features/home/presentation/bloc/bloc.dart';
import 'package:bomatrack/features/home/presentation/screens/tenant_details/bloc/tenant_details_page_bloc.dart';
import 'package:flutter/material.dart';
import 'package:bomatrack/models/models.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bomatrack/core/theme/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class TenantDetailsPage extends StatelessWidget {
  final Tenant tenant;
  final List<Unit> units;
  final List<UnitTenancy> tenancies;

  const TenantDetailsPage({
    required this.tenant,
    required this.units,
    required this.tenancies,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // We'll keep all tenancies but still maintain the active/ended distinction
    // for UI display purposes without filtering them out
    return BlocProvider(
      create: (context) => TenantDetailsPageBloc(),
      child: TenantDetails(
        tenant: tenant,
        units: units,
        tenancies: tenancies,
      ),
    );
  }
}

class TenantDetails extends StatefulWidget {
  final Tenant tenant;
  final List<Unit> units;
  final List<UnitTenancy> tenancies;

  const TenantDetails({
    required this.tenant,
    required this.units,
    required this.tenancies,
    super.key,
  });

  @override
  State<TenantDetails> createState() => _TenantDetailsState();
}

class _TenantDetailsState extends State<TenantDetails> {
  late List<Unit> _units;
  late List<UnitTenancy> _tenancies;
  late List<TenantDiscountGroup> _discountGroups = [];

  @override
  void initState() {
    super.initState();
    _units = List.from(widget.units);
    _tenancies = List.from(widget.tenancies);
    _loadDiscountGroups();
  }

  void _loadDiscountGroups() {
    final state = context.read<HomeBloc>().state;
    if (state is HomeLoaded) {
      _discountGroups = state.discountGroups
          .where((group) => group.tenantId == widget.tenant.id)
          .toList();
    }
  }

  void _addUnit() {
    final formKey = GlobalKey<FormState>();
    int? selectedUnitId;
    final rentController = TextEditingController();
    DateTime startDate = DateTime.now();
    final startDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(startDate),
    );

    // Get available units from HomeBloc state
    final state = context.read<HomeBloc>().state;
    List<Unit> availableUnits = [];

    if (state is HomeLoaded) {
      // Filter for units that are available (not occupied)
      availableUnits = state.units
          .where((unit) => unit.status.toLowerCase() == 'available')
          .toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: BlocProvider.of<HomeBloc>(context),
        child: BlocProvider.value(
          value: BlocProvider.of<TenantDetailsPageBloc>(context),
          child: BlocListener<TenantDetailsPageBloc, TenantDetailsPageState>(
            listener: (context, state) {
              if (state is TenantDetailsPageSuccess) {
                Navigator.pop(context); // Close the bottom sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unit added successfully.')),
                );
                // Remove manual data reload as real-time updates will handle it
                // context.read<HomeBloc>().add(LoadHome());
              } else if (state is TenantDetailsPageError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${state.error}')),
                );
              }
            },
            child: StatefulBuilder(
              builder: (context, setState) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Add Unit to Tenant',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Unit selection dropdown
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Select Unit',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedUnitId,
                          items: availableUnits.map((unit) {
                            return DropdownMenuItem<int>(
                              value: unit.id,
                              child: Text('Unit ${unit.unitNumber}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedUnitId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a unit';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Monthly rent field
                        TextFormField(
                          controller: rentController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Monthly Rent',
                            hintText: 'Enter monthly rent amount',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the monthly rent';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Start date field
                        TextFormField(
                          controller: startDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: () async {
                            final selectedDate = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );

                            if (selectedDate != null) {
                              setState(() {
                                startDate = selectedDate;
                                startDateController.text =
                                    DateFormat('yyyy-MM-dd').format(startDate);
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 24),

                        BlocBuilder<TenantDetailsPageBloc,
                            TenantDetailsPageState>(
                          builder: (context, state) {
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: state is TenantDetailsPageLoading
                                    ? null
                                    : () {
                                        if (formKey.currentState!.validate()) {
                                          final monthlyRent = double.parse(
                                              rentController.text.trim());

                                          context
                                              .read<TenantDetailsPageBloc>()
                                              .add(
                                                AddUnitPressed(
                                                  tenantId: widget.tenant.id,
                                                  unitId: selectedUnitId!,
                                                  monthlyRent:
                                                      monthlyRent.toInt(),
                                                  startDate: startDate
                                                          .toString()
                                                          .split(' ')[
                                                      0], // Format as YYYY-MM-DD
                                                ),
                                              );
                                        }
                                      },
                                child: state is TenantDetailsPageLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Add Unit'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _removeUnit(Unit unit) {
    if (_units.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A tenant must have at least one unit.')));
      return;
    }

    final TextEditingController newRentController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: BlocProvider.of<HomeBloc>(context),
        child: BlocProvider.value(
          value: BlocProvider.of<TenantDetailsPageBloc>(context),
          child: BlocListener<TenantDetailsPageBloc, TenantDetailsPageState>(
            listener: (context, state) {
              if (state is TenantDetailsPageSuccess) {
                Navigator.pop(context); // Close the bottom sheet
                setState(() {
                  _units.remove(unit);
                  _tenancies.removeWhere((t) => t.unitId == unit.id);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unit removed successfully.')),
                );
                // context.read<HomeBloc>().add(LoadHome());
              } else if (state is TenantDetailsPageError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${state.error}')),
                );
              }
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Remove Unit ${unit.unitNumber}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                        'Are you sure you want to remove Unit ${unit.unitNumber}?'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newRentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'New Monthly Rent',
                        hintText: 'Enter the new rent for this unit',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the new rent';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Note: This unit will be marked as available with the new rent amount.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    BlocBuilder<TenantDetailsPageBloc, TenantDetailsPageState>(
                      builder: (context, state) {
                        return SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: state is TenantDetailsPageLoading
                                ? null
                                : () {
                                    if (formKey.currentState!.validate()) {
                                      final newRentText =
                                          newRentController.text.trim();
                                      final newRent =
                                          double.tryParse(newRentText);

                                      if (newRent == null) {
                                        return;
                                      }

                                      context.read<TenantDetailsPageBloc>().add(
                                            RemoveUnitPressed(
                                              unitId: unit.id,
                                              newMonthlyRent: newRent.toInt(),
                                            ),
                                          );
                                    }
                                  },
                            child: state is TenantDetailsPageLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Remove Unit'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _changeUnit(Unit currentUnit) {
    final formKey = GlobalKey<FormState>();
    int? selectedUnitId;
    final rentController = TextEditingController();
    DateTime startDate = DateTime.now();
    final startDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(startDate),
    );

    // Get available units from HomeBloc state
    final state = context.read<HomeBloc>().state;
    List<Unit> availableUnits = [];

    if (state is HomeLoaded) {
      // Filter for units that are available (not occupied)
      availableUnits = state.units
          .where((unit) => unit.status.toLowerCase() == 'available')
          .toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: BlocProvider.of<HomeBloc>(context),
        child: BlocProvider.value(
          value: BlocProvider.of<TenantDetailsPageBloc>(context),
          child: BlocListener<TenantDetailsPageBloc, TenantDetailsPageState>(
            listener: (context, state) {
              if (state is TenantDetailsPageSuccess) {
                Navigator.pop(context); // Close the bottom sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Unit changed successfully.')),
                );
                // Remove manual data reload as real-time updates will handle it
                // context.read<HomeBloc>().add(LoadHome());
              } else if (state is TenantDetailsPageError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${state.error}')),
                );
              }
            },
            child: StatefulBuilder(
              builder: (context, setState) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Change Unit ${currentUnit.unitNumber}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Unit selection dropdown
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Select New Unit',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedUnitId,
                          items: availableUnits.map((unit) {
                            return DropdownMenuItem<int>(
                              value: unit.id,
                              child: Text('Unit ${unit.unitNumber}'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedUnitId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a unit';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Monthly rent field
                        TextFormField(
                          controller: rentController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'New Monthly Rent',
                            hintText: 'Enter monthly rent amount',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the monthly rent';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Start date field
                        TextFormField(
                          controller: startDateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Effective Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: () async {
                            final selectedDate = await showDatePicker(
                              context: context,
                              initialDate: startDate,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 30)),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 30)),
                            );

                            if (selectedDate != null) {
                              setState(() {
                                startDate = selectedDate;
                                startDateController.text =
                                    DateFormat('yyyy-MM-dd').format(startDate);
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 24),

                        BlocBuilder<TenantDetailsPageBloc,
                            TenantDetailsPageState>(
                          builder: (context, state) {
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: state is TenantDetailsPageLoading
                                    ? null
                                    : () {
                                        if (formKey.currentState!.validate()) {
                                          final monthlyRent = double.parse(
                                              rentController.text.trim());

                                          context
                                              .read<TenantDetailsPageBloc>()
                                              .add(
                                                ChangeUnitPressed(
                                                  tenantId: widget.tenant.id,
                                                  oldUnitId: currentUnit.id,
                                                  newUnitId: selectedUnitId!,
                                                  monthlyRent:
                                                      monthlyRent.toInt(),
                                                  startDate: startDate
                                                          .toString()
                                                          .split(' ')[
                                                      0], // Format as YYYY-MM-DD
                                                ),
                                              );
                                        }
                                      },
                                child: state is TenantDetailsPageLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Change Unit'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _addPayment() {
    final formKey = GlobalKey<FormState>();
    String paymentMethod = '';
    String referenceNumber = '';
    String description = '';
    double amount = 0;
    DateTime paymentDate = DateTime.now();
    Payment? selectedPendingPayment;
    bool isPartialPayment = false;
    final paymentDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(paymentDate),
    );

    final state = context.read<HomeBloc>().state;
    List<Payment> pendingPayments = [];
    Map<String, List<Payment>> groupedPayments = {};

    if (state is HomeLoaded && state.payments.isNotEmpty) {
      final tenantUnitTenancyIds =
          _tenancies.map((tenancy) => tenancy.id).toList();

      // Get all pending/overdue payments for this tenant
      pendingPayments = state.payments
          .where((p) =>
              (p.paymentStatus == 'pending' || p.paymentStatus == 'overdue') &&
              tenantUnitTenancyIds.contains(p.unitTenancyId))
          .toList();

      // Group payments by type, date and amount for consolidation
      for (var payment in pendingPayments) {
        String paymentType =
            payment.description?.toLowerCase().contains('deposit') ?? false
                ? 'deposit'
                : 'rent';
        // Create a key combining payment type, due date, and amount
        String key = '${paymentType}_${payment.dueDate}_${payment.amount}';
        if (!groupedPayments.containsKey(key)) {
          groupedPayments[key] = [];
        }
        groupedPayments[key]!.add(payment);
      }
    }

    // Create consolidated pending payments list for the dropdown
    List<Payment> consolidatedPendingPayments = [];
    groupedPayments.forEach((key, payments) {
      if (payments.length > 1) {
        // Get unit numbers for description
        final List<String> unitNumbers = [];
        for (var payment in payments) {
          final tenancy =
              _tenancies.firstWhere((t) => t.id == payment.unitTenancyId);
          final unit = _units.firstWhere((u) => u.id == tenancy.unitId);
          unitNumbers.add(unit.unitNumber);
        }

        // Create a consolidated payment
        consolidatedPendingPayments.add(Payment(
          id: payments.first.id,
          unitTenancyId: payments.first.unitTenancyId,
          amount: payments.first.amount,
          dueDate: payments.first.dueDate,
          paymentStatus: payments.first.paymentStatus,
          description:
              payments.first.description?.toLowerCase().contains('deposit') ??
                      false
                  ? 'Security Deposit (Units: ${unitNumbers.join(", ")})'
                  : 'Monthly Rent (Units: ${unitNumbers.join(", ")})',
          createdAt: payments.first.createdAt,
          organizationId: payments.first.organizationId,
          propertyId: payments.first.propertyId,
        ));
      } else {
        consolidatedPendingPayments.add(payments.first);
      }
    });

    // Sort consolidated payments by due date
    consolidatedPendingPayments.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return BlocProvider.value(
          value: BlocProvider.of<HomeBloc>(context),
          child: BlocProvider.value(
            value: BlocProvider.of<TenantDetailsPageBloc>(context),
            child: BlocListener<TenantDetailsPageBloc, TenantDetailsPageState>(
              listener: (context, state) {
                if (state is TenantDetailsPageSuccess) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Payment added successfully.')),
                  );
                }
              },
              child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return BlocBuilder<TenantDetailsPageBloc,
                      TenantDetailsPageState>(
                    builder: (context, state) {
                      return Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                        ),
                        child: Form(
                          key: formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Add Payment',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              // Checkbox for Partial Payment
                              Row(
                                children: [
                                  Checkbox(
                                    value: isPartialPayment,
                                    onChanged: (value) {
                                      setState(() {
                                        isPartialPayment = value!;
                                        if (isPartialPayment) {
                                          selectedPendingPayment = null;
                                        }
                                      });
                                    },
                                  ),
                                  const Text('Partial Payment'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (isPartialPayment)
                                TextFormField(
                                  decoration: const InputDecoration(
                                      labelText: 'Amount'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    amount = double.tryParse(value) ?? 0;
                                  },
                                  validator: (value) => value == null ||
                                          value.isEmpty ||
                                          double.tryParse(value) == null
                                      ? 'Please enter a valid amount'
                                      : null,
                                ),
                              const SizedBox(height: 10),
                              TextFormField(
                                decoration: const InputDecoration(
                                    labelText: 'Payment Date'),
                                readOnly: true,
                                onTap: () async {
                                  final selectedDate = await showDatePicker(
                                    context: context,
                                    initialDate: paymentDate,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime.now(),
                                  );
                                  if (selectedDate != null) {
                                    setState(() {
                                      paymentDate = selectedDate;
                                      paymentDateController.text =
                                          DateFormat('yyyy-MM-dd')
                                              .format(paymentDate);
                                    });
                                  }
                                },
                                controller: paymentDateController,
                                validator: (value) => value == null
                                    ? 'Please select a payment date'
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                    labelText: 'Payment Method'),
                                items: ['mpesa', 'bank', 'cash']
                                    .map((method) => DropdownMenuItem(
                                          value: method,
                                          child: Text(method.toUpperCase()),
                                        ))
                                    .toList(),
                                onChanged: (value) => paymentMethod = value!,
                                validator: (value) => value == null
                                    ? 'Please select a payment method'
                                    : null,
                              ),
                              const SizedBox(height: 10),
                              // Updated Dropdown for Consolidated Pending/Overdue Payments
                              DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                    labelText:
                                        'Select Pending/Overdue Payment'),
                                value: selectedPendingPayment?.id,
                                items: consolidatedPendingPayments
                                    .map((p) => p.id)
                                    .toSet()
                                    .map((id) {
                                  final payment = consolidatedPendingPayments
                                      .firstWhere((p) => p.id == id);
                                  final isSecurityDeposit = payment.description
                                          ?.toLowerCase()
                                          .contains('deposit') ??
                                      false;
                                  final isConsolidated =
                                      payment.description?.contains('Units:') ??
                                          false;
                                  final displayText = isSecurityDeposit
                                      ? payment.description!
                                      : isConsolidated
                                          ? 'Due: ${DateFormat('MMMM dd, yyyy').format(payment.dueDate)} - Amount: ${NumberFormat.currency(symbol: 'Ksh').format(payment.amount)} (${payment.description})'
                                          : 'Due: ${DateFormat('MMMM dd, yyyy').format(payment.dueDate)} - Amount: ${NumberFormat.currency(symbol: 'Ksh').format(payment.amount)}';
                                  return DropdownMenuItem<int>(
                                    value: id,
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width -
                                          100,
                                      child: Text(displayText,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (paymentId) {
                                  if (paymentId != null) {
                                    setState(() {
                                      selectedPendingPayment =
                                          consolidatedPendingPayments
                                              .firstWhere(
                                                  (p) => p.id == paymentId);
                                      if (!isPartialPayment) {
                                        amount = selectedPendingPayment!.amount
                                            .toDouble();
                                      }
                                    });
                                  }
                                },
                                validator: (value) => value == null
                                    ? 'Please select a payment'
                                    : null,
                              ),
                              // ... rest of the form ...
                              const SizedBox(height: 10),
                              TextFormField(
                                decoration: const InputDecoration(
                                    labelText: 'Reference Number'),
                                onChanged: (value) => referenceNumber = value,
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Reference number is required'
                                        : null,
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                decoration: const InputDecoration(
                                    labelText: 'Description (Optional)'),
                                onChanged: (value) => description = value,
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: state is TenantDetailsPageLoading
                                    ? null
                                    : () {
                                        if (formKey.currentState!.validate()) {
                                          if (selectedPendingPayment == null) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                  content: Text(
                                                      'Please select a pending payment.')),
                                            );
                                            return;
                                          }

                                          // Get all payment IDs for the consolidated payment
                                          List<int> allPaymentIds = [];
                                          String paymentType =
                                              (selectedPendingPayment!
                                                          .description
                                                          ?.toLowerCase()
                                                          .contains(
                                                              'deposit') ??
                                                      false)
                                                  ? 'deposit'
                                                  : 'rent';
                                          String key =
                                              '${paymentType}_${selectedPendingPayment!.dueDate}_${selectedPendingPayment!.amount}';

                                          if (groupedPayments
                                              .containsKey(key)) {
                                            allPaymentIds =
                                                groupedPayments[key]!
                                                    .map((p) => p.id)
                                                    .toList();
                                          } else {
                                            allPaymentIds = [
                                              selectedPendingPayment!.id
                                            ];
                                          }

                                          context
                                              .read<TenantDetailsPageBloc>()
                                              .add(
                                                AddPaymentPressed(
                                                  tenantId: widget.tenant.id,
                                                  pendingPaymentId:
                                                      allPaymentIds,
                                                  amount: isPartialPayment
                                                      ? amount.toInt()
                                                      : selectedPendingPayment!
                                                          .amount
                                                          .toInt(),
                                                  paymentDate:
                                                      paymentDate.toString(),
                                                  paymentMethod: paymentMethod,
                                                  referenceNumber:
                                                      referenceNumber,
                                                  description: description,
                                                ),
                                              );
                                        }
                                      },
                                child: state is TenantDetailsPageLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Submit Payment'),
                              ),
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPaymentDetails(Payment payment, bool isDarkTheme) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            _buildDetailRow('Amount',
                NumberFormat.currency(symbol: 'Ksh').format(payment.amount)),
            _buildDetailRow('Status', payment.paymentStatus!.toUpperCase()),
            _buildDetailRow('Due Date',
                DateFormat('MMMM dd, yyyy').format(payment.dueDate)),
            if (payment.paymentDate != null)
              _buildDetailRow('Payment Date',
                  DateFormat('MMMM dd, yyyy').format(payment.paymentDate!)),
            if (payment.paymentMethod != null)
              _buildDetailRow(
                  'Payment Method', payment.paymentMethod!.toUpperCase()),
            if (payment.referenceNumber != null)
              _buildDetailRow('Reference', payment.referenceNumber!),
            if (payment.description != null && payment.description!.isNotEmpty)
              _buildDetailRow('Description', payment.description!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _removeTenant(int tenantId) {
    showDialog(
        context: context,
        builder: (_) => BlocProvider.value(
              value: BlocProvider.of<HomeBloc>(context),
              child: BlocProvider.value(
                value: BlocProvider.of<TenantDetailsPageBloc>(context),
                child:
                    BlocListener<TenantDetailsPageBloc, TenantDetailsPageState>(
                  listener: (context, state) {
                    if (state is TenantDetailsPageSuccess) {
                      Navigator.pop(context); // Close the dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tenant removed.')),
                      );
                    }
                  },
                  child: AlertDialog(
                    title: const Text('Remove Tenant'),
                    content: const Text(
                        'Are you sure you want to remove this tenant?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () {
                            context.read<TenantDetailsPageBloc>().add(
                                  RemoveTenantPressed(
                                    tenantId: tenantId,
                                  ),
                                );
                            // Remove manual data reload as real-time updates will handle it
                            // context.read<HomeBloc>().add(LoadHome());
                          },
                          child: const Text('Remove')),
                    ],
                  ),
                ),
              ),
            ));
  }

  // Function to make a phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      await launchUrl(launchUri);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch phone dialer: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _removeTenant(
                  widget.tenant.id,
                ),
              )
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                '${widget.tenant.firstName} ${widget.tenant.lastName}',
                style: GoogleFonts.raleway(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryLight,
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.account_circle,
                    size: 100,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildInfoSection(context),
                _buildUnitsSection(context),
                _buildPaymentHistorySection(context),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          _tenancies.any((t) => t.status.toLowerCase() == 'active')
              ? FloatingActionButton.extended(
                  onPressed: _addPayment,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Payment'),
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                )
              : null,
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit,
                    size: 20,
                  ),
                  onPressed: () {
                    _showEditModal(context);
                  },
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow(Icons.email, 'Email', widget.tenant.email ?? 'N/A'),
            Row(
              children: [
                Icon(Icons.phone, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Phone: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(widget.tenant.phone),
                const Spacer(),
                // Add call button
                ElevatedButton.icon(
                  onPressed: () => _makePhoneCall(widget.tenant.phone),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            _buildInfoRow(
                Icons.credit_card, 'ID Number', widget.tenant.idNumber),
            _buildInfoRow(Icons.contact_phone, 'Emergency Contact',
                widget.tenant.emergencyContact),
          ],
        ),
      ),
    );
  }

  // Edit tenant information modal
  void _showEditModal(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    
    // Controllers pre-populated with current tenant info
    final firstNameController = TextEditingController(text: widget.tenant.firstName);
    final lastNameController = TextEditingController(text: widget.tenant.lastName);
    final emailController = TextEditingController(text: widget.tenant.email ?? '');
    final phoneController = TextEditingController(text: widget.tenant.phone);
    final idNumberController = TextEditingController(text: widget.tenant.idNumber);
    final emergencyContactController = TextEditingController(text: widget.tenant.emergencyContact);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return BlocProvider.value(
          value: BlocProvider.of<TenantDetailsPageBloc>(context),
          child: BlocListener<TenantDetailsPageBloc, TenantDetailsPageState>(
            listener: (context, state) {
              if (state is TenantDetailsPageSuccess) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tenant information updated successfully'),
                    duration: Duration(seconds: 2),
                  ),
                );
                // Reload home data to reflect changes
                context.read<HomeBloc>().add(LoadHome());
              } else if (state is TenantDetailsPageError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${state.error}'),
                    duration: Duration(seconds: 3),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: BlocBuilder<TenantDetailsPageBloc, TenantDetailsPageState>(
              builder: (context, state) {
                return Padding(
                  padding: EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Edit Personal Information',
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // First Name field
                          TextFormField(
                            controller: firstNameController,
                            decoration: const InputDecoration(
                              labelText: 'First Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter first name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Last Name field
                          TextFormField(
                            controller: lastNameController,
                            decoration: const InputDecoration(
                              labelText: 'Last Name',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter last name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Email field
                          TextFormField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email (optional)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                // Simple email validation
                                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                if (!emailRegex.hasMatch(value)) {
                                  return 'Please enter a valid email address';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Phone field
                          TextFormField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter phone number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // ID Number field
                          TextFormField(
                            controller: idNumberController,
                            decoration: const InputDecoration(
                              labelText: 'ID Number',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter ID number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Emergency Contact field
                          TextFormField(
                            controller: emergencyContactController,
                            decoration: const InputDecoration(
                              labelText: 'Emergency Contact',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter emergency contact';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          
                          // Save button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: state is TenantDetailsPageLoading 
                                ? null 
                                : () {
                                  if (formKey.currentState!.validate()) {
                                    context.read<TenantDetailsPageBloc>().add(
                                      EditTenantPressed(
                                        tenantId: widget.tenant.id,
                                        firstName: firstNameController.text.trim(),
                                        lastName: lastNameController.text.trim(),
                                        email: emailController.text.trim().isEmpty 
                                          ? null 
                                          : emailController.text.trim(),
                                        phone: phoneController.text.trim(),
                                        idNumber: idNumberController.text.trim(),
                                        emergencyContact: emergencyContactController.text.trim(),
                                      ),
                                    );
                                  }
                                },
                              child: state is TenantDetailsPageLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save Changes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnitsSection(BuildContext context) {
    final bool hasDiscountGroups = _discountGroups.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rented Units',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),

            // First, show any bundled/discounted units
            if (hasDiscountGroups) ...[
              ..._discountGroups.map(
                  (discountGroup) => _buildDiscountGroupCard(discountGroup)),
              const Divider(height: 24),
            ],

            // Then show individual units (that aren't part of a discount group)
            ..._units.where((unit) {
              // Only show units that are not part of a discount group
              final tenancy = _tenancies.firstWhere((t) => t.unitId == unit.id);
              return tenancy.discountGroupId == null;
            }).map((unit) {
              final tenancy = _tenancies.firstWhere((t) => t.unitId == unit.id);
              final bool isActive = tenancy.status.toLowerCase() == 'active';

              return ListTile(
                leading: Icon(
                  Icons.home_work_rounded,
                  color: isActive ? Colors.green : Colors.grey,
                ),
                title: Text(
                  'Unit ${unit.unitNumber}',
                  style: TextStyle(
                    color: isActive ? null : Colors.grey,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                            'Rent: ${NumberFormat.currency(symbol: 'Ksh').format(tenancy.monthlyRent)}'),
                      ],
                    ),
                    Text(
                        'Since: ${DateFormat('MMMM dd, yyyy').format(tenancy.startDate)}'),
                    if (!isActive && tenancy.endDate != null)
                      Text(
                        'Ended: ${DateFormat('MMMM dd, yyyy').format(tenancy.endDate!)}',
                        style: const TextStyle(color: Colors.red),
                      ),
                  ],
                ),
                trailing: isActive
                    ? PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          switch (value) {
                            case 'change':
                              _changeUnit(unit);
                              break;
                            case 'remove':
                              _removeUnit(unit);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'change',
                            child: Row(
                              children: [
                                Icon(Icons.swap_horiz, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Change Unit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.remove_circle, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Remove Unit'),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ENDED',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              );
            }),

            // Add unit option - only show if the tenant has at least one active tenancy
            if (_tenancies.any((t) => t.status == 'active'))
              ListTile(
                leading: const Icon(Icons.add_circle, color: Colors.green),
                title: const Text('Add Unit'),
                onTap: _addUnit,
              ),

            // Coming soon: Add bundled units option
            if (_tenancies.any((t) => t.status == 'active'))
              ListTile(
                leading: const Icon(Icons.local_offer, color: Colors.grey),
                title: const Text('Add Bundled Units with Discount'),
                subtitle: const Text('Coming soon',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, color: Colors.grey)),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'This feature will be available in a future update'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountGroupCard(TenantDiscountGroup group) {
    // Get all units in this discount group
    final unitIdsInGroup = _tenancies
        .where((t) => t.discountGroupId == group.id)
        .map((t) => t.unitId)
        .toList();

    final unitsInGroup =
        _units.where((u) => unitIdsInGroup.contains(u.id)).toList();

    final allActive = unitsInGroup.every((u) {
      final tenancy = _tenancies.firstWhere((t) => t.unitId == u.id);
      return tenancy.status.toLowerCase() == 'active';
    });

    return Card(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_offer,
                  color: allActive ? Colors.orange : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  group.discountName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                _buildDiscountBadge(group),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Bundled Units: ${unitsInGroup.map((u) => u.unitNumber).join(", ")}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              'Total Bundle Rent: ${NumberFormat.currency(symbol: 'Ksh').format(group.monthlyRent ?? 0)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            if (!allActive)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'One or more units in this bundle has ended',
                  style: TextStyle(
                    color: Colors.red,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountBadge(TenantDiscountGroup group) {
    final String discountText;
    if (group.discountType == 'flat') {
      discountText =
          '- ${NumberFormat.currency(symbol: 'Ksh').format(group.discountValue)}';
    } else {
      discountText = '${group.discountValue.toStringAsFixed(0)}% OFF';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Text(
        discountText,
        style: TextStyle(
          color: Colors.orange.shade900,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _addBundledUnits() {
    final formKey = GlobalKey<FormState>();
    final discountNameController = TextEditingController();
    final rentController = TextEditingController();
    final discountValueController = TextEditingController();
    String discountType = 'flat'; // Default to flat discount
    DateTime startDate = DateTime.now();
    final startDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(startDate),
    );

    // Get available units from HomeBloc state
    final state = context.read<HomeBloc>().state;
    List<Unit> availableUnits = [];
    List<Unit> selectedUnits = [];
    double standardTotalRent = 0.0;

    if (state is HomeLoaded) {
      // Filter for units that are available (not occupied)
      availableUnits = state.units
          .where((unit) => unit.status.toLowerCase() == 'available')
          .toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: BlocProvider.of<HomeBloc>(context),
        child: BlocProvider.value(
          value: BlocProvider.of<TenantDetailsPageBloc>(context),
          child: BlocListener<TenantDetailsPageBloc, TenantDetailsPageState>(
            listener: (context, state) {
              if (state is TenantDetailsPageSuccess) {
                Navigator.pop(context); // Close the bottom sheet
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Units bundle created successfully.')),
                );
              } else if (state is TenantDetailsPageError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${state.error}')),
                );
              }
            },
            child: StatefulBuilder(
              builder: (context, setState) {
                // Calculate total standard rent when selected units change
                // Since Unit class doesn't have a rent property, we'll use the base rate
                // from available properties or a default value
                standardTotalRent = selectedUnits.isEmpty
                    ? 0.0
                    : selectedUnits.length * 10000.0; // Default calculation

                // Calculate suggested discounted price (10% off by default)
                final suggestedDiscount = standardTotalRent * 0.1;
                final suggestedPrice = standardTotalRent - suggestedDiscount;

                return Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Form(
                    key: formKey,
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Bundle Units with Discount',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create a discounted bundle for multiple units',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Bundle name
                        TextFormField(
                          controller: discountNameController,
                          decoration: const InputDecoration(
                            labelText: 'Bundle Name',
                            hintText: 'e.g., "Two Bedroom Special"',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a name for this bundle';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Unit selection - show selected units as chips
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Units:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            selectedUnits.isEmpty
                                ? const Text('No units selected',
                                    style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey))
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: selectedUnits
                                        .map((unit) => Chip(
                                              label: Text(
                                                  'Unit ${unit.unitNumber}'),
                                              deleteIcon: const Icon(
                                                  Icons.close,
                                                  size: 16),
                                              onDeleted: () => setState(() {
                                                selectedUnits.remove(unit);
                                              }),
                                            ))
                                        .toList(),
                                  ),
                            const SizedBox(height: 8),
                            // Only show available units that aren't already selected
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'Add Unit to Bundle',
                                border: OutlineInputBorder(),
                              ),
                              hint: const Text('Select units to bundle'),
                              value:
                                  null, // Always set to null to avoid duplicate value errors
                              items: availableUnits
                                  .where(
                                      (unit) => !selectedUnits.contains(unit))
                                  .map((unit) {
                                return DropdownMenuItem<int>(
                                  value: unit.id,
                                  child: Text('Unit ${unit.unitNumber}'),
                                );
                              }).toList(),
                              onChanged: (unitId) {
                                if (unitId != null) {
                                  // Find the unit by its ID
                                  final selectedUnit = availableUnits
                                      .firstWhere((u) => u.id == unitId);
                                  setState(() {
                                    selectedUnits.add(selectedUnit);
                                  });
                                }
                              },
                            ),
                          ],
                        ),

                        if (selectedUnits.isNotEmpty) ...[
                          const SizedBox(height: 16),

                          // Show standard total rent
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Standard Total Rent: ${NumberFormat.currency(symbol: 'Ksh').format(standardTotalRent)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Suggested Bundle Price: ${NumberFormat.currency(symbol: 'Ksh').format(suggestedPrice)} (10% discount)',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Discount type selection
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Flat Amount'),
                                  value: 'flat',
                                  groupValue: discountType,
                                  onChanged: (value) {
                                    setState(() {
                                      discountType = value!;
                                      // Update suggested discount value
                                      discountValueController.text =
                                          discountType == 'flat'
                                              ? suggestedDiscount
                                                  .toStringAsFixed(0)
                                              : '10';
                                    });
                                  },
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: const Text('Percentage'),
                                  value: 'percentage',
                                  groupValue: discountType,
                                  onChanged: (value) {
                                    setState(() {
                                      discountType = value!;
                                      // Update suggested discount value
                                      discountValueController.text =
                                          discountType == 'flat'
                                              ? suggestedDiscount
                                                  .toStringAsFixed(0)
                                              : '10';
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Discount value
                          TextFormField(
                            controller: discountValueController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: discountType == 'flat'
                                  ? 'Discount Amount'
                                  : 'Discount Percentage',
                              hintText: discountType == 'flat'
                                  ? 'e.g., 500'
                                  : 'e.g., 10',
                              prefixText:
                                  discountType == 'flat' ? 'Ksh ' : null,
                              suffixText:
                                  discountType == 'percentage' ? '%' : null,
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a discount value';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Bundle rent amount (final price)
                          TextFormField(
                            controller: rentController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Bundle Monthly Rent',
                              hintText: 'Enter the total bundled price',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the monthly rent';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Start date field
                          TextFormField(
                            controller: startDateController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              labelText: 'Start Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            onTap: () async {
                              final selectedDate = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime.now()
                                    .subtract(const Duration(days: 365)),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365)),
                              );

                              if (selectedDate != null) {
                                setState(() {
                                  startDate = selectedDate;
                                  startDateController.text =
                                      DateFormat('yyyy-MM-dd')
                                          .format(startDate);
                                });
                              }
                            },
                          ),
                        ],

                        const SizedBox(height: 24),

                        BlocBuilder<TenantDetailsPageBloc,
                            TenantDetailsPageState>(
                          builder: (context, state) {
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).primaryColor,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: (selectedUnits.length < 2 ||
                                        state is TenantDetailsPageLoading)
                                    ? null // Disable if fewer than 2 units or loading
                                    : () {
                                        if (formKey.currentState!.validate()) {
                                          final discountName =
                                              discountNameController.text
                                                  .trim();
                                          final discountValue = double.parse(
                                              discountValueController.text
                                                  .trim());
                                          final monthlyRent = double.parse(
                                              rentController.text.trim());
                                          final unitIds = selectedUnits
                                              .map((u) => u.id)
                                              .toList();

                                          context
                                              .read<TenantDetailsPageBloc>()
                                              .add(
                                                CreateBundledUnitsPressed(
                                                  tenantId: widget.tenant.id,
                                                  unitIds: unitIds,
                                                  discountName: discountName,
                                                  discountType: discountType,
                                                  discountValue: discountValue,
                                                  monthlyRent: monthlyRent,
                                                  startDate: startDate
                                                          .toString()
                                                          .split(' ')[
                                                      0], // Format as YYYY-MM-DD
                                                ),
                                              );
                                        }
                                      },
                                child: state is TenantDetailsPageLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(selectedUnits.length < 2
                                        ? 'Select at least 2 units'
                                        : 'Create Bundled Units'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentHistorySection(BuildContext context) {
    final state = context.read<HomeBloc>().state;
    List<Payment> payments = [];
    if (state is HomeLoaded) {
      payments = state.payments
          .where((payment) =>
              // Include regular payments linked to unit tenancies
              _tenancies
                  .any((tenancy) => tenancy.id == payment.unitTenancyId) ||
              // OR include bundle payments linked to discount groups
              (payment.isBundlePayment == true &&
                  _discountGroups
                      .any((group) => group.id == payment.discountGroupId)))
          .toList();
    }

    // Group all payments by date, amount, type and status
    Map<String, List<Payment>> groupedPayments = {};
    for (var payment in payments) {
      // Create a key combining all relevant fields for exact matching
      String paymentType =
          payment.description?.toLowerCase().contains('deposit') ?? false
              ? 'deposit'
              : 'rent';
      String status = payment.paymentStatus ?? 'pending';
      String paymentDateStr = payment.paymentDate?.toIso8601String() ?? '';
      String key =
          '${paymentType}_${payment.dueDate}_${payment.amount}_${status}_${paymentDateStr}';

      if (!groupedPayments.containsKey(key)) {
        groupedPayments[key] = [];
      }
      groupedPayments[key]!.add(payment);
    }

    // Convert grouped payments back to a list, combining payments with same attributes
    List<Payment> consolidatedPayments = [];
    groupedPayments.forEach((key, payments) {
      // First check if it's a bundle payment (these don't need consolidation)
      if (payments.first.isBundlePayment == true) {
        consolidatedPayments.add(payments.first);
        return;
      }

      if (payments.length > 1) {
        // Create a consolidated payment
        bool isDeposit =
            payments.first.description?.toLowerCase().contains('deposit') ??
                false;

        // Get all unit numbers for the description
        final unitTenancyIds = payments.map((p) => p.unitTenancyId).toList();

        // Safer approach to find matching units
        final units = _units
            .where((u) => _tenancies
                .any((t) => unitTenancyIds.contains(t.id) && t.unitId == u.id))
            .toList();

        final unitNumbers = units.map((u) => u.unitNumber).join(', ');

        consolidatedPayments.add(Payment(
          id: payments.first.id,
          unitTenancyId: payments.first.unitTenancyId,
          amount: payments.first.amount,
          dueDate: payments.first.dueDate,
          paymentDate: payments.first.paymentDate,
          paymentStatus: payments.first.paymentStatus,
          paymentMethod: payments.first.paymentMethod,
          referenceNumber: payments.first.referenceNumber,
          description: isDeposit
              ? 'Security Deposit (Units: $unitNumbers)'
              : 'Rent Payment (Units: $unitNumbers)',
          createdAt: payments.first.createdAt,
          organizationId: payments.first.organizationId,
          propertyId: payments.first.propertyId,
        ));
      } else {
        // Single payment, add as is
        consolidatedPayments.add(payments.first);
      }
    });

    // Sort all payments by date, with most recent first
    consolidatedPayments.sort((a, b) {
      final aDate = a.paymentDate ?? a.dueDate;
      final bDate = b.paymentDate ?? b.dueDate;
      return bDate.compareTo(aDate);
    });

    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    
    // Create filtered payment lists for the tabs
    final paidPayments = consolidatedPayments.where((p) => 
      p.paymentStatus == 'paid' || p.paymentStatus == 'partial').toList();
    final pendingPayments = consolidatedPayments.where((p) => 
      p.paymentStatus == 'pending').toList();
    final overduePayments = consolidatedPayments.where((p) => 
      p.paymentStatus == 'overdue').toList();

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count and expand/collapse functionality
          PaymentHistoryHeader(
            totalCount: consolidatedPayments.length,
            paidCount: paidPayments.length,
            pendingCount: pendingPayments.length,
            overdueCount: overduePayments.length,
          ),
          
          // Tabbed payment list
          PaymentHistoryTabs(
            allPayments: consolidatedPayments,
            paidPayments: paidPayments,
            pendingPayments: pendingPayments, 
            overduePayments: overduePayments,
            isDarkTheme: isDarkTheme,
            onShowDetails: _showPaymentDetails,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}

class PaymentHistoryHeader extends StatefulWidget {
  final int totalCount;
  final int paidCount;
  final int pendingCount;
  final int overdueCount;
  
  const PaymentHistoryHeader({
    Key? key,
    required this.totalCount,
    required this.paidCount,
    required this.pendingCount,
    required this.overdueCount,
  }) : super(key: key);

  @override
  State<PaymentHistoryHeader> createState() => _PaymentHistoryHeaderState();
}

class _PaymentHistoryHeaderState extends State<PaymentHistoryHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        setState(() {
          _expanded = !_expanded;
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Payment History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.totalCount.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPaymentStat('Paid', widget.paidCount, Colors.green),
                    const SizedBox(width: 16),
                    _buildPaymentStat('Pending', widget.pendingCount, Colors.orange),
                    const SizedBox(width: 16),
                    _buildPaymentStat('Overdue', widget.overdueCount, Colors.red),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentHistoryTabs extends StatefulWidget {
  final List<Payment> allPayments;
  final List<Payment> paidPayments;
  final List<Payment> pendingPayments;
  final List<Payment> overduePayments;
  final bool isDarkTheme;
  final Function(Payment, bool) onShowDetails;

  const PaymentHistoryTabs({
    Key? key,
    required this.allPayments,
    required this.paidPayments,
    required this.pendingPayments,
    required this.overduePayments,
    required this.isDarkTheme,
    required this.onShowDetails,
  }) : super(key: key);

  @override
  State<PaymentHistoryTabs> createState() => _PaymentHistoryTabsState();
}

class _PaymentHistoryTabsState extends State<PaymentHistoryTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const int _initialItemsToShow = 5;
  Map<int, int> _itemsToShow = {0: _initialItemsToShow, 1: _initialItemsToShow, 2: _initialItemsToShow, 3: _initialItemsToShow};
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  List<Payment> _filterPayments(List<Payment> payments) {
    if (_searchQuery.isEmpty) return payments;
    
    return payments.where((payment) {
      // Search by amount
      final amountString = payment.amount.toString();
      
      // Search by date
      final dueDate = DateFormat('yyyy-MM-dd').format(payment.dueDate);
      final paymentDate = payment.paymentDate != null ? 
          DateFormat('yyyy-MM-dd').format(payment.paymentDate!) : '';
      
      // Search by description
      final description = payment.description?.toLowerCase() ?? '';
      
      // Search by status
      final status = payment.paymentStatus?.toLowerCase() ?? '';
      
      return amountString.contains(_searchQuery) ||
             dueDate.contains(_searchQuery) ||
             paymentDate.contains(_searchQuery) ||
             description.contains(_searchQuery.toLowerCase()) ||
             status.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search payments...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            tabs: [
              const Tab(text: 'All'),
              Tab(text: 'Paid (${widget.paidPayments.length})'),
              Tab(text: 'Pending (${widget.pendingPayments.length})'),
              Tab(text: 'Overdue (${widget.overduePayments.length})'),
            ],
            labelColor: Theme.of(context).colorScheme.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            indicatorSize: TabBarIndicatorSize.tab,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: (_itemsToShow[_tabController.index] ?? _initialItemsToShow) * 80.0,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentsList(_filterPayments(widget.allPayments), 0),
                _buildPaymentsList(_filterPayments(widget.paidPayments), 1),
                _buildPaymentsList(_filterPayments(widget.pendingPayments), 2),
                _buildPaymentsList(_filterPayments(widget.overduePayments), 3),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaymentHistoryFullPage(
                    payments: widget.allPayments,
                    onShowDetails: widget.onShowDetails,
                    isDarkTheme: widget.isDarkTheme,
                  ),
                ),
              );
            },
            child: const Text('View All Payment History'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsList(List<Payment> payments, int tabIndex) {
    final itemsToShow = _itemsToShow[tabIndex] ?? _initialItemsToShow;
    final displayedPayments = payments.take(itemsToShow).toList();
    
    if (payments.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No payments found',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: displayedPayments.length,
            itemBuilder: (context, index) {
              final payment = displayedPayments[index];
              return _buildPaymentListItem(payment);
            },
          ),
        ),
        if (payments.length > itemsToShow)
          TextButton(
            onPressed: () {
              setState(() {
                _itemsToShow[tabIndex] = itemsToShow + 5;
              });
            },
            child: Text('Load More (${payments.length - itemsToShow} remaining)'),
          ),
      ],
    );
  }

  Widget _buildPaymentListItem(Payment payment) {
    String statusText;
    IconData statusIcon;
    Color statusColor;
    
    if (payment.paymentStatus == 'partial') {
      statusText = 'Partial Payment';
      statusIcon = Icons.hourglass_bottom;
      statusColor = Colors.yellow.shade800;
    } else if (payment.paymentDate != null) {
      statusText = 'Paid';
      statusIcon = Icons.check;
      statusColor = Colors.green;
    } else if (payment.paymentStatus == 'overdue') {
      statusText = 'Overdue';
      statusIcon = Icons.error_outline;
      statusColor = Colors.red;
    } else {
      statusText = "Pending Payment";
      statusIcon = Icons.timelapse_outlined;
      statusColor = Colors.orange;
    }

    bool isSecurityDeposit = payment.description?.toLowerCase().contains('deposit') ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        tileColor: isSecurityDeposit
            ? (widget.isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade200)
            : null,
        onTap: () => widget.onShowDetails(payment, widget.isDarkTheme),
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(
            isSecurityDeposit ? Icons.security : statusIcon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          isSecurityDeposit ? 'Security Deposit' : 'Monthly Rent',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${statusText} • ${DateFormat('MMM dd, yyyy').format(payment.paymentDate ?? payment.dueDate)}',
          style: TextStyle(fontSize: 12, color: statusColor),
        ),
        trailing: Text(
          NumberFormat.currency(symbol: 'Ksh').format(payment.amount),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class PaymentHistoryFullPage extends StatefulWidget {
  final List<Payment> payments;
  final Function(Payment, bool) onShowDetails;
  final bool isDarkTheme;
  
  const PaymentHistoryFullPage({
    Key? key,
    required this.payments,
    required this.onShowDetails,
    required this.isDarkTheme,
  }) : super(key: key);

  @override
  State<PaymentHistoryFullPage> createState() => _PaymentHistoryFullPageState();
}

class _PaymentHistoryFullPageState extends State<PaymentHistoryFullPage> {
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    // Filter payments based on search query and date range
    final filteredPayments = widget.payments.where((payment) {
      // Filter by search query
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final amountString = payment.amount.toString();
        final dueDate = DateFormat('yyyy-MM-dd').format(payment.dueDate);
        final paymentDate = payment.paymentDate != null ?
            DateFormat('yyyy-MM-dd').format(payment.paymentDate!) : '';
        final description = payment.description?.toLowerCase() ?? '';
        final status = payment.paymentStatus?.toLowerCase() ?? '';
        
        matchesSearch = amountString.contains(_searchQuery) ||
               dueDate.contains(_searchQuery) ||
               paymentDate.contains(_searchQuery) ||
               description.contains(_searchQuery.toLowerCase()) ||
               status.contains(_searchQuery.toLowerCase());
      }
      
      // Filter by date range
      bool matchesDateRange = true;
      final date = payment.paymentDate ?? payment.dueDate;
      if (_startDate != null) {
        matchesDateRange = matchesDateRange && date.isAfter(_startDate!);
      }
      if (_endDate != null) {
        // Include the end date by adding a day
        matchesDateRange = matchesDateRange && 
            date.isBefore(_endDate!.add(const Duration(days: 1)));
      }
      
      // Filter by payment status
      bool matchesStatus = true;
      if (_selectedFilter != 'All') {
        switch (_selectedFilter) {
          case 'Paid':
            matchesStatus = payment.paymentStatus == 'paid' || 
                payment.paymentStatus == 'partial';
            break;
          case 'Pending':
            matchesStatus = payment.paymentStatus == 'pending';
            break;
          case 'Overdue':
            matchesStatus = payment.paymentStatus == 'overdue';
            break;
        }
      }
      
      return matchesSearch && matchesDateRange && matchesStatus;
    }).toList();

    // Group payments by month for better organization
    final groupedPayments = <String, List<Payment>>{};
    for (var payment in filteredPayments) {
      final date = payment.paymentDate ?? payment.dueDate;
      final monthYear = DateFormat('MMMM yyyy').format(date);
      if (!groupedPayments.containsKey(monthYear)) {
        groupedPayments[monthYear] = [];
      }
      groupedPayments[monthYear]!.add(payment);
    }

    // Sort the keys by date (most recent first)
    final sortedMonths = groupedPayments.keys.toList()
      ..sort((a, b) {
        // Convert month name to date for comparison
        final aDate = DateFormat('MMMM yyyy').parse(a);
        final bDate = DateFormat('MMMM yyyy').parse(b);
        return bDate.compareTo(aDate);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterOptions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search payments...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Active filters display
          if (_startDate != null || _endDate != null || _selectedFilter != 'All')
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_selectedFilter != 'All')
                    _buildFilterChip(
                      label: _selectedFilter,
                      onRemove: () {
                        setState(() {
                          _selectedFilter = 'All';
                        });
                      },
                    ),
                  if (_startDate != null)
                    _buildFilterChip(
                      label: 'From: ${DateFormat('MMM dd, yyyy').format(_startDate!)}',
                      onRemove: () {
                        setState(() {
                          _startDate = null;
                        });
                      },
                    ),
                  if (_endDate != null)
                    _buildFilterChip(
                      label: 'To: ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                      onRemove: () {
                        setState(() {
                          _endDate = null;
                        });
                      },
                    ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _startDate = null;
                        _endDate = null;
                        _selectedFilter = 'All';
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
            ),
            
          // Results count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${filteredPayments.length} payments found',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const Spacer(),
                // Add download/export button here if needed
              ],
            ),
          ),
          
          // Payment list grouped by month
          Expanded(
            child: filteredPayments.isEmpty
                ? const Center(
                    child: Text(
                      'No payments match your filters',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  )
                : ListView.builder(
                    itemCount: sortedMonths.length,
                    itemBuilder: (context, monthIndex) {
                      final month = sortedMonths[monthIndex];
                      final monthPayments = groupedPayments[month]!;
                      
                      return ExpansionTile(
                        initiallyExpanded: monthIndex == 0, // Expand the most recent month
                        title: Text(
                          month,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text('${monthPayments.length} payments'),
                        children: monthPayments.map((payment) {
                          return _buildPaymentListItem(payment);
                        }).toList(),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip({required String label, required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label),
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onRemove,
      ),
    );
  }
  
  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filter Payments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Payment Status', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['All', 'Paid', 'Pending', 'Overdue'].map((status) {
                    return ChoiceChip(
                      label: Text(status),
                      selected: _selectedFilter == status,
                      onSelected: (selected) {
                        if (selected) {
                          setModalState(() {
                            _selectedFilter = status;
                          });
                          setState(() {
                            _selectedFilter = status;
                          });
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Date Range', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_startDate == null
                            ? 'Start Date'
                            : DateFormat('MMM dd, yyyy').format(_startDate!)),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setModalState(() {
                              _startDate = date;
                            });
                            setState(() {
                              _startDate = date;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_endDate == null
                            ? 'End Date'
                            : DateFormat('MMM dd, yyyy').format(_endDate!)),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setModalState(() {
                              _endDate = date;
                            });
                            setState(() {
                              _endDate = date;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _selectedFilter = 'All';
                          _startDate = null;
                          _endDate = null;
                        });
                        setState(() {
                          _selectedFilter = 'All';
                          _startDate = null;
                          _endDate = null;
                        });
                      },
                      child: const Text('Clear Filters'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPaymentListItem(Payment payment) {
    String statusText;
    IconData statusIcon;
    Color statusColor;
    
    if (payment.paymentStatus == 'partial') {
      statusText = 'Partial Payment';
      statusIcon = Icons.hourglass_bottom;
      statusColor = Colors.yellow.shade800;
    } else if (payment.paymentDate != null) {
      statusText = 'Paid';
      statusIcon = Icons.check;
      statusColor = Colors.green;
    } else if (payment.paymentStatus == 'overdue') {
      statusText = 'Overdue';
      statusIcon = Icons.error_outline;
      statusColor = Colors.red;
    } else {
      statusText = "Pending Payment";
      statusIcon = Icons.timelapse_outlined;
      statusColor = Colors.orange;
    }

    bool isSecurityDeposit = payment.description?.toLowerCase().contains('deposit') ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        tileColor: isSecurityDeposit
            ? (widget.isDarkTheme ? Colors.grey.shade800 : Colors.grey.shade200)
            : null,
        onTap: () => widget.onShowDetails(payment, widget.isDarkTheme),
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(
            isSecurityDeposit ? Icons.security : statusIcon,
            color: Colors.white,
          ),
        ),
        title: Text(
          isSecurityDeposit ? 'Security Deposit' : 'Monthly Rent',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMMM dd, yyyy').format(payment.paymentDate ?? payment.dueDate),
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              NumberFormat.currency(symbol: 'Ksh').format(payment.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (payment.paymentMethod != null)
              Text(
                payment.paymentMethod!.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
