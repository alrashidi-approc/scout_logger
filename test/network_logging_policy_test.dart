import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/config/network_logging_policy.dart';

void main() {
  test('errorsOnly skips request and response logging', () {
    const NetworkLoggingPolicy policy = NetworkLoggingPolicy(
      scope: NetworkLogScope.errorsOnly,
    );
    expect(policy.shouldLogRequest(), isFalse);
    expect(policy.shouldLogResponse(200), isFalse);
    expect(policy.shouldLogFailure(500), isTrue);
  });

  test('nonErrorStatusCodes suppress failure logs', () {
    const NetworkLoggingPolicy policy = NetworkLoggingPolicy(
      nonErrorStatusCodes: <int>{401, 404},
    );
    expect(policy.shouldLogFailure(401), isFalse);
    expect(policy.shouldLogFailure(404), isFalse);
    expect(policy.shouldLogFailure(500), isTrue);
    expect(policy.shouldLogFailure(null), isTrue);
  });

  test('all scope still skips ignored statuses on response path', () {
    const NetworkLoggingPolicy policy = NetworkLoggingPolicy(
      scope: NetworkLogScope.all,
      nonErrorStatusCodes: <int>{401},
    );
    expect(policy.shouldLogRequest(), isTrue);
    expect(policy.shouldLogResponse(200), isTrue);
    expect(policy.shouldLogResponse(401), isFalse);
    expect(policy.shouldLogFailure(401), isFalse);
  });
}
