/// Immutable app identity the host passes once at init (blackbox parameters).
class BlackboxAppContext {
  const BlackboxAppContext({
    required this.appVersion,
    required this.buildNumber,
    required this.packageName,
    this.appName,
    this.userId,
    this.sessionId,
    this.globalMetadata = const <String, dynamic>{},
    this.userMetadata = const <String, dynamic>{},
  });

  final String appVersion;
  final String buildNumber;
  final String packageName;
  /// Human-readable app label for backend routing (e.g. `Diyar Wallet`).
  /// When null, [displayName] falls back to [packageName].
  final String? appName;
  final String? userId;

  /// Value sent as `app.name` on every incident — use this to group logs per app.
  String get displayName =>
      (appName != null && appName!.trim().isNotEmpty) ? appName!.trim() : packageName;
  final String? sessionId;
  final Map<String, dynamic> globalMetadata;
  /// Per-user extras from [ScoutLogger.bindUser] (tenant, role, branch, …).
  final Map<String, dynamic> userMetadata;

  BlackboxAppContext copyWith({
    String? appVersion,
    String? buildNumber,
    String? packageName,
    String? appName,
    String? userId,
    String? sessionId,
    Map<String, dynamic>? globalMetadata,
    Map<String, dynamic>? userMetadata,
  }) {
    return BlackboxAppContext(
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      globalMetadata: globalMetadata ?? this.globalMetadata,
      userMetadata: userMetadata ?? this.userMetadata,
    );
  }
}
