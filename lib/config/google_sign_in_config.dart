import 'package:google_sign_in/google_sign_in.dart';

abstract class GoogleSignInConfig {
  static const _webClientId =
      '843195742570-sdodllnf205eekgpt7b4q6d7s9bpkb5o.apps.googleusercontent.com';

  static const _iosClientId =
      '843195742570-gmeglhfsmqo84h7mplg75q5ed0leqim7.apps.googleusercontent.com';

  static final GoogleSignIn googleSignIn = GoogleSignIn(
    clientId: _iosClientId,
    serverClientId: _webClientId,
  );
  
}
