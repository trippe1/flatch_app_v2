extension EmailValidator on String {
  String? isValidEmail() {
    bool match = RegExp(
            r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$')
        .hasMatch(this);
    if (trim().isEmpty) {
      return "Email is required";
    } else if (match) {
      return null;
    } else {
      return "Please enter a valid email address";
    }
  }
}
