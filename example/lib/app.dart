import 'package:flutter/material.dart';

import 'core/di/app_container.dart';
import 'core/di/app_scope.dart';
import 'features/demo/presentation/pages/demo_checkout_page.dart';
import 'features/demo/presentation/pages/demo_details_page.dart';
import 'features/demo/presentation/pages/demo_home_page.dart';

class DemoApp extends StatelessWidget {
  const DemoApp({required this.container, super.key});

  final AppContainer container;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      container: container,
      child: MaterialApp(
        title: 'Scout App Logger Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
          useMaterial3: true,
        ),
        navigatorObservers: <NavigatorObserver>[container.logger.navigatorObserver],
        home: const DemoHomePage(),
        routes: <String, WidgetBuilder>{
          '/details': (_) => const DemoDetailsPage(),
          '/checkout': (_) => const DemoCheckoutPage(),
        },
      ),
    );
  }
}
