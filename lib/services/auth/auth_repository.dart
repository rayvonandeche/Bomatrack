import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient supabase;
  final GoogleSignIn googleSignIn;
  final FlutterSecureStorage secureStorage;

  AuthRepository(
      {required this.supabase,
      required this.googleSignIn,
      required this.secureStorage})
      : _supabase = supabase,
        _googleSignIn = googleSignIn,
        _secureStorage = secureStorage;

  final SupabaseClient _supabase;
  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _secureStorage;
  bool _i = false;

  final String _supabaseKey = 'supabase.session';

  bool get isGoogleSignIn => _i;

  Session? get currentSession => _supabase.auth.currentSession;

  Stream<Session?> get userSession =>
      _supabase.auth.onAuthStateChange.map((event) => event.session);	

  Future<AuthResponse?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
      );
      if (res.user!.userMetadata!.isEmpty && res.user!.identities!.isEmpty) {
        throw 'User already exists';
      }
      if (res.user!.userMetadata!.isNotEmpty &&
          res.user!.identities!.isNotEmpty) {
        return res;
      }
      return null;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<AuthResponse?> signInWithGoogle() async {
    _i = true;
    try {
      final googleUser = await _googleSignIn.signIn();
      final googleAuth = await googleUser!.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (accessToken == null) {
        throw 'No Access Token Found';
      }
      if (idToken == null) {
        throw 'No Id Token Found';
      }

      final res = await _supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken);

      if (res.session != null && res.user != null) {
        return res;
      }

      return null;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _supabase.auth
          .signInWithPassword(email: email, password: password);
      if (res.session != null && res.user != null) {
        await _secureStorage.write(
            key: _supabaseKey, value: jsonEncode(res.session));
      }
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _supabase.auth.signOut();
      await _secureStorage.delete(key: _supabaseKey);
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<UserResponse?> completeProfile({
    required String firstName,
    required String lastName,
    required String username,
    required String phoneNumber,
    required String organization,
  }) async {
    try {
      final phone = '254${phoneNumber.substring(1)}';
      final UserResponse res = await _supabase.auth.updateUser(
        UserAttributes(
          data: {
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'phone_number': phone,
            'username': username.trim(),
            'organization': organization,
          },
        ),
      );
      return res;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<AuthResponse> verifyOTP({
    required String email,
    required String otp,
  }) async {
    try {
      final res = await _supabase.auth.verifyOTP(
        email: email,
        token: otp,
        type: OtpType.signup,
      );
      return res;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<ResendResponse> resendOTP({
    required String email,
  }) async {
    try {
      final res =
          await _supabase.auth.resend(type: OtpType.signup, email: email);
      return res;
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
