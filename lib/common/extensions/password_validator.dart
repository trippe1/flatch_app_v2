extension PasswordValidator on String {
  String? isValidPassword() {
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[!@#\$%\^&\*])[A-Za-z\d!@#\$%\^&\*]{8,20}$',
    );
    if (trim().isEmpty) {
      return "Password is required";
    } else if (!regex.hasMatch(trim())) {
      return "8–20 char, one uppercase letter, one lowercase letter, one number, and one special character (!@#\$%^&*)";
    } else {
      return null;
    }
  }
}
