/// Immutable app identity the host passes once at init (blackbox parameters).
class BlackboxAppContext {
  const BlackboxAppContext({
    required this.appVersion,
    required this.buildNumber,
    required this.packageName,
    this.userId,
    this.sessionId,
    this.globalMetadata = const <String, dynamic>{},
    this.userMetadata = const <String, dynamic>{},
  });

  final String appVersion;
  final String buildNumber;
  final String packageName;
  final String? userId;
  final String? sessionId;
  final Map<String, dynamic> globalMetadata;
  /// Per-user extras from [ScoutLogger.bindUser] (tenant, role, branch, …).
  final Map<String, dynamic> userMetadata;

  BlackboxAppContext copyWith({
    String? appVersion,
    String? buildNumber,
    String? packageName,
    String? userId,
    String? sessionId,
    Map<String, dynamic>? globalMetadata,
    Map<String, dynamic>? userMetadata,
  }) {
    return BlackboxAppContext(
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      packageName: packageName ?? this.packageName,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      globalMetadata: globalMetadata ?? this.globalMetadata,
      userMetadata: userMetadata ?? this.userMetadata,
    );
  }
}
