import 'package:bomatrack/features/home/presentation/bloc/bloc.dart';
import 'package:bomatrack/features/home/presentation/screens/tenant_details/tenant_details_page.dart';
import 'package:bomatrack/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:bomatrack/core/theme/theme.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  bool _isSearching = false;
  bool _showFilters = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (BuildContext context, HomeState state) {
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
          bool isTenancyActive(UnitTenancy ut) {
            return ut.status.toLowerCase() == 'active' && (ut.endDate == null || ut.endDate!.isAfter(DateTime.now()));
          }
          
          // Apply search filter to all payment lists
          final filter = _searchQuery.toLowerCase();
          
          // For pending payments - ONLY show for active tenancies
          final allPendingPayments = state.payments.where((p) {
            try {
              final ut = state.unitTenancies.firstWhere((ut) => ut.id == p.unitTenancyId);
              // Only include if status is pending AND tenancy is still active
              return p.paymentStatus == 'pending' && isTenancyActive(ut);
            } catch (e) {
              return false;
            }
          }).toList();

          // Filter pending payments
          final pendingPayments = _searchQuery.isEmpty ? allPendingPayments : allPendingPayments.where((p) {
            // Try to find the tenant for this payment
            try {
              final ut = state.unitTenancies.firstWhere((ut) => ut.id == p.unitTenancyId);
              final tenant = state.tenants.firstWhere((t) => t.id == ut.tenantId);
              final unit = state.units.firstWhere((u) => u.id == ut.unitId);
              
              // Search by tenant name, unit number, amount, or date
              final tenantName = '${tenant.firstName} ${tenant.lastName}'.toLowerCase();
              final unitNumber = unit.unitNumber.toString();
              final amount = p.amount.toString();
              final dueDate = DateFormat('yyyy-MM-dd').format(p.dueDate);
              
              return tenantName.contains(filter) || 
                     unitNumber.contains(filter) || 
                     amount.contains(filter) || 
                     dueDate.contains(filter);
            } catch (_) {
              return false;
            }
          }).toList();

          // For paid payments - Include ALL payments with status 'paid' or 'partial'
          final allPaidPayments = state.payments
              .where((p) => p.paymentStatus == 'paid' || p.paymentStatus == 'partial')
              .toList();
                
          // Sort paid payments with most recent first
          allPaidPayments.sort((a, b) {
            final aDate = a.paymentDate ?? a.dueDate;
            final bDate = b.paymentDate ?? b.dueDate;
            return bDate.compareTo(aDate); // Sort descending (newest first)
          });
          
          // Filter paid payments
          final paidPayments = _searchQuery.isEmpty ? allPaidPayments : allPaidPayments.where((p) {
            // Try to find the tenant for this payment
            try {
              final ut = state.unitTenancies.firstWhere((ut) => ut.id == p.unitTenancyId);
              final tenant = state.tenants.firstWhere((t) => t.id == ut.tenantId);
              final unit = state.units.firstWhere((u) => u.id == ut.unitId);
              
              // Search by tenant name, unit number, amount, or date
              final tenantName = '${tenant.firstName} ${tenant.lastName}'.toLowerCase();
              final unitNumber = unit.unitNumber.toString();
              final amount = p.amount.toString();
              final paymentDate = p.paymentDate != null 
                  ? DateFormat('yyyy-MM-dd').format(p.paymentDate!) 
                  : DateFormat('yyyy-MM-dd').format(p.dueDate);
              final method = (p.paymentMethod ?? '').toLowerCase();
              final reference = (p.referenceNumber ?? '').toLowerCase();
              
              return tenantName.contains(filter) || 
                     unitNumber.contains(filter) || 
                     amount.contains(filter) || 
                     paymentDate.contains(filter) ||
                     method.contains(filter) ||
                     reference.contains(filter);
            } catch (_) {
              // For payments without tenant info, search by basic properties
              final amount = p.amount.toString();
              final paymentDate = p.paymentDate != null 
                  ? DateFormat('yyyy-MM-dd').format(p.paymentDate!) 
                  : DateFormat('yyyy-MM-dd').format(p.dueDate);
              final method = (p.paymentMethod ?? '').toLowerCase();
              final reference = (p.referenceNumber ?? '').toLowerCase();
              final description = (p.description ?? '').toLowerCase();
              
              return amount.contains(filter) || 
                     paymentDate.contains(filter) ||
                     method.contains(filter) ||
                     reference.contains(filter) ||
                     description.contains(filter);
            }
          }).toList();

          // For overdue payments - ONLY show for active tenancies
          final allOverduePayments = state.payments.where((p) {
            try {
              final ut = state.unitTenancies.firstWhere((ut) => ut.id == p.unitTenancyId);
              // Only include if status is overdue AND tenancy is still active
              return p.paymentStatus == 'overdue' && isTenancyActive(ut);
            } catch (e) {
              return false;
            }
          }).toList();
          
          // Filter overdue payments
          final overduePayments = _searchQuery.isEmpty ? allOverduePayments : allOverduePayments.where((p) {
            // Try to find the tenant for this payment
            try {
              final ut = state.unitTenancies.firstWhere((ut) => ut.id == p.unitTenancyId);
              final tenant = state.tenants.firstWhere((t) => t.id == ut.tenantId);
              final unit = state.units.firstWhere((u) => u.id == ut.unitId);
              
              // Search by tenant name, unit number, amount, or date
              final tenantName = '${tenant.firstName} ${tenant.lastName}'.toLowerCase();
              final unitNumber = unit.unitNumber.toString();
              final amount = p.amount.toString();
              final dueDate = DateFormat('yyyy-MM-dd').format(p.dueDate);
              final daysOverdue = DateTime.now().difference(p.dueDate).inDays.toString();
              
              return tenantName.contains(filter) || 
                     unitNumber.contains(filter) || 
                     amount.contains(filter) || 
                     dueDate.contains(filter) ||
                     daysOverdue.contains(filter);
            } catch (_) {
              return false;
            }
          }).toList();

          // Calculate summary statistics
          final pendingTotal = _calculateTotal(pendingPayments);
          final paidTotal = _calculateTotal(paidPayments);
          final overdueTotal = _calculateTotal(overduePayments);

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search payments...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.filter_list),
                            onPressed: () {
                              setState(() {
                                _showFilters = !_showFilters;
                              });
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              
              // Animated filter section
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _showFilters ? 90 : 0,
                child: _showFilters ? _buildFilterSection() : const SizedBox.shrink(),
              ),
              
              // Tab bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: Theme.of(context).colorScheme.surface,
                      border: Border.all(
                        width: 2,
                        color: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      splashBorderRadius: BorderRadius.circular(10),
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: Theme.of(context).colorScheme.onSecondaryContainer,
                      unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                      tabs: const [
                        Tab(text: 'Pending'),
                        Tab(text: 'Paid'),
                        Tab(text: 'Overdue'),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Add payment summary cards
              _buildPaymentSummaryCards(pendingTotal, paidTotal, overdueTotal),
              
              // Tab view with lists
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        context.read<HomeBloc>().add(LoadHome());
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Show count and filtered indicators
                          _buildResultsHeader(
                            context,
                            allPendingPayments.length,
                            pendingPayments.length,
                            "pending"
                          ),
                          PaymentList(payments: pendingPayments),
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: () async {
                        context.read<HomeBloc>().add(LoadHome());
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Show count and filtered indicators
                          _buildResultsHeader(
                            context,
                            allPaidPayments.length,
                            paidPayments.length,
                            "paid"
                          ),
                          PaymentList(payments: paidPayments, groupByField: 'paymentDate'),
                        ],
                      ),
                    ),
                    RefreshIndicator(
                      onRefresh: () async {
                        context.read<HomeBloc>().add(LoadHome());
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Show count and filtered indicators
                          _buildResultsHeader(
                            context, 
                            allOverduePayments.length, 
                            overduePayments.length,
                            "overdue"
                          ),
                          PaymentList(payments: overduePayments),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return const Center(child: Text('Something went wrong'));
      },
    );
  }
  
  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter options coming soon',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('This Month', true, () {}),
                _buildFilterChip('By Tenant', false, () {}),
                _buildFilterChip('By Unit', false, () {}),
                _buildFilterChip('By Date Range', false, () {}),
                _buildFilterChip('High to Low', false, () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (value) => onTap(),
        backgroundColor: Colors.white.withOpacity(0.15),
        selectedColor: Theme.of(context).colorScheme.secondaryContainer,
        labelStyle: TextStyle(
          color: selected ? Theme.of(context).colorScheme.onSecondaryContainer : Colors.white,
        ),
      ),
    );
  }
  
  int _calculateTotal(List<Payment> payments) {
    if (payments.isEmpty) return 0;
    return payments.fold(0, (sum, payment) => (sum + payment.amount).toInt());
  }
  
  Widget _buildPaymentSummaryCards(int pendingTotal, int paidTotal, int overdueTotal) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildSummaryCard(
            context,
            'Pending',
            pendingTotal,
            Colors.orange.shade200,
            Colors.orange.shade800,
            Icons.access_time,
          ),
          _buildSummaryCard(
            context,
            'Paid',
            paidTotal,
            Colors.green.shade200,
            Colors.green.shade800,
            Icons.check_circle,
          ),
          _buildSummaryCard(
            context,
            'Overdue',
            overdueTotal,
            Colors.red.shade200,
            Colors.red.shade800,
            Icons.warning,
          ),
          _buildSummaryCard(
            context,
            'Total',
            pendingTotal + paidTotal + overdueTotal,
            Theme.of(context).colorScheme.secondaryContainer,
            Theme.of(context).colorScheme.onSecondaryContainer,
            Icons.attach_money,
          ),
        ],
      ),
    );
  }
  
  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    int amount,
    Color bgColor,
    Color textColor,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(right: 12),
      color: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14, 
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(icon, size: 18, color: textColor),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                NumberFormat.currency(symbol: 'Ksh ').format(amount),
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultsHeader(
    BuildContext context, 
    int totalCount, 
    int filteredCount,
    String paymentType,
  ) {
    final isFiltered = _searchQuery.isNotEmpty;
    
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      sliver: SliverToBoxAdapter(
        child: Row(
          children: [
            Text(
              isFiltered 
                ? '$filteredCount of $totalCount results' 
                : '$totalCount $paymentType payments',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const Spacer(),
            if (isFiltered)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _isSearching = false;
                  });
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PaymentList extends StatefulWidget {
  final List<Payment> payments;
  final String? groupByField;  // Add this parameter to specify which field to group by

  const PaymentList({
    super.key, 
    required this.payments,
    this.groupByField,  // Optional parameter with null as default
  });

  @override
  State<PaymentList> createState() => _PaymentListState();
}

class _PaymentListState extends State<PaymentList> with AutomaticKeepAliveClientMixin {
  static const int _pageSize = 40;  // Changed from 20 to 40
  int _currentPage = 0;
  final ScrollController _scrollController = ScrollController();
  bool _loadingMore = false;
  bool _reachedEnd = false;  // Flag to track when we've reached the end of the list

  @override
  void initState() {
    super.initState();
    // We'll use NotificationListener instead of ScrollController.addListener 
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadMoreItems() {
    // Check if we have more pages before attempting to load
    if (!_loadingMore && _hasMorePages) {
      setState(() {
        _loadingMore = true;
      });
      
      // Add a small delay to simulate loading
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // Check if we've reached the end of the list
          final nextStartIndex = (_currentPage + 1) * _pageSize;
          
          if (nextStartIndex >= widget.payments.length) {
            // We've reached the end, no more data to load
            setState(() {
              _loadingMore = false;
              // Set a flag to indicate we've reached the end
              _reachedEnd = true;
            });
          } else {
            setState(() {
              _currentPage++;
              _loadingMore = false;
            });
          }
        }
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  List<Payment> get _paginatedPayments {
    if (widget.payments.isEmpty) return [];
    
    final startIndex = _currentPage * _pageSize;
    if (startIndex >= widget.payments.length) {
      return [];
    }
    
    final endIndex = (startIndex + _pageSize).clamp(0, widget.payments.length);
    return widget.payments.sublist(startIndex, endIndex);
  }

  bool get _hasMorePages {
    return (_currentPage + 1) * _pageSize < widget.payments.length;
  }

  Map<String, List<Payment>> _groupPaymentsByDate(List<Payment> payments) {
    return groupBy(payments, (Payment p) {
      // For paid section, we want to group by:
      // - paymentDate for payments with status 'paid'
      // - dueDate for payments with status 'partial' (since they might not have paymentDate)
      DateTime dateToUse;
      
      if (widget.groupByField == 'paymentDate') {
        if (p.paymentStatus == 'paid' && p.paymentDate != null) {
          dateToUse = p.paymentDate!;
        } else {
          dateToUse = p.dueDate;
        }
      } else {
        dateToUse = p.dueDate;
      }
      
      // Use format 'yyyy-MM' for consistent sorting
      return '${dateToUse.year}-${dateToUse.month.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.payments.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No payments to display',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final paginatedPayments = _paginatedPayments;
    final groupedPayments = _groupPaymentsByDate(paginatedPayments);
    final dateGroups = groupedPayments.keys.toList()..sort((a, b) => b.compareTo(a));

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == dateGroups.length) {
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            } else if (_reachedEnd) {
              // Show end of list indicator
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'End of list',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            } else if (_hasMorePages) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: TextButton(
                    onPressed: _loadMoreItems,
                    child: Text('Load more'),
                  ),
                ),
              );
            }
            return null;
          }

          if (index >= dateGroups.length) return null;

          final dateGroup = dateGroups[index];
          final paymentsInGroup = groupedPayments[dateGroup]!;
          
          // Sort payments within each group (most recent first)
          paymentsInGroup.sort((a, b) {
            final aDate = widget.groupByField == 'paymentDate' && a.paymentDate != null
                ? a.paymentDate!
                : a.dueDate;
            final bDate = widget.groupByField == 'paymentDate' && b.paymentDate != null
                ? b.paymentDate!
                : b.dueDate;
            return bDate.compareTo(aDate);
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  _formatMonthYear(dateGroup),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              // If this is the "paid" section, show dates more prominently
              if (widget.groupByField == 'paymentDate') 
                ...paymentsInGroup.map((payment) {
                  // Group payments by exact date
                  final paymentDate = payment.paymentDate != null
                      ? DateFormat('EEEE, MMMM dd, yyyy').format(payment.paymentDate!)
                      : DateFormat('EEEE, MMMM dd, yyyy').format(payment.dueDate);
                      
                  final state = context.read<HomeBloc>().state;
                  if (state is HomeLoaded) {
                    try {
                      // Find the tenancy related to this payment
                      final unitTenancy = state.unitTenancies.firstWhere(
                        (ut) => ut.id == payment.unitTenancyId,
                        orElse: () => null as UnitTenancy, // Will throw if not found
                      );
                      
                      // Find the tenant using the tenancy, even if the tenancy is no longer active
                      final tenant = state.tenants.firstWhere(
                        (e) => e.id == unitTenancy.tenantId,
                        orElse: () => null as Tenant, // Will throw if not found
                      );
                      
                      // Find the unit for this tenancy
                      final unit = state.units.firstWhere(
                        (e) => e.id == unitTenancy.unitId,
                        orElse: () => null as Unit, // Will throw if not found
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index > 0 && 
                              _getPaymentDateStr(paymentsInGroup[index-1]) != _getPaymentDateStr(payment))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Text(
                                paymentDate,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          if (index == 0)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                              child: Text(
                                paymentDate,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          PaymentListItem(
                            key: ValueKey(payment.id),
                            payment: payment,
                            tenant: tenant,
                            unit: unit,
                          ),
                        ],
                      );
                    } catch (e) {
                      // For payments without valid tenancy data, create a fallback display
                      if (payment.paymentStatus == 'paid' || payment.paymentStatus == 'partial') {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (index > 0 && 
                                _getPaymentDateStr(paymentsInGroup[index-1]) != _getPaymentDateStr(payment))
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                child: Text(
                                  paymentDate,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            if (index == 0)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                child: Text(
                                  paymentDate,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).colorScheme.secondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            FallbackPaymentListItem(payment: payment),
                          ],
                        );
                      }
                      // For other payment types, skip
                      return const SizedBox.shrink();
                    }
                  }
                  return const SizedBox.shrink();
                }).toList()
              else
                ...paymentsInGroup.map((payment) {
                  final state = context.read<HomeBloc>().state;
                  if (state is HomeLoaded) {
                    try {
                      // Find the tenancy related to this payment
                      final unitTenancy = state.unitTenancies.firstWhere(
                        (ut) => ut.id == payment.unitTenancyId,
                        orElse: () => null as UnitTenancy, // Will throw if not found
                      );
                      
                      // Find the tenant using the tenancy
                      final tenant = state.tenants.firstWhere(
                        (e) => e.id == unitTenancy.tenantId,
                        orElse: () => null as Tenant, // Will throw if not found
                      );
                      
                      // Find the unit for this tenancy
                      final unit = state.units.firstWhere(
                        (e) => e.id == unitTenancy.unitId,
                        orElse: () => null as Unit, // Will throw if not found
                      );

                      return PaymentListItem(
                        key: ValueKey(payment.id),
                        payment: payment,
                        tenant: tenant,
                        unit: unit,
                      );
                    } catch (e) {
                      // For payments without valid tenancy data, create a fallback display
                      if (payment.paymentStatus == 'paid' || payment.paymentStatus == 'partial') {
                        return FallbackPaymentListItem(payment: payment);
                      }
                      // For other payment types, skip
                      return const SizedBox.shrink();
                    }
                  }
                  return const SizedBox.shrink();
                }).toList(),
            ],
          );
        },
        childCount: dateGroups.length + (_hasMorePages ? 1 : 0),
      ),
    );
  }

  // Helper function to get standardized payment date string
  String _getPaymentDateStr(Payment payment) {
    final date = payment.paymentDate ?? payment.dueDate;
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatMonthYear(String dateGroup) {
    try {
      final parts = dateGroup.split('-');
      if (parts.length < 2) return dateGroup;
      
      final year = parts[0];
      final month = int.parse(parts[1]);
      
      return '${_getMonth(month)} $year';
    } catch (e) {
      return dateGroup; // Return the original string if parsing fails
    }
  }

  String _getMonth(int month) {
    switch (month) {
      case 1: return 'January';
      case 2: return 'February';
      case 3: return 'March';
      case 4: return 'April';
      case 5: return 'May';
      case 6: return 'June';
      case 7: return 'July';
      case 8: return 'August';
      case 9: return 'September';
      case 10: return 'October';
      case 11: return 'November';
      case 12: return 'December';
      default: return '';
    }
  }
}

