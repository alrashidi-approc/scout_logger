import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/core/network_timing_keys.dart';
import 'package:scout_logger/src/core/timed_http_client_adapter.dart';

void main() {
  test('captures first-byte and completion timestamps from response stream', () async {
    final List<int> ticks = <int>[1000, 1100, 1300];
    final TimedHttpClientAdapter adapter = TimedHttpClientAdapter(
      _FakeAdapter(
        streamFactory: () async* {
          yield Uint8List.fromList(<int>[1, 2]);
          yield Uint8List.fromList(<int>[3]);
        },
      ),
      nowMicros: () => ticks.removeAt(0),
    );
    final RequestOptions options = RequestOptions(path: '/timed');

    final ResponseBody response = await adapter.fetch(options, null, null);
    await response.stream.fold<List<int>>(<int>[], (List<int> out, Uint8List chunk) {
      out.addAll(chunk);
      return out;
    });

    expect(options.extra[kScoutStartUsKey], 1000);
    expect(response.extra[kScoutFirstByteUsKey], 1100);
    expect(response.extra[kScoutResponseDoneUsKey], 1300);
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.streamFactory});

  final Stream<Uint8List> Function() streamFactory;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(streamFactory(), 200);
  }

  @override
  void close({bool force = false}) {}
}
