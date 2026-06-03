/// How much HTTP traffic [SmartDioInterceptor] records.
enum NetworkLogScope {
  /// Log request start, successful responses, and failures.
  all,

  /// Log only failures (still respects [NetworkLoggingPolicy.nonErrorStatusCodes]).
  errorsOnly,
}

/// Controls Dio network logging volume and which HTTP statuses count as errors.
class NetworkLoggingPolicy {
  const NetworkLoggingPolicy({
    this.scope = NetworkLogScope.all,
    this.nonErrorStatusCodes = kDefaultNonErrorHttpStatuses,
  });

  /// Default: full waterfall logging; 401 is expected auth flow, not an incident.
  static const NetworkLoggingPolicy defaults = NetworkLoggingPolicy();

  final NetworkLogScope scope;
  final Set<int> nonErrorStatusCodes;

  bool shouldLogRequest() => scope == NetworkLogScope.all;

  bool shouldLogResponse(int? statusCode) {
    if (scope == NetworkLogScope.errorsOnly) {
      return false;
    }
    return !_isIgnoredStatus(statusCode);
  }

  bool shouldLogFailure(int? statusCode) {
    return !_isIgnoredStatus(statusCode);
  }

  bool _isIgnoredStatus(int? statusCode) =>
      statusCode != null && nonErrorStatusCodes.contains(statusCode);
}

/// Status codes that must not produce failure logs (e.g. session expired).
const Set<int> kDefaultNonErrorHttpStatuses = <int>{401};
