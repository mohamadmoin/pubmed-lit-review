/// Parse API/Neo4j timestamps into [DateTime].
DateTime parseFlexibleTimestamp(dynamic value) {
  if (value == null) {
    return DateTime.now();
  }
  if (value is DateTime) {
    return value;
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return DateTime.now();
  }

  try {
    return DateTime.parse(text);
  } catch (_) {
    // Neo4j sometimes returns nanosecond fractions Dart cannot parse.
    final normalized = text.replaceFirstMapped(
      RegExp(r'\.(\d{3})\d+(?=[Z+\-])'),
      (m) => '.${m.group(1)}',
    );
    try {
      return DateTime.parse(normalized);
    } catch (_) {
      return DateTime.now();
    }
  }
}
