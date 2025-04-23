import 'package:bomatrack/features/home/presentation/bloc/bloc.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bomatrack/models/unit.dart';

class UnitsPage extends StatefulWidget {
  const UnitsPage({super.key});

  @override
  State<UnitsPage> createState() => _UnitsPageState();
}

class _UnitsPageState extends State<UnitsPage> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        if (state is HomeLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is HomeError) {
          return _ErrorScreen(
            error: state.error,
            onRetry: () => context.read<HomeBloc>().add(LoadHome()),
          );
        } else if (state is HomeLoaded) {
          if (state.units.isEmpty) {
            return const NoUnitsScreen();
          }
          
          // Apply filters
          var filteredUnits = state.units;
          
          // Filter by status
          if (_statusFilter != 'all') {
            filteredUnits = filteredUnits.where(
              (unit) => unit.status.toLowerCase() == _statusFilter.toLowerCase()
            ).toList();
          }
          
          // Filter by search query
          if (_searchQuery.isNotEmpty) {
            filteredUnits = filteredUnits.where(
              (unit) => unit.unitNumber.toLowerCase().contains(_searchQuery.toLowerCase())
            ).toList();
          }
          
          // Check if no units match the filters
          if (filteredUnits.isEmpty) {
            return _buildNoResultsView();
          }

          // Group units by floor
          var unitsByFloor = groupBy(filteredUnits, (Unit unit) => unit.unitNumber[0]);

          return Scaffold(
            body: Column(
              children: [
                _buildFilterBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      context.read<HomeBloc>().add(LoadHome());
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        ...unitsByFloor.entries.map((entry) {
                          String floorId = entry.key;
                          List<Unit> floorUnits = entry.value;
                          return SliverStickyHeader.builder(
                            builder: (context, state) => Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
                                    offset: const Offset(0, 2),
                                    blurRadius: 5,
                                    blurStyle: BlurStyle.normal,
                                  ),
                                ],
                              ),
                              child: Text(
                                'Floor $floorId',
                                style: Theme.of(context).textTheme.headlineSmall!.apply(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                              ),
                            ),
                            sliver: SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((context, index) {
                                  var unit = floorUnits[index];
                                  return _buildUnitCard(context, unit, state);
                                }, childCount: floorUnits.length),
                              ),
                            ),
                          );
                        }),
                        SliverToBoxAdapter(
                          child: SizedBox(height: 80), // Space for the FAB
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _showAddUnitDialog(context, state),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Add Unit'),
              tooltip: 'Add a new unit',
            ),
          );
        }
        return const NoUnitsScreen();
      },
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search units',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(context, 'All', 'all'),
                _buildFilterChip(context, 'Available', 'available'),
                _buildFilterChip(context, 'Occupied', 'occupied'),
                _buildFilterChip(context, 'Unavailable', 'unavailable'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String value) {
    final bool selected = _statusFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        labelStyle: TextStyle(
          color: selected 
              ? Theme.of(context).colorScheme.onPrimary 
              : Theme.of(context).colorScheme.onSurface,
        ),
        selected: selected,
        selectedColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        onSelected: (selected) {
          setState(() {
            _statusFilter = selected ? value : 'all';
          });
        },
      ),
    );
  }

  Widget _buildUnitCard(BuildContext context, Unit unit, HomeLoaded state) {
    final tenancy = state.unitTenancies
        .firstWhereOrNull((e) => e.unitId == unit.id && e.status.toLowerCase() == 'active');
    
    final tenant = tenancy != null
        ? state.tenants.firstWhereOrNull((t) => t.id == tenancy.tenantId)
        : null;
    
    // Get theme colors
    final primaryColor = Theme.of(context).colorScheme.primary;
    final availableColor = Theme.of(context).colorScheme.secondary;
    
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: unit.status == 'available' 
              ? availableColor.withOpacity(0.5) 
              : primaryColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Unit ${unit.unitNumber}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: unit.status == 'available'
                        ? availableColor.withOpacity(0.1)
                        : primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unit.status.capitalize,
                    style: TextStyle(
                      color: unit.status == 'available'
                          ? availableColor
                          : primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: tenant != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline, 
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${tenant.firstName} ${tenant.lastName}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        if (tenancy != null)
                          Row(
                            children: [
                              Icon(Icons.payments_outlined, 
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Rent: ${tenancy.monthlyRent}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'No active tenant',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
          ButtonBar(
            alignment: MainAxisAlignment.end,
            children: [
              if (unit.status == 'available')
                TextButton.icon(
                  icon: Icon(Icons.person_add, 
                    size: 18,
                    color: primaryColor,
                  ),
                  label: Text('Add Tenant', 
                    style: TextStyle(color: primaryColor),
                  ),
                  onPressed: () {
                    // Navigate to add tenant page with this unit pre-selected
                    _showAddTenantPrompt(context, unit);
                  },
                )
              else
                TextButton.icon(
                  icon: Icon(Icons.info_outline, 
                    size: 18,
                    color: primaryColor,
                  ),
                  label: Text('Details',
                    style: TextStyle(color: primaryColor),
                  ),
                  onPressed: () {
                    // Show more details about the unit and tenant
                    _showUnitDetails(context, unit, tenant, tenancy);
                  },
                ),
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onPressed: () {
                  _showUnitOptions(context, unit);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 20),
          Text(
            'No units match your filters',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
                _statusFilter = 'all';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  void _showAddTenantPrompt(BuildContext context, Unit unit) {
    // This would navigate to your add tenant page with this unit pre-selected
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Add tenant functionality coming soon'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showUnitDetails(BuildContext context, Unit unit, dynamic tenant, dynamic tenancy) {
    // Show a modal with more details about the unit and tenant
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Unit ${unit.unitNumber} Details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            ListTile(
              leading: Icon(Icons.home, color: Theme.of(context).colorScheme.primary),
              title: Text('Unit Number', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              subtitle: Text(unit.unitNumber, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            ListTile(
              leading: Icon(
                Icons.check_circle, 
                color: unit.status == 'available' 
                    ? Theme.of(context).colorScheme.secondary 
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text('Status', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              subtitle: Text(
                unit.status.capitalize,
                style: TextStyle(
                  color: unit.status == 'available'
                      ? Theme.of(context).colorScheme.secondary
                      : Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (tenant != null) ...[
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              Text(
                'Tenant Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              ListTile(
                leading: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                title: Text('Name', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                subtitle: Text(
                  '${tenant.firstName} ${tenant.lastName}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                ),
              ),
              if (tenant.phone != null)
                ListTile(
                  leading: Icon(Icons.phone, color: Theme.of(context).colorScheme.primary),
                  title: Text('Contact', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  subtitle: Text(
                    tenant.phone,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                  ),
                ),
              if (tenancy != null)
                ListTile(
                  leading: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                  title: Text('Lease Start', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  subtitle: Text(
                    tenancy.startDate.toString().split(' ')[0],
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                  ),
                ),
              if (tenancy != null)
                ListTile(
                  leading: Icon(Icons.payments, color: Theme.of(context).colorScheme.primary),
                  title: Text('Monthly Rent', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  subtitle: Text(
                    '\$${tenancy.monthlyRent}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnitOptions(BuildContext context, Unit unit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              title: Text('Edit Unit', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Edit unit functionality coming soon'),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(
                unit.status.toLowerCase() == 'available'
                    ? Icons.do_not_disturb
                    : Icons.check_circle_outline,
                color: unit.status.toLowerCase() == 'available'
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.secondary,
              ),
              title: Text(
                unit.status.toLowerCase() == 'available'
                    ? 'Mark as Unavailable'
                    : 'Mark as Available',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              onTap: () {
                Navigator.pop(context);
                context.read<HomeBloc>().add(
                  UpdateUnitStatus(
                    unitId: unit.id,
                    newStatus: unit.status.toLowerCase() == 'available' ? 'unavailable' : 'available',
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Updating unit status...'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddUnitDialog(BuildContext context, HomeLoaded state) {
    final formKey = GlobalKey<FormState>();
    final unitNumberController = TextEditingController();
    int? selectedFloorId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add New Unit',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: InputDecoration(
                  labelText: 'Floor',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                hint: Text(
                  'Select Floor', 
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
                ),
                dropdownColor: Theme.of(context).colorScheme.surface,
                items: state.floors.map((floor) {
                  return DropdownMenuItem<int>(
                    value: floor.id,
                    child: Text(
                      'Floor ${floor.floorNumber}',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedFloorId = value;
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a floor';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: unitNumberController,
                decoration: InputDecoration(
                  labelText: 'Unit Number',
                  hintText: 'e.g. 101',
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a unit number';
                  }
                  return null;
                },
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final String unitNumber = unitNumberController.text.trim();
                      
                      context.read<HomeBloc>().add(
                        AddUnit(
                          unitNumber: unitNumber,
                          floorId: selectedFloorId!,
                          propertyId: state.selectedProperty!.id,
                        ),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Adding unit...'),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Add Unit'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoUnitsScreen extends StatelessWidget {
  const NoUnitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(slivers: [
      SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.apartment_outlined,
                  size: 120,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'No Units Yet',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Add your first unit and start managing\nyour property more efficiently',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('Add Unit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorScreen({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 120,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Oops! Something Went Wrong',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String get capitalize => isNotEmpty ? '${this[0].toUpperCase()}${substring(1)}' : '';
}
