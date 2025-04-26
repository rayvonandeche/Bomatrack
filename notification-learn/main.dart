import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Supabase.initialize(
    url: 'https://tzsxucuhfxdpicgcsvcn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR6c3h1Y3VoZnhkcGljZ2NzdmNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDEyNDUyNjMsImV4cCI6MjA1NjgyMTI2M30.bh0zsfYMrx0cH4bzOp-ihgoJJXKxu_xbbF5ftRM6yHQ',
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Push Notification Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const HomePage(),
          '/details': (context) => const Details(),
        });
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    supabase.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedIn) {
        await FirebaseMessaging.instance.requestPermission();
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await _setFcmToken(fcmToken);
        }
      }
    });
    FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) async {
      await _setFcmToken(fcmToken);
    });
    FirebaseMessaging.onMessage.listen((payload) {
      final notification = payload.notification;
      if (notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notification.body ?? 'No message body'),
            action: SnackBarAction(
              label: 'Close',
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    });
    _();
  }

  Future<void> _setFcmToken(String token) async {
    final userId = supabase.auth.currentSession?.user.id;
    if (userId != null) {
      await supabase.from('profiles').upsert({
        'id': supabase.auth.currentSession?.user.id,
        'fcm_token': token,
      });
    }
  }

  Future<void> _() async {
    RemoteMessage? message =
        await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) {
      _handleMessage(message);
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      Navigator.pushNamed(context, '/details', arguments: {
        'title': notification.title,
        'body': notification.body,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Push Notification Demo'),
          actions: [
            IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await supabase.auth.signOut();
                })
          ],
        ),
        body: StreamBuilder<AuthState>(
            stream: supabase.auth.onAuthStateChange,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }
              if (snapshot.data?.session == null) {
                return const AuthenticationPage();
              }

              return const HomePageContent();
            }));
  }
}

class AuthenticationPage extends StatefulWidget {
  const AuthenticationPage({super.key});

  @override
  State<AuthenticationPage> createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends State<AuthenticationPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _signIn() async {
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
    } catch (e) {
      // Handle error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _signIn,
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

class HomePageContent extends StatefulWidget {
  const HomePageContent({super.key});

  @override
  State<HomePageContent> createState() => _HomePageContentState();
}

class _HomePageContentState extends State<HomePageContent> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Enter Text',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await supabase.from('messages').insert({
                  'user_id': supabase.auth.currentSession?.user.id,
                  'message': _textController.text,
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message sent!')),
                );
                _textController.clear();
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}


class Details extends StatelessWidget {
  const Details({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, String?>;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Title: ${args['title']}'),
            Text('Body: ${args['body']}'),
          ],
        ),
      ),
    );
  }
}