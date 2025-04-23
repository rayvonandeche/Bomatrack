import 'package:formz/formz.dart';

class Phone extends FormzInput<String, String> {
  const Phone.pure() : super.pure('');
  const Phone.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String value) {
    return RegExp(r'^0[17]\d{8}$').hasMatch(value) || value.isEmpty
        ? null
        : 'Invalid phone number';
  }
}
