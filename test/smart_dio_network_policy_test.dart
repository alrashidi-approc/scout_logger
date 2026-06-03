import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/config/network_logging_policy.dart';
import 'package:scout_logger/src/core/smart_dio_interceptor.dart';
import 'package:scout_logger/src/core/timed_http_client_adapter.dart';
import 'package:scout_logger/src/models/log_models.dart';

void main() {
  test('errorsOnly does not emit request or success response logs', () async {
    final List<String> messages = <String>[];
    final Dio dio = _dioWithPolicy(
      const NetworkLoggingPolicy(scope: NetworkLogScope.errorsOnly),
      _SuccessAdapter(),
      onMessage: messages.add,
    );

    await dio.get<Object>('/ok');

    expect(messages, isEmpty);
  });

  test('skips all logs for ignored failure status when errorsOnly', () async {
    final List<String> messages = <String>[];
    final Dio dio = _dioWithPolicy(
      const NetworkLoggingPolicy(
        scope: NetworkLogScope.errorsOnly,
        nonErrorStatusCodes: <int>{401},
      ),
      _StatusAdapter(401),
      onMessage: messages.add,
    );

    try {
      await dio.get<Object>('/me');
      fail('expected DioException');
    } on DioException {
      // expected
    }

    expect(messages, isEmpty);
  });

  test('errorsOnly still logs true failures', () async {
    final List<String> messages = <String>[];
    final Dio dio = _dioWithPolicy(
      const NetworkLoggingPolicy(scope: NetworkLogScope.errorsOnly),
      _StatusAdapter(500),
      onMessage: messages.add,
    );

    try {
      await dio.get<Object>('/boom');
      fail('expected DioException');
    } on DioException {
      // expected
    }

    expect(messages, contains('API request failed'));
  });
}

Dio _dioWithPolicy(
  NetworkLoggingPolicy policy,
  HttpClientAdapter adapter, {
  required void Function(String message) onMessage,
}) {
  return Dio()
    ..httpClientAdapter = TimedHttpClientAdapter(adapter)
    ..interceptors.add(
      SmartDioInterceptor(
        ({
          required Domain domain,
          required LogCategory category,
          required LogLevel level,
          required String message,
          Map<String, dynamic> metadata = const <String, dynamic>{},
          String? stackTrace,
          bool immediateDispatch = false,
        }) async {
          onMessage(message);
        },
        networkPolicy: policy,
      ),
    );
}

class _SuccessAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('ok', 200);
  }

  @override
  void close({bool force = false}) {}
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('body', status);
  }

  @override
  void close({bool force = false}) {}
}
