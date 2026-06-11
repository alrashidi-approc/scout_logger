import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/connectivity_checker.dart';

class ConnectivitySnapshot {
  const ConnectivitySnapshot({
    required this.types,
    required this.isOnline,
  });

  final List<String> types;
  final bool isOnline;

  static Future<ConnectivitySnapshot> capture({
    ConnectivityChecker? checker,
  }) async {
    final Future<List<ConnectivityResult>> Function() check =
        checker ?? () => Connectivity().checkConnectivity();
    final List<ConnectivityResult> results = await check();
    final List<String> types = results.map((ConnectivityResult r) => r.name).toList();
    return ConnectivitySnapshot(
      types: types,
      isOnline: !results.contains(ConnectivityResult.none),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'types': types,
        'isOnline': isOnline,
      };
}
