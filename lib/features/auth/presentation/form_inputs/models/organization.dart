import 'package:formz/formz.dart';

enum OrganizationValidationError { invalid }

class Organization extends FormzInput<String, OrganizationValidationError> {
  const Organization.pure() : super.pure('');
  const Organization.dirty([super.value = '']) : super.dirty();

  @override
  OrganizationValidationError? validator(String? value) {
    return value?.isEmpty == true ? OrganizationValidationError.invalid : null;
  }
}
