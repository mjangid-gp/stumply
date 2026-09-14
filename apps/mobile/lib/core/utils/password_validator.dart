class PasswordValidationResult {
  const PasswordValidationResult({required this.isValid, this.errors = const []});

  final bool isValid;
  final List<String> errors;
}

class PasswordValidator {
  static const minLength = 8;

  static PasswordValidationResult validate(String password) {
    final errors = <String>[];

    if (password.length < minLength) {
      errors.add('At least $minLength characters');
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      errors.add('One uppercase letter');
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      errors.add('One lowercase letter');
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      errors.add('One number');
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]').hasMatch(password)) {
      errors.add('One special character');
    }

    return PasswordValidationResult(isValid: errors.isEmpty, errors: errors);
  }

  static String? formError(String? password) {
    if (password == null || password.isEmpty) return 'Password is required';
    final result = validate(password);
    if (result.isValid) return null;
    return 'Password needs: ${result.errors.join(', ')}';
  }

  static List<String> requirements = const [
    'At least 8 characters',
    'One uppercase letter (A-Z)',
    'One lowercase letter (a-z)',
    'One number (0-9)',
    'One special character (!@#...)',
  ];
}
