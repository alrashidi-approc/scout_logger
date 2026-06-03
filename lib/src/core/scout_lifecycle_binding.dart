import 'package:flutter/widgets.dart';

import '../models/log_models.dart';
import 'breadcrumbs.dart';

/// Records app foreground/background/pause for incident user-flow context.
class ScoutLifecycleBinding with WidgetsBindingObserver {
  ScoutLifecycleBinding(this._store);

  final BreadcrumbStore _store;

  void install() => WidgetsBinding.instance.addObserver(this);

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _store.add(
      Breadcrumb(
        label: 'APP_${state.name.toUpperCase()}',
        timestamp: DateTime.now(),
        metadata: <String, dynamic>{'state': state.name},
      ),
    );
  }
}
