import 'package:formz/formz.dart';

class Username extends FormzInput<String, String> {
  const Username.pure() : super.pure('');
  const Username.dirty([super.value = '']) : super.dirty();

  static final RegExp _usernameRegExp = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  @override
  String? validator(String? value) {
    return _usernameRegExp.hasMatch(value ?? '')
        ? null
        : 'Invalid username';
  }
}