extension CommmonValidator on String {
  bool isValidURL() {
    // Define a regex pattern for URL validation
    String pattern = r'^(https?:\/\/)?' // Optional protocol (http or https)
        r'((([a-zA-Z\d]([a-zA-Z\d-]*[a-zA-Z\d])*)\.)+[a-zA-Z]{2,}|' // Domain name
        r'((\d{1,3}\.){3}\d{1,3}))' // OR IP (v4) address
        r'(\:\d+)?(\/[-a-zA-Z\d%_.~+]*)*' // Optional port and path
        r'(\?[;&a-zA-Z\d%_.~+=-]*)?' // Optional query string
        r'(\#[-a-zA-Z\d_]*)?$'; // Optional fragment locator
    RegExp regExp = RegExp(pattern);
    return regExp.hasMatch(this);
  }
}
