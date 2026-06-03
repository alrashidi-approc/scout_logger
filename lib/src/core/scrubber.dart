class PiiScrubber {
  static const Set<String> _sensitiveMarkers = <String>{
    'password',
    'passwd',
    'secret',
    'token',
    'authorization',
    'auth',
    'bearer',
    'api_key',
    'apikey',
    'card_number',
    'cardnumber',
    'cvv',
    'cvc',
    'ssn',
    'email',
    'phone',
    'otp',
    'pin',
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
