class PiiScrubber {
  static const Set<String> _sensitiveMarkers = <String>{
    'password',
    'token',
    'authorization',
    'card_number',
    'cvv',
    'email',
    'phone',
  };

  static dynamic scrub(dynamic value) {
    if (value is Map) {
      return value.map((dynamic key, dynamic nestedValue) {
        final String keyString = key.toString().toLowerCase();
        if (_sensitiveMarkers.any(keyString.contains)) {
          return MapEntry<dynamic, dynamic>(key, '[REDACTED]');
        }
        return MapEntry<dynamic, dynamic>(key, scrub(nestedValue));
      });
    }
    if (value is List) {
      return value.map(scrub).toList(growable: false);
    }
    return value;
  }
}
