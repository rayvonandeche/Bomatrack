import 'package:bomatrack/features/home/presentation/bloc/bloc.dart';
import 'package:bomatrack/features/home/presentation/screens/tenant_details/tenant_details_page.dart';
import 'package:bomatrack/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class TenantsPage extends StatefulWidget {
  const TenantsPage({super.key});

  @override
  State<TenantsPage> createState() => _TenantsPageState();
}

class _TenantsPageState extends State<TenantsPage> {
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
    return BlocBuilder<HomeBloc, HomeState>(builder: (context, state) {
      if (state is HomeLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state is HomeError) {
        return _ErrorScreen(
          error: state.error,
          onRetry: () => context.read<HomeBloc>().add(LoadHome()),
        );
      }
      if (state is HomeLoaded) {
        if (state.tenants.isEmpty) {
          return const NoTenantsScreen();
        }
        
        // Apply filters
        var filteredTenants = List<Tenant>.from(state.tenants);
        
        // Filter by status
        if (_statusFilter != 'all') {
          filteredTenants = filteredTenants.where((tenant) {
            final tenancies = state.unitTenancies.where((ut) => ut.tenantId == tenant.id).toList();
            final bool hasActiveTenancy = tenancies.any((t) => t.status.toLowerCase() == 'active');
            return _statusFilter == 'active' ? hasActiveTenancy : !hasActiveTenancy;
          }).toList();
        }
        
        // Filter by search query
        if (_searchQuery.isNotEmpty) {
          filteredTenants = filteredTenants.where((tenant) {
            final fullName = '${tenant.firstName} ${tenant.lastName}'.toLowerCase();
            final phone = tenant.phone.toLowerCase();
            final email = tenant.email?.toLowerCase() ?? '';
            return fullName.contains(_searchQuery.toLowerCase()) || 
                   phone.contains(_searchQuery.toLowerCase()) ||
                   email.contains(_searchQuery.toLowerCase());
          }).toList();
        }
        
        // Sort by creation date (newest first)
        filteredTenants.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        // Check if no tenants match the filters
        if (filteredTenants.isEmpty) {
          return _buildNoResultsView();
        }

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
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList.builder(
                          itemCount: filteredTenants.length,
                          itemBuilder: (context, index) {
                            Tenant tenant = filteredTenants[index];
                            List<UnitTenancy> tenantTenancies = state.unitTenancies
                                .where((ut) => ut.tenantId == tenant.id)
                                .toList();
                            List<Unit> tenantUnits = tenantTenancies
                                .map((ut) => state.units
                                    .firstWhere((unit) => unit.id == ut.unitId))
                                .toList();
                            return TenantCard(
                              tenant: tenant,
                              units: tenantUnits,
                              tenancies: tenantTenancies,
                            );
                          },
                        ),
                      ),
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
            onPressed: () => _showAddTenantPrompt(context),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            icon: const Icon(Icons.person_add),
            label: const Text('Add Tenant'),
            tooltip: 'Add a new tenant',
          ),
        );
      }
      return const NoTenantsScreen();
    });
  }
  
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tenants by name, phone, or email',
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
                _buildFilterChip(context, 'Active', 'active'),
                _buildFilterChip(context, 'Inactive', 'inactive'),
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
            'No tenants match your filters',
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
  
  void _showAddTenantPrompt(BuildContext context) {
    // This would navigate to your add tenant page
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Add tenant functionality coming soon'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class TenantCard extends StatelessWidget {
  final Tenant tenant;
  final List<Unit> units;
  final List<UnitTenancy> tenancies;

  const TenantCard({
    required this.tenant,
    required this.units,
    required this.tenancies,
    super.key,
  });

  String _formatDate(String date) {
    final parsedDate = DateTime.parse(date);
    return DateFormat('MMM dd, yyyy').format(parsedDate);
  }

  String _getActiveUnits() {
    return units
        .where((unit) => tenancies
            .any((tenancy) => tenancy.unitId == unit.id && tenancy.status.toLowerCase() == 'active'))
        .map((unit) => unit.unitNumber)
        .join(", ");
  }

  double _calculateTotalRent() {
    double total = 0;
    for (var tenancy in tenancies.where((t) => t.status.toLowerCase() == 'active')) {
      total += tenancy.monthlyRent;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveTenancy = tenancies.any((t) => t.status.toLowerCase() == 'active');
    final totalMonthlyRent = _calculateTotalRent();
    final activeUnits = _getActiveUnits();
    final activeUnitCount = activeUnits.isEmpty ? 0 : activeUnits.split(',').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 3,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: BlocProvider.of<HomeBloc>(context),
                child: TenantDetailsPage(
                  tenant: tenant,
                  units: units,
                  tenancies: tenancies,
                ),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasActiveTenancy
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Theme.of(context).colorScheme.error.withOpacity(0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: hasActiveTenancy 
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      : Theme.of(context).colorScheme.error.withOpacity(0.2),
                    child: Text(
                      '${tenant.firstName[0]}${tenant.lastName[0]}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: hasActiveTenancy 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${tenant.firstName} ${tenant.lastName}",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tenant.phone,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        if (tenant.email != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  tenant.email!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: hasActiveTenancy 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      hasActiveTenancy ? 'ACTIVE' : 'INACTIVE',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    context, 
                    Icons.home_work_rounded, 
                    'Units', 
                    '$activeUnitCount ${activeUnitCount == 1 ? "unit" : "units"}: $activeUnits', 
                    hasActiveTenancy
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context, 
                    Icons.payments_outlined, 
                    'Monthly Rent', 
                    'Ksh ${NumberFormat.currency(symbol: '').format(totalMonthlyRent)}',
                    hasActiveTenancy
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context, 
                    Icons.calendar_month_outlined, 
                    'Since', 
                    _formatDate(tenancies.first.startDate.toString()),
                    hasActiveTenancy
                  ),
                ],
              ),
            ),
            if (hasActiveTenancy)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tap for details',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value, bool isActive) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isActive 
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class NoTenantsScreen extends StatelessWidget {
  const NoTenantsScreen({super.key});

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
                  Icons.people_outline,
                  size: 120,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'No Tenants Yet',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Add your first tenant to get started\nwith managing your property efficiently',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Tenant'),
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
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
