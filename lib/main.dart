import 'package:bomatrack/app/app.dart';
import 'package:bomatrack/config/config.dart';
import 'package:bomatrack/services/services.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
