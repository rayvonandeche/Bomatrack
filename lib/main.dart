import 'package:bomatrack/app/app.dart';
import 'package:bomatrack/core/config/config.dart';
import 'package:bomatrack/services/services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await SupabaseConfig.init();

  final authRepository = AuthRepository(
    supabase: SupabaseConfig.supabase,
    googleSignIn: GoogleSignInConfig.googleSignIn,
    secureStorage: FlutterStorageConfig.secureStorage,
  );

  runApp(App(
    authenticationRepository: authRepository,
  ));
}
