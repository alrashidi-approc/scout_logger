import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/app_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppContainer container = await AppContainer.init();
  runApp(DemoApp(container: container));
}
