import 'package:flutter/widgets.dart';

import '../models/log_models.dart';
import 'breadcrumbs.dart';

class SmartUIObserver extends NavigatorObserver {
  SmartUIObserver(this._store);

  final BreadcrumbStore _store;

  void addManualBreadcrumb(String label, {Map<String, dynamic>? metadata}) {
    _store.add(
      Breadcrumb(
        label: label,
        timestamp: DateTime.now(),
        metadata: metadata ?? const <String, dynamic>{},
      ),
    );
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    addManualBreadcrumb(
      'NAV_PUSH',
      metadata: <String, dynamic>{
        'from': previousRoute?.settings.name,
        'to': route.settings.name,
      },
    );
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    addManualBreadcrumb(
      'NAV_POP',
      metadata: <String, dynamic>{
        'from': route.settings.name,
        'to': previousRoute?.settings.name,
      },
    );
    super.didPop(route, previousRoute);
  }
}