class PaymentListItem extends StatelessWidget {
  final Payment payment;
  final Tenant tenant;
  final Unit unit;

  const PaymentListItem({
    super.key,
    required this.payment,
    required this.tenant,
    required this.unit,
  });

  String _getStatusText(String status, DateTime dueDate) {
    switch (status) {
      case 'pending':
        return 'Due: ${_formatDate(dueDate)}';
      case 'paid':
        return 'Paid';
      case 'partial':
        return 'Partial';
      case 'overdue':
        final days = _getDaysOverdue(dueDate);
        return 'Overdue: $days days';
      default:
        return '';
    }
  }

  Color _getStatusColor(String status, BuildContext context) {
    switch (status) {
      case 'pending':
        return Theme.of(context).colorScheme.tertiary;
      case 'paid':
        return Theme.of(context).colorScheme.primary;
      case 'partial':
        return Theme.of(context).colorScheme.secondary;
      case 'overdue':
        return Theme.of(context).colorScheme.error;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Color _getPartialPaymentColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _getStatusText(payment.paymentStatus!, payment.dueDate);
    final statusColor = _getStatusColor(payment.paymentStatus!, context);
    final isPartial = payment.paymentStatus == 'partial';
    final partialPaymentColor = _getPartialPaymentColor(context);
    final hasMultipleUnits = payment.description?.contains('Units:') ?? false;
    final tenantName = '${tenant.firstName} ${tenant.lastName}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: isPartial ? 1 : 2,
      color: isPartial ? partialPaymentColor : Theme.of(context).colorScheme.surface,
      child: ListTile(
        onTap: () {
          // Get the current HomeBloc instance from the context
          final homeBloc = BlocProvider.of<HomeBloc>(context);
          
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) => BlocProvider.value(
              value: homeBloc, // Pass the HomeBloc to the bottom sheet
              child: DraggableScrollableSheet(
                initialChildSize: 0.5,
                minChildSize: 0.25,
                maxChildSize: 0.95,
                expand: false,
                builder: (_, scrollController) => PaymentDetailsSheet(
                  payments: [payment],
                  tenantName: tenantName,
                  unitNumbers: hasMultipleUnits ? payment.description!.replaceAll('Units: ', '') : unit.unitNumber.toString(),
                  scrollController: scrollController,
                ),
              ),
            ),
          );
        },
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: statusColor.withOpacity(0.2),
          child: Builder(
            builder: (context) {
              final names = tenantName
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((s) => s.isNotEmpty)
                  .toList();
              final initials = names.isNotEmpty
                  ? names.take(2).map((s) => s[0]).join()
                  : '??';
              return Text(
                initials,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              );
            },
          ),
        ),
        title: Text(
          tenantName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasMultipleUnits ? payment.description! : "Unit: ${unit.unitNumber}",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              NumberFormat.currency(symbol: 'Ksh').format(payment.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              payment.paymentDate != null
                  ? DateFormat('MMM dd, yyyy').format(payment.paymentDate!)
                  : DateFormat('MMM dd, yyyy').format(payment.dueDate),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  int _getDaysOverdue(DateTime dueDate) {
    final today = DateTime.now();
    return today.difference(dueDate).inDays;
  }
}

class PaymentDetailsSheet extends StatelessWidget {
  final List<Payment> payments;
  final String tenantName;
  final String unitNumbers;
  final ScrollController scrollController;

  const PaymentDetailsSheet({
    super.key,
    required this.payments,
    required this.tenantName,
    required this.unitNumbers,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final totalAmount = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final payment = payments.first;
    final isSecurityDeposit = payment.description?.toLowerCase().contains('deposit') ?? false;
    final status = payment.paymentStatus ?? 'pending';
    
    // Determine colors based on payment status
    final Color statusColor;
    final IconData statusIcon;
    
    switch (status) {
      case 'paid':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'partial':
        statusColor = Colors.amber;
        statusIcon = Icons.hourglass_bottom;
        break;
      case 'overdue':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      default: // pending
        statusColor = Colors.orange;
        statusIcon = isSecurityDeposit ? Icons.security : Icons.access_time;
    }

    return Column(
      children: [
        // Handle that can be dragged to expand/collapse
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
        
        // Payment header with amount and status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor.withOpacity(0.7),
                statusColor.withOpacity(0.4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withOpacity(0.8),
                    child: Icon(
                      statusIcon,
                      color: statusColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          NumberFormat.currency(symbol: 'Ksh ').format(payment.amount),
                          style: const TextStyle(
                            fontSize: 24, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          isSecurityDeposit ? 'Security Deposit' : 'Monthly Rent',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tenantName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      // Get the tenant and unit information from the HomeBloc
                      final homeState = context.read<HomeBloc>().state;
                      if (homeState is HomeLoaded) {
                        try {
                          // Get the tenant, units, and tenancies for this payment
                          final payment = payments.first;
                          final unitTenancy = homeState.unitTenancies
                              .firstWhere((ut) => ut.id == payment.unitTenancyId);
                          final tenant = homeState.tenants
                              .firstWhere((t) => t.id == unitTenancy.tenantId);
                          
                          // Get all tenancies for this tenant (both active and inactive)
                          final tenantTenancies = homeState.unitTenancies
                              .where((ut) => ut.tenantId == tenant.id)
                              .toList();
                              
                          // Get all units related to these tenancies
                          final tenantUnits = tenantTenancies
                              .map((ut) => homeState.units
                                  .firstWhere((u) => u.id == ut.unitId))
                              .toList();
                          
                          // Navigate to tenant details page
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: BlocProvider.of<HomeBloc>(context),
                                child: TenantDetailsPage(
                                  tenant: tenant,
                                  units: tenantUnits,
                                  tenancies: tenantTenancies,
                                ),
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not find tenant details')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 16, color: Colors.white),
                    label: const Text('View Tenant', style: TextStyle(color: Colors.white)),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.black12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.home_work,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Unit(s): $unitNumbers',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Payment information
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            children: [
              // Payment dates section
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Important Dates',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      _buildTimelineItem(
                        context,
                        title: 'Created',
                        date: payment.createdAt ?? payment.dueDate,
                        isDone: true,
                        isFirst: true,
                        icon: Icons.create,
                        color: Colors.blue,
                      ),
                      _buildTimelineItem(
                        context,
                        title: 'Due Date',
                        date: payment.dueDate,
                        isDone: payment.paymentDate != null || payment.paymentStatus == 'paid',
                        isFirst: false,
                        icon: Icons.event,
                        color: payment.paymentStatus == 'overdue' ? Colors.red : Colors.orange,
                      ),
                      if (payment.paymentDate != null)
                        _buildTimelineItem(
                          context,
                          title: 'Payment Date',
                          date: payment.paymentDate!,
                          isDone: true,
                          isFirst: false,
                          isLast: true,
                          icon: Icons.payment,
                          color: Colors.green,
                        ),
                    ],
                  ),
                ),
              ),
              
              // Payment details card
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      _buildDetailTile(
                        context, 
                        Icons.tag, 
                        'Payment ID', 
                        '#${payment.id}'
                      ),
                      _buildDetailTile(
                        context, 
                        Icons.monetization_on, 
                        'Amount', 
                        NumberFormat.currency(symbol: 'Ksh ').format(payment.amount)
                      ),
                      if (payment.paymentMethod != null)
                        _buildDetailTile(
                          context,
                          Icons.credit_card,
                          'Payment Method',
                          payment.paymentMethod!.toUpperCase()
                        ),
                      if (payment.referenceNumber != null)
                        _buildDetailTile(
                          context,
                          Icons.receipt,
                          'Reference Number',
                          payment.referenceNumber!
                        ),
                      if (payment.description != null && payment.description!.isNotEmpty)
                        _buildDetailTile(
                          context,
                          Icons.description,
                          'Description',
                          payment.description!
                        ),
                    ],
                  ),
                ),
              ),
              
              // No actions for now, but could add buttons for:
              // - Mark as paid
              // - Delete payment
              // - Print receipt
              // etc.
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    BuildContext context, {
    required String title,
    required DateTime date,
    required bool isDone,
    required bool isFirst,
    bool isLast = false,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          margin: const EdgeInsets.only(right: 16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDone ? color : Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDone ? Colors.white : Colors.grey,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 30,
                  color: isDone ? color : Colors.grey.shade300,
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDone ? color : Colors.grey,
                ),
              ),
              Text(
                DateFormat('MMMM dd, yyyy').format(date),
                style: TextStyle(
                  color: isDone ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailTile(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

class FallbackPaymentListItem extends StatelessWidget {
  final Payment payment;

  const FallbackPaymentListItem({
    super.key,
    required this.payment,
  });

  String _getStatusText(String status) {
    switch (status) {
      case 'partial':
        return 'Partial';
      case 'paid':
      default:
        return 'Paid';
    }
  }

  Color _getStatusColor(String status, BuildContext context) {
    switch (status) {
      case 'partial':
        return Theme.of(context).colorScheme.secondary;
      case 'paid':
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  Color _getPartialPaymentColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondaryContainer;
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _getStatusText(payment.paymentStatus!);
    final statusColor = _getStatusColor(payment.paymentStatus!, context);
    final isPartial = payment.paymentStatus == 'partial';
    final partialPaymentColor = _getPartialPaymentColor(context);
    
    // Extract unit information from description if available
    String unitInfo = 'Unit: Unknown';
    if (payment.description != null) {
      if (payment.description!.contains('Units:')) {
        unitInfo = "Units: ${payment.description!.replaceAll('Units: ', '')}";
      } else {
        unitInfo = payment.description!;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: isPartial ? 1 : 2,
      color: isPartial ? partialPaymentColor : Theme.of(context).colorScheme.surface,
      child: ListTile(
        onTap: () {
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
                  _buildDetailRow('Payment ID', '#${payment.id}'),
                  _buildDetailRow('Amount', 'Ksh ${payment.amount}'),
                  _buildDetailRow('Type', payment.description ?? 'Monthly Rent'),
                  _buildDetailRow('Status', payment.paymentStatus?.toUpperCase() ?? 'N/A'),
                  _buildDetailRow('Due Date', DateFormat('MMM dd, yyyy').format(payment.dueDate)),
                  if (payment.paymentDate != null)
                    _buildDetailRow('Payment Date', DateFormat('MMM dd, yyyy').format(payment.paymentDate!)),
                  if (payment.paymentMethod != null)
                    _buildDetailRow('Method', payment.paymentMethod!.toUpperCase()),
                ],
              ),
            ),
          );
        },
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(
            isPartial ? Icons.monetization_on_outlined : Icons.check_circle_outline,
            color: statusColor,
          ),
        ),
        title: Text(
          'Payment #${payment.id}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              unitInfo,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              NumberFormat.currency(symbol: 'Ksh').format(payment.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              payment.paymentDate != null
                  ? DateFormat('MMM dd, yyyy').format(payment.paymentDate!)
                  : DateFormat('MMM dd, yyyy').format(payment.dueDate),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
}
