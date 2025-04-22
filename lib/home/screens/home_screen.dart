import 'package:bomatrack/app/app.dart';
import 'package:bomatrack/home/bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:animations/animations.dart';
import 'package:bomatrack/config/config.dart';
import 'package:bomatrack/home/screens/screens.dart';
import 'package:bomatrack/services/services.dart';
import 'package:bomatrack/shared/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'drawer/drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen(
      {super.key,
      required PropertyRepository propertyRepository,
      required AuthRepository authRepository})
      : _authRepository = authRepository;

  static Page<void> page() => MaterialPage(
      child: HomeScreen(
          propertyRepository:
              PropertyRepository(supabase: SupabaseConfig.supabase),
          authRepository: AuthRepository(
              supabase: SupabaseConfig.supabase,
              googleSignIn: GoogleSignInConfig.googleSignIn,
              secureStorage: FlutterStorageConfig.secureStorage)));

  final AuthRepository _authRepository;

  @override
  State<HomeScreen> createState() => _HomePageState();
}

class _HomePageState extends State<HomeScreen> {
  int _currentIndex = 0;

  Widget _buildPage(index) {
    switch (index) {
      case 0:
        return const HomePage();
      case 1:
        return const UnitsPage();
      case 2:
        return const TenantsPage();
      case 3:
        return const PaymentsPage();
      default:
        return const Center(
          child: Text('404'),
        );
    }
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Units';
      case 2:
        return 'Tenants';
      case 3:
        return 'Payments';
      default:
        return '404';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc()..add(LoadHome()),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            SystemNavigator.pop();
            return;
          }
        },
        child: Scaffold(
            appBar: AppBar(
              title: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  if (state is HomeLoading) {
                    return const ShimmerLoading(
                      child: ShimmerContainer(
                        height: 20,
                        width: 100,
                      ),
                    );
                  } else if (state is HomeLoaded && _currentIndex == 0) {
                    return Text(state.selectedProperty?.name ?? 'Home');
                  } else {
                    return Text(_getTitle(_currentIndex));
                  }
                },
              ),
            ),
            drawer: _drawer(
                context: context, authRepository: widget._authRepository),
            body: PageTransitionSwitcher(
              transitionBuilder: (child, animation, secondaryAnimation) {
                return FadeThroughTransition(
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  child: child,
                );
              },
              child: _buildPage(_currentIndex),
            ),
            bottomNavigationBar: Theme(
                data: Theme.of(context).copyWith(
                  bottomNavigationBarTheme: BottomNavigationBarThemeData(
                    selectedItemColor: Theme.of(context).colorScheme.primary,
                    unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    showSelectedLabels: true,
                    showUnselectedLabels: true,
                    type: BottomNavigationBarType.fixed,
                    elevation: 8,
                  ),
                ),
                child: BottomNavigationBar(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.analytics_outlined),
                        activeIcon: Icon(Icons.analytics),
                        label: 'Home',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.home_work_outlined),
                        activeIcon: Icon(Icons.home_work_rounded),
                        label: 'Units',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.people_alt_outlined),
                        activeIcon: Icon(Icons.people_alt_rounded),
                        label: 'Tenants',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.payment_outlined),
                        activeIcon: Icon(Icons.payment_rounded),
                        label: 'Payments',
                      ),
                    ])),
      ),
    ));
  }
}
