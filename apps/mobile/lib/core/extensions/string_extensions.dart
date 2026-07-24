extension StringX on String {
  /// `'hello world'` → `'Hello world'`.
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// `'hello world'` → `'Hello World'`.
  String get titleCased => split(' ').map((word) => word.capitalized).join(' ');

  bool get isValidEmail => RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(this);

  /// Truncates to [max] chars with a trailing ellipsis.
  String ellipsize(int max) => length <= max ? this : '${substring(0, max)}…';
}

extension NullableStringX on String? {
  bool get isNullOrBlank => this == null || this!.trim().isEmpty;

  bool get isNotNullOrBlank => !isNullOrBlank;

  String get orEmpty => this ?? '';
}
