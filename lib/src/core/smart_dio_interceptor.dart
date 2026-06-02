import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../models/log_models.dart';
import 'network_timing_keys.dart';
import 'scout_logger_manager.dart';
import 'scrubber.dart';

typedef NetworkLogEmitter =
    Future<void> Function({
      required Domain domain,
      required LogCategory category,
      required LogLevel level,
      required String message,
      Map<String, dynamic> metadata,
      String? stackTrace,
      bool immediateDispatch,
    });

class SmartDioInterceptor extends Interceptor {
  /// Creates a Dio interceptor that emits sanitized network logs.
  SmartDioInterceptor.fromLogger(
    ScoutLogger logger, {
    Uuid? uuid,
    int Function()? nowMicros,
  }) : this(logger.log, uuid: uuid, nowMicros: nowMicros);

  SmartDioInterceptor(
    this._emitLog, {
    Uuid? uuid,
    int Function()? nowMicros,
  }) : _uuid = uuid ?? const Uuid(),
       _nowMicros = nowMicros ?? (() => DateTime.now().microsecondsSinceEpoch);

  final NetworkLogEmitter _emitLog;
  final Uuid _uuid;
  final int Function() _nowMicros;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    final String traceId = _uuid.v4();
    final int start = _nowMicros();
    options.headers['X-Trace-ID'] = traceId;
    options.extra[kScoutStartUsKey] = start;
    options.extra[kScoutTraceIdKey] = traceId;

    _emitLog(
      domain: Domain.external,
      category: LogCategory.network,
      level: LogLevel.debug,
      message: 'API request started',
      metadata: <String, dynamic>{
        'traceId': traceId,
        'path': options.path,
        'method': options.method,
        'startedAtUs': start,
        'headers': PiiScrubber.scrub(options.headers),
        'body': PiiScrubber.scrub(options.data),
      },
    );
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final int now = _nowMicros();
    final int start = response.requestOptions.extra[kScoutStartUsKey] as int? ?? now;
    final int firstByte = response.extra[kScoutFirstByteUsKey] as int? ?? now;
    final int doneAt = response.extra[kScoutResponseDoneUsKey] as int? ?? now;
    final int ttfbUs = firstByte - start;
    final int payloadUs = doneAt - firstByte;
    final int totalUs = doneAt - start;

    _emitLog(
      domain: Domain.external,
      category: LogCategory.network,
      level: LogLevel.info,
      message: 'API request completed',
      metadata: <String, dynamic>{
        'traceId': response.requestOptions.extra[kScoutTraceIdKey],
        'statusCode': response.statusCode,
        'path': response.requestOptions.path,
        'method': response.requestOptions.method,
        'waterfallUs': <String, int>{
          'startedAt': start,
          'firstByteAt': firstByte,
          'ttfb': ttfbUs,
          'payloadDownload': payloadUs,
          'total': totalUs,
        },
        'networkWaterfall': <Map<String, dynamic>>[
          <String, dynamic>{'phase': 'ttfb', 'durationUs': ttfbUs},
          <String, dynamic>{'phase': 'payload_download', 'durationUs': payloadUs},
          <String, dynamic>{'phase': 'total', 'durationUs': totalUs},
        ],
        'response': PiiScrubber.scrub(response.data),
      },
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final int now = _nowMicros();
    final int start = err.requestOptions.extra[kScoutStartUsKey] as int? ?? now;
    final int firstByte =
        err.response?.extra[kScoutFirstByteUsKey] as int? ?? now;
    final int doneAt =
        err.response?.extra[kScoutResponseDoneUsKey] as int? ?? now;
    final int ttfbUs = firstByte - start;
    final int totalUs = doneAt - start;
    final int payloadUs = doneAt - firstByte;
    _emitLog(
      domain: Domain.external,
      category: LogCategory.network,
      level: LogLevel.error,
      message: 'API request failed',
      metadata: <String, dynamic>{
        'traceId': err.requestOptions.extra[kScoutTraceIdKey],
        'path': err.requestOptions.path,
        'method': err.requestOptions.method,
        'statusCode': err.response?.statusCode,
        'waterfallUs': <String, int>{
          'startedAt': start,
          'firstByteAt': firstByte,
          'ttfb': ttfbUs,
          'payloadDownload': payloadUs,
          'total': totalUs,
        },
        'networkWaterfall': <Map<String, dynamic>>[
          <String, dynamic>{'phase': 'ttfb', 'durationUs': ttfbUs},
          <String, dynamic>{'phase': 'payload_download', 'durationUs': payloadUs},
          <String, dynamic>{'phase': 'total', 'durationUs': totalUs},
        ],
        'requestHeaders': PiiScrubber.scrub(err.requestOptions.headers),
        'requestBody': PiiScrubber.scrub(err.requestOptions.data),
        'responseBody': PiiScrubber.scrub(err.response?.data),
      },
      stackTrace: err.stackTrace.toString(),
    );
    handler.next(err);
  }
}
