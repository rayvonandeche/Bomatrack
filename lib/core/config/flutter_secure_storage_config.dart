import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class FlutterStorageConfig {
  static AndroidOptions _getAndroidOptions() => const AndroidOptions(
        encryptedSharedPreferences: true,
      );
  static FlutterSecureStorage secureStorage =
      FlutterSecureStorage(aOptions: _getAndroidOptions());
}
