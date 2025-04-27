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
  // ignore: unused_field
  bool _notificationPermissionRequested = false;
  // ignore: unused_field
  bool _notificationPermissionGranted = false;
  bool _isAppReady = false;
  bool _isHandlingDeepLink = false;
  Map<String, dynamic>? _pendingNotificationData;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize the app state
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // Start with app not ready
    setState(() {
      _isAppReady = false;
    });
    
    // Initialize notification handlers first to capture any deep links
    await _setupNotificationHandlers();
    
    // Then check notification permissions
    await _checkAndRequestNotificationPermission();
    
    // Mark app as ready after initialization
    setState(() {
      _isAppReady = true;
    });
    
    // Process any pending notification data after app is ready
    if (_pendingNotificationData != null) {
      _processDeepLink(_pendingNotificationData!);
      _pendingNotificationData = null;
    }
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
      await _initializeFcmTokenStorage();
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
      await _initializeFcmTokenStorage();
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
        } catch (e) {
          debugPrint('Error storing FCM token: $e');
        }
      }
    }
  }

  Future<void> _setupNotificationHandlers() async {
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
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      if (_isAppReady) {
        _handleNotificationData(initialMessage.data);
      } else {
        // Store it temporarily if app isn't ready yet
        _pendingNotificationData = initialMessage.data;
      }
    }

    // Handle background notifications when app is opened
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (_isAppReady) {
        _handleNotificationData(message.data);
      } else {
        // Store it temporarily if app isn't ready yet
        _pendingNotificationData = message.data;
      }
    });
  }

  void _handleNotificationData(Map<String, dynamic> data) {
    // Set flag to indicate we're handling a deep link
    setState(() {
      _isHandlingDeepLink = true;
      _pendingNotificationData = data;
    });

    // Process the deep link once the app is ready
    if (_isAppReady) {
      _processDeepLink(data);
    }
    // If app is not ready, it will be processed in _initializeApp once ready
  }

  void _processDeepLink(Map<String, dynamic> data) {
    final String? eventType = data['event_type'];
    final String? entityType = data['entity_type'];
    final String? entityId = data['entity_id'];
    final String? clickAction = data['click_action'];

    debugPrint('Processing deep link: $data');

    if (eventType != null && entityType != null && entityId != null) {
      // Set the appropriate tab index based on the notification type
      int targetIndex = 0;
      
      if (clickAction == 'VIEW_PAYMENT' || clickAction == 'VIEW_OVERDUE_PAYMENT') {
        targetIndex = 3; // Payments tab
      } else if (clickAction == 'VIEW_TENANT') {
        targetIndex = 2; // Tenants tab
      } else if (clickAction == 'VIEW_UNIT') {
        targetIndex = 1; // Units tab
      } else if (clickAction == 'VIEW_PROPERTY') {
        targetIndex = 0; // Home/Property tab
      }

      setState(() {
        _currentIndex = targetIndex;
        _isHandlingDeepLink = false;
      });

      // Now navigate to the specific entity detail screen
      // This should be done after the tab has changed and UI has updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToEntityDetails(entityType, entityId, data);
      });
    } else {
      // If we don't have enough data, just clear the handling flag
      setState(() {
        _isHandlingDeepLink = false;
      });
    }
  }

  void _navigateToEntityDetails(String entityType, String entityId, Map<String, dynamic> data) {
    // Navigate to the appropriate detail screen based on entity type
    // For example:
    switch (entityType) {
      case 'payment':
        // Example: Navigate to payment details
        // Navigator.of(context).push(MaterialPageRoute(
        //   builder: (_) => PaymentDetailsScreen(paymentId: int.parse(entityId)),
        // ));
        break;
      case 'tenant':
        // Example: Navigate to tenant details
        // Navigator.of(context).push(MaterialPageRoute(
        //   builder: (_) => TenantDetailsScreen(tenantId: int.parse(entityId)),
        // ));
        break;
      case 'unit':
        // Example: Navigate to unit details
        // Navigator.of(context).push(MaterialPageRoute(
        //   builder: (_) => UnitDetailsScreen(unitId: int.parse(entityId)),
        // ));
        break;
      case 'property':
        // Example: Navigate to property details
        // Navigator.of(context).push(MaterialPageRoute(
        //   builder: (_) => PropertyDetailsScreen(propertyId: int.parse(entityId)),
        // ));
        break;
      default:
        debugPrint('Unknown entity type: $entityType');
    }
  }

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
          body: _isAppReady && !_isHandlingDeepLink
              ? PageTransitionSwitcher(
                  transitionBuilder: (child, animation, secondaryAnimation) {
                    return FadeThroughTransition(
                      animation: animation,
                      secondaryAnimation: secondaryAnimation,
                      child: child,
                    );
                  },
                  child: _buildPage(_currentIndex),
                )
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text(
                        'Loading...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
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
      ),
    );
  }
}
