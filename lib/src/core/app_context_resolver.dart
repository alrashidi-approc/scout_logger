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
    return seed.copyWith(
      appVersion: info.version,
      buildNumber: info.buildNumber,
      packageName: info.packageName,
      userId: userId ?? seed.userId,
      sessionId: sessionId ?? seed.sessionId,
      globalMetadata: globalMetadata == null
          ? seed.globalMetadata
          : <String, dynamic>{...seed.globalMetadata, ...globalMetadata},
    );
  }
}
