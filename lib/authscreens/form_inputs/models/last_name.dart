import 'package:formz/formz.dart';

class LastName extends FormzInput<String, String> {
  const LastName.pure() : super.pure('');
  const LastName.dirty([super.value = '']) : super.dirty();

  @override
  String? validator(String? value) {
    return value?.isNotEmpty == true ? null : '';
  }
}