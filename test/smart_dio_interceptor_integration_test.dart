import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/core/network_timing_keys.dart';
import 'package:scout_logger/src/core/smart_dio_interceptor.dart';
import 'package:scout_logger/src/core/timed_http_client_adapter.dart';
import 'package:scout_logger/src/models/log_models.dart';

void main() {
  test('emits response log with waterfall metadata from timed adapter', () async {
    final List<_CapturedLog> captured = <_CapturedLog>[];
    final Dio dio = Dio()
      ..httpClientAdapter = TimedHttpClientAdapter(
        _SuccessAdapter(),
        nowMicros: _TickClock(<int>[1000, 1100, 1400]).call,
      )
      ..interceptors.add(
        SmartDioInterceptor(
          ({
            required Domain domain,
            required LogCategory category,
            required LogLevel level,
            required String message,
            Map<String, dynamic> metadata = const <String, dynamic>{},
            Map<String, dynamic> customMetadata = const <String, dynamic>{},
            String? stackTrace,
            bool immediateDispatch = false,
          }) async {
            captured.add(
              _CapturedLog(
                domain: domain,
                category: category,
                level: level,
                message: message,
                metadata: metadata,
                customMetadata: customMetadata,
              ),
            );
          },
          nowMicros: _TickClock(<int>[900, 1500]).call,
        ),
      );

    await dio.get<Object>(
      '/orders',
      options: Options(responseType: ResponseType.plain),
    );

    final _CapturedLog completed = captured.firstWhere(
      (_CapturedLog log) => log.message == 'API request completed',
    );
    final Map<String, dynamic> waterfall =
        completed.metadata['waterfallUs'] as Map<String, dynamic>;
    expect(waterfall['startedAt'], 900);
    expect(waterfall['firstByteAt'], 1000);
    expect(waterfall['ttfb'], 100);
    expect(waterfall['payloadDownload'], 100);
    expect(waterfall['total'], 200);
  });

  test('emits error log with waterfall and scrubbed payloads', () async {
    final List<_CapturedLog> captured = <_CapturedLog>[];
    final Dio dio = Dio()
      ..httpClientAdapter = TimedHttpClientAdapter(
        _ErrorAdapter(),
        nowMicros: _TickClock(<int>[2000, 2100, 2400]).call,
      )
      ..interceptors.add(
        SmartDioInterceptor(
          ({
            required Domain domain,
            required LogCategory category,
            required LogLevel level,
            required String message,
            Map<String, dynamic> metadata = const <String, dynamic>{},
            Map<String, dynamic> customMetadata = const <String, dynamic>{},
            String? stackTrace,
            bool immediateDispatch = false,
          }) async {
            captured.add(
              _CapturedLog(
                domain: domain,
                category: category,
                level: level,
                message: message,
                metadata: metadata,
                customMetadata: customMetadata,
              ),
            );
          },
          nowMicros: _TickClock(<int>[1900, 2500]).call,
        ),
      );

    try {
      await dio.post<Object>(
        '/orders',
        data: <String, dynamic>{'password': 'secret'},
      );
      fail('Expected DioException');
    } on DioException {
      // Expected.
    }

    final _CapturedLog failure = captured.firstWhere(
      (_CapturedLog log) => log.message == 'API request failed',
    );
    final Map<String, dynamic> waterfall =
        failure.metadata['waterfallUs'] as Map<String, dynamic>;
    expect(waterfall['startedAt'], 1900);
    expect(waterfall['firstByteAt'], 2000);
    expect(waterfall['ttfb'], 100);
    expect(waterfall['payloadDownload'], 100);
    expect(waterfall['total'], 200);
    final Map<dynamic, dynamic> requestBody =
        failure.metadata['requestBody'] as Map<dynamic, dynamic>;
    final Map<dynamic, dynamic> responseBody =
        failure.metadata['responseBody'] as Map<dynamic, dynamic>;
    expect(requestBody['password'], '[REDACTED]');
    expect(responseBody['token'], '[REDACTED]');
  });

  test('forwards dio scoutIncidentCustom on failed requests', () async {
    final List<_CapturedLog> captured = <_CapturedLog>[];
    final Dio dio = Dio()
      ..httpClientAdapter = TimedHttpClientAdapter(_ErrorAdapter())
      ..interceptors.add(
        SmartDioInterceptor(
          ({
            required Domain domain,
            required LogCategory category,
            required LogLevel level,
            required String message,
            Map<String, dynamic> metadata = const <String, dynamic>{},
            Map<String, dynamic> customMetadata = const <String, dynamic>{},
            String? stackTrace,
            bool immediateDispatch = false,
          }) async {
            captured.add(
              _CapturedLog(
                domain: domain,
                category: category,
                level: level,
                message: message,
                metadata: metadata,
                customMetadata: customMetadata,
              ),
            );
          },
        ),
      );

    try {
      await dio.get<Object>(
        '/fail',
        options: Options(
          extra: <String, dynamic>{
            kScoutIncidentCustomKey: <String, dynamic>{'feature': 'inbox'},
          },
        ),
      );
    } on DioException {
      // expected
    }

    final _CapturedLog failure = captured.firstWhere(
      (_CapturedLog log) => log.message == 'API request failed',
    );
    expect(failure.customMetadata['feature'], 'inbox');
  });
}

class _SuccessAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream<Uint8List>.fromIterable(<Uint8List>[
        Uint8List.fromList(<int>[111]),
        Uint8List.fromList(<int>[107]),
      ]),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream<Uint8List>.fromIterable(<Uint8List>[
        Uint8List.fromList(<int>[123, 34, 116, 111, 107, 101, 110, 34, 58]),
        Uint8List.fromList(<int>[34, 115, 51, 99, 114, 51, 116, 34, 125]),
      ]),
      500,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _TickClock {
  _TickClock(this._ticks);

  final List<int> _ticks;

  int call() => _ticks.removeAt(0);
}

class _CapturedLog {
  const _CapturedLog({
    required this.domain,
    required this.category,
    required this.level,
    required this.message,
    required this.metadata,
    this.customMetadata = const <String, dynamic>{},
  });

  final Domain domain;
  final LogCategory category;
  final LogLevel level;
  final String message;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> customMetadata;
}
