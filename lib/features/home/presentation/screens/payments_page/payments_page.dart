import 'package:bomatrack/features/home/presentation/bloc/bloc.dart';
import 'package:bomatrack/features/home/presentation/screens/tenant_details/tenant_details_page.dart';
import 'package:bomatrack/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:bomatrack/core/theme/theme.dart';

class PaymentsPage extends StatelessWidget {
  const PaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          toolbarHeight: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              child: Container(
                height: 40,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    width: 2,
                    color: Theme.of(context).colorScheme.surface,
                  ),
                ),
                child: TabBar(
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
        ),
        body: BlocBuilder<HomeBloc, HomeState>(
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

              // For pending payments - ONLY show for active tenancies
              final pendingPayments = state.payments.where((p) {
                try {
                  final ut = state.unitTenancies.firstWhere((ut) => ut.id == p.unitTenancyId);
                  // Only include if status is pending AND tenancy is still active
                  return p.paymentStatus == 'pending' && isTenancyActive(ut);
                } catch (e) {
                  return false;
                }
              }).toList();

              // For paid payments - Include ALL payments with status 'paid' or 'partial'
              // Don't filter based on unit tenancy for paid payments to ensure all records show
              final paidPayments = state.payments
                  .where((p) => p.paymentStatus == 'paid' || p.paymentStatus == 'partial')
                  .toList();
                  
              // Sort paid payments with most recent first
              paidPayments.sort((a, b) {
                final aDate = a.paymentDate ?? a.dueDate;
                final bDate = b.paymentDate ?? b.dueDate;
                return bDate.compareTo(aDate); // Sort descending (newest first)
              });

              // For overdue payments - ONLY show for active tenancies
              final overduePayments = state.payments.where((p) {
                try {
                  final ut = state.unitTenancies.firstWhere((ut) => ut.id == p.unitTenancyId);
                  // Only include if status is overdue AND tenancy is still active
                  return p.paymentStatus == 'overdue' && isTenancyActive(ut);
                } catch (e) {
                  return false;
                }
              }).toList();

              // A payment would not be shown in pendingPayments if:
              // 1. It doesn't have status 'pending'
              // 2. The associated tenancy is not active (status != 'active' or endDate is in the past)
              // 3. There's no matching unitTenancy found (throws exception in try-catch)
              
              // A payment would not be shown in paidPayments if:
              // 1. Its status is not 'paid' or 'partial'
              // 2. There's no matching unitTenancy in state.unitTenancies
              // Note: .any() returns false if no matching tenancy is found instead of throwing an exception

              // A payment would not be shown in overduePayments if:
              // 1. It doesn't have status 'overdue'
              // 2. The associated tenancy is not active (status != 'active' or endDate is in the past)
              // 3. There's no matching unitTenancy found (throws exception in try-catch)
              
              // A payment might also not be displayed in a PaymentList widget if:
              // 1. The PaymentList can't find the associated tenant or unit (fails in try-catch block)
              // 2. The payment is beyond the current pagination limits

              return TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      context.read<HomeBloc>().add(LoadHome());
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        // Check for scroll updates as we get closer to the bottom
                        if (notification is ScrollUpdateNotification) {
                          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 300) {
                            // Directly access the PaymentList's State
                            final PaymentList? paymentList = notification.context?.findAncestorWidgetOfExactType<PaymentList>();
                            if (paymentList != null) {
                              // Find the state using the widget
                              final state = context.findAncestorStateOfType<_PaymentListState>();
                              state?._loadMoreItems();
                            }
                          }
                        }
                        return false;
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          PaymentList(payments: pendingPayments),
                        ],
                      ),
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: () async {
                      context.read<HomeBloc>().add(LoadHome());
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        // Check for scroll updates as we get closer to the bottom
                        if (notification is ScrollUpdateNotification) {
                          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 300) {
                            // Directly access the PaymentList's State
                            final PaymentList? paymentList = notification.context?.findAncestorWidgetOfExactType<PaymentList>();
                            if (paymentList != null) {
                              // Find the state using the widget
                              final state = context.findAncestorStateOfType<_PaymentListState>();
                              state?._loadMoreItems();
                            }
                          }
                        }
                        return false;
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          PaymentList(payments: paidPayments, groupByField: 'paymentDate'),
                        ],
                      ),
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: () async {
                      context.read<HomeBloc>().add(LoadHome());
                    },
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        // Check for scroll updates as we get closer to the bottom
                        if (notification is ScrollUpdateNotification) {
                          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 300) {
                            // Directly access the PaymentList's State
                            final PaymentList? paymentList = notification.context?.findAncestorWidgetOfExactType<PaymentList>();
                            if (paymentList != null) {
                              // Find the state using the widget
                              final state = context.findAncestorStateOfType<_PaymentListState>();
                              state?._loadMoreItems();
                            }
                          }
                        }
                        return false;
                      },
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          PaymentList(payments: overduePayments),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }
            return const Center(child: Text('Something went wrong'));
          },
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
      final date = widget.groupByField == 'paymentDate' 
          ? (p.paymentStatus == 'paid' && p.paymentDate != null ? p.paymentDate! : p.dueDate)
          : p.dueDate;
      
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
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
              ...paymentsInGroup.map((payment) {
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

  String _formatMonthYear(String dateGroup) {
    final parts = dateGroup.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    return '${_getMonth(month)} $year';
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

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tenantName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('View Tenant'),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
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
                  Icon(
                    Icons.home_work,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text('Unit(s): $unitNumbers'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Payment ID', '#${payment.id}'),
                      _buildDetailRow('Amount', 'Ksh ${payment.amount}'),
                      _buildDetailRow('Type', payment.description ?? 'Monthly Rent'),
                      _buildDetailRow('Status', payment.paymentStatus?.toUpperCase() ?? 'N/A'),
                      _buildDetailRow('Due Date', _formatDate(payment.dueDate)),
                      if (payment.paymentDate != null)
                        _buildDetailRow('Payment Date', _formatDate(payment.paymentDate!)),
                      if (payment.paymentMethod != null)
                        _buildDetailRow('Method', payment.paymentMethod!.toUpperCase()),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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

  String _formatDate(DateTime date) {
    return DateFormat('MMMM dd, yyyy').format(date);
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
