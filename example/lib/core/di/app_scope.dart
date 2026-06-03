import 'package:flutter/widgets.dart';

import 'app_container.dart';

/// Exposes [AppContainer] to the widget tree (like a lightweight service locator).
class AppScope extends InheritedWidget {
  const AppScope({
    required this.container,
    required super.child,
    super.key,
  });

  final AppContainer container;

  static AppContainer of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw StateError('AppScope not found. Wrap MaterialApp with AppScope.');
    }
    return scope.container;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => container != oldWidget.container;
}
