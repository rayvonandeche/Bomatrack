import 'package:bomatrack/app/app.dart';
import 'package:bomatrack/features/home/presentation/bloc/bloc.dart';
import 'package:bomatrack/features/home/presentation/home.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:animations/animations.dart';
import 'package:bomatrack/services/services.dart';
import 'package:bomatrack/shared/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bomatrack/core/theme/theme.dart';
import 'package:bomatrack/core/config/config.dart';
import 'package:bomatrack/features/home/presentation/screens/about/about_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _notificationPermissionRequested = false;
  bool _notificationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    // Delay notification permission request to ensure UI loads properly first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestNotificationPermission();
    });
  }

  Future<void> _checkAndRequestNotificationPermission() async {
    // Check if we've already asked for permission
    final prefs = await SharedPreferences.getInstance();
    final hasAskedForPermission =
        prefs.getBool('notification_permission_requested') ?? false;

    // Check current permission status
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final isGranted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    if (mounted) {
      setState(() {
        _notificationPermissionRequested = hasAskedForPermission;
        _notificationPermissionGranted = isGranted;
      });
    }

    // If we haven't asked or if the permissions aren't granted, show the request dialog
    if ((!hasAskedForPermission || !isGranted) && mounted) {
      // Wait a moment for the app to settle before showing dialog
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _showNotificationPermissionDialog();
      });
    } else if (isGranted) {
      // If permission is granted, initialize FCM token storage
      _initializeFcmTokenStorage();
    }
  }

  Future<void> _showNotificationPermissionDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enable Notifications'),
        content: const Text(
            'Notifications help you stay updated on important property events, tenant payments, and maintenance alerts. Would you like to enable notifications?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _markPermissionAsRequested(granted: false);
            },
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _requestNotificationPermission();
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestNotificationPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;

    _markPermissionAsRequested(granted: granted);

    if (granted) {
      _initializeFcmTokenStorage();
    } else {
      // Show a follow-up dialog explaining why notifications are important
      if (mounted) {
        _showPermissionDeniedDialog();
      }
    }
  }

  Future<void> _showPermissionDeniedDialog() async {
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notifications Disabled'),
        content: const Text(
            'You\'ve declined notifications, which means you might miss important updates about your properties. You can enable notifications later in your device settings.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _requestNotificationPermission();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _markPermissionAsRequested({required bool granted}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_permission_requested', true);

    setState(() {
      _notificationPermissionRequested = true;
      _notificationPermissionGranted = granted;
    });
  }

  Future<void> _initializeFcmTokenStorage() async {
    // Get the FCM token
    final fcmToken = await FirebaseMessaging.instance.getToken();

    // Store the token in Supabase
    if (fcmToken != null) {
      final supabase = SupabaseConfig.supabase;
      final user = supabase.auth.currentUser;

      if (user != null) {
        try {
          await supabase.from('profiles').upsert({
            'id': user.id,
            'fcm_token': fcmToken,
            'organization_id': user.userMetadata!['organization']
          });

          // Listen for token changes
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
            await supabase.from('profiles').upsert({
              'id': user.id,
              'fcm_token': newToken,
              'organization_id': user.userMetadata!['organization']
            });
          });

          // Setup notification handlers
          _setupNotificationHandlers();
        } catch (e) {
          debugPrint('Error storing FCM token: $e');
        }
      }
    }
  }

  void _setupNotificationHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notification.title ?? 'New notification'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // Handle notification action
                _handleNotificationData(message.data);
              },
            ),
          ),
        );
      }
    });

    // Check for initial notification if the app was opened from terminated state
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        _handleNotificationData(message.data);
      }
    });

    // Handle background notifications when app is opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationData(message.data);
    });
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    // Handle notification data based on type
    final String? eventType = data['event_type'];
    final String? entityType = data['entity_type'];
    final String? entityId = data['entity_id'];

    if (eventType != null && entityType != null && entityId != null) {
      // Here you can navigate to specific screens based on notification type
      // For example:
      /*
      if (entityType == 'payment') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => PaymentDetailsScreen(paymentId: entityId),
        ));
      } else if (entityType == 'tenant') {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TenantDetailsScreen(tenantId: entityId),
        ));
      }
      */
    }
  }

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
              systemOverlayStyle: SystemUiOverlayStyle.light,
              backgroundColor: AppTheme.primaryColor,
              scrolledUnderElevation: 0,
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
                    unselectedItemColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
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
