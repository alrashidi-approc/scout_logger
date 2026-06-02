import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivitySnapshot {
  const ConnectivitySnapshot({
    required this.types,
    required this.isOnline,
  });

  final List<String> types;
  final bool isOnline;

  static Future<ConnectivitySnapshot> capture() async {
    final List<ConnectivityResult> results = await Connectivity().checkConnectivity();
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
