import 'package:package_info_plus/package_info_plus.dart';

import '../config/blackbox_app_context.dart';

/// Resolves app version / build / package from the host app automatically.
class AppContextResolver {
  static Future<BlackboxAppContext> resolve({
    BlackboxAppContext? base,
    String? userId,
    String? sessionId,
    Map<String, dynamic>? globalMetadata,
  }) async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    final BlackboxAppContext seed = base ??
        BlackboxAppContext(
          appVersion: info.version,
          buildNumber: info.buildNumber,
          packageName: info.packageName,
        );
    final String resolvedName = _resolveAppName(seed, info.appName);
    return seed.copyWith(
      appVersion: info.version,
      buildNumber: info.buildNumber,
      packageName: info.packageName,
      appName: resolvedName,
      userId: userId ?? seed.userId,
      sessionId: sessionId ?? seed.sessionId,
      globalMetadata: globalMetadata == null
          ? seed.globalMetadata
          : <String, dynamic>{...seed.globalMetadata, ...globalMetadata},
    );
  }

  static String _resolveAppName(BlackboxAppContext seed, String platformAppName) {
    final String? host = seed.appName?.trim();
    if (host != null && host.isNotEmpty) {
      return host;
    }
    final String trimmed = platformAppName.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    return seed.packageName;
  }
}
