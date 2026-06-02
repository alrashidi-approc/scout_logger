import 'package:dio/dio.dart';

import '../core/scout_logger_manager.dart';
import '../core/smart_dio_interceptor.dart';
import '../core/timed_http_client_adapter.dart';

extension ScoutDioExtension on Dio {
  void attachScoutLogger(ScoutLogger logger) {
    if (httpClientAdapter is! TimedHttpClientAdapter) {
      httpClientAdapter = TimedHttpClientAdapter(httpClientAdapter);
    }
    interceptors.add(SmartDioInterceptor.fromLogger(logger));
  }
}
