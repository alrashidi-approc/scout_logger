import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'network_timing_keys.dart';

class TimedHttpClientAdapter implements HttpClientAdapter {
  TimedHttpClientAdapter(
    this._inner, {
    int Function()? nowMicros,
  }) : _nowMicros = nowMicros ?? (() => DateTime.now().microsecondsSinceEpoch);

  final HttpClientAdapter _inner;
  final int Function() _nowMicros;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    options.extra.putIfAbsent(kScoutStartUsKey, _nowMicros);
    final ResponseBody response =
        await _inner.fetch(options, requestStream, cancelFuture);
    int? firstByteUs;

    response.stream = response.stream.transform(
      StreamTransformer<Uint8List, Uint8List>.fromHandlers(
        handleData: (Uint8List chunk, EventSink<Uint8List> sink) {
          firstByteUs ??= _nowMicros();
          response.extra[kScoutFirstByteUsKey] = firstByteUs;
          sink.add(chunk);
        },
        handleError: (Object error, StackTrace stack, EventSink<Uint8List> sink) {
          final int doneAt = _nowMicros();
          response.extra[kScoutFirstByteUsKey] ??= doneAt;
          response.extra[kScoutResponseDoneUsKey] = doneAt;
          sink.addError(error, stack);
        },
        handleDone: (EventSink<Uint8List> sink) {
          final int doneAt = _nowMicros();
          response.extra[kScoutFirstByteUsKey] ??= doneAt;
          response.extra[kScoutResponseDoneUsKey] = doneAt;
          sink.close();
        },
      ),
    );

    return response;
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
