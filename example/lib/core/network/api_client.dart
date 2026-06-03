import 'package:dio/dio.dart';
import 'package:scout_logger/scout_logger.dart';

/// Shared Dio for the demo app — mirrors production `core/network/api_client.dart`.
class ApiClient {
  ApiClient._(this.dio);

  final Dio dio;

  static ApiClient create(ScoutLogger logger) {
    final Dio dio = Dio(
      BaseOptions(connectTimeout: const Duration(seconds: 12)),
    );
    dio.attachScoutLogger(logger);
    return ApiClient._(dio);
  }
}
