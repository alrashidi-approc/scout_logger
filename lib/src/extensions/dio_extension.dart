import 'package:dio/dio.dart';

import '../core/network_timing_keys.dart';
import '../core/scout_logger_manager.dart';
import '../core/smart_dio_interceptor.dart';
import '../core/timed_http_client_adapter.dart';

/// App fields attached to a Dio call and merged into incident `custom` only.
extension ScoutRequestOptionsExtension on RequestOptions {
  set scoutIncidentCustom(Map<String, dynamic> value) {
    extra[kScoutIncidentCustomKey] = value;
  }

  Map<String, dynamic> get scoutIncidentCustom {
    final dynamic raw = extra[kScoutIncidentCustomKey];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return const <String, dynamic>{};
  }
}

extension ScoutDioExtension on Dio {
  void attachScoutLogger(ScoutLogger logger) {
    if (httpClientAdapter is! TimedHttpClientAdapter) {
      httpClientAdapter = TimedHttpClientAdapter(httpClientAdapter);
    }
    interceptors.add(SmartDioInterceptor.fromLogger(logger));
  }
}
