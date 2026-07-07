extension StringExtensions on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  String capitalizeEachWord() {
    if (trim().isEmpty) return this;

    return split(RegExp(r'\s+')) // Split by spaces
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' '); // Join words back with a space
  }
}
