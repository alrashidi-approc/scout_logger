import 'package:flutter/material.dart';

import '../../../../core/di/app_scope.dart';
import '../../../../core/logging/demo_log_hub.dart';
import '../widgets/demo_action_panel.dart';
import '../widgets/demo_log_console.dart';
import '../widgets/demo_stats_bar.dart';

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  DemoLogHub? _hub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final DemoLogHub hub = AppScope.of(context).hub;
    if (_hub == hub) {
      return;
    }
    _hub?.removeListener(_onHubChanged);
    _hub = hub;
    _hub!.addListener(_onHubChanged);
  }

  @override
  void dispose() {
    _hub?.removeListener(_onHubChanged);
    super.dispose();
  }

  void _onHubChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final container = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scout App Logger'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Clear console',
            onPressed: container.hub.clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          DemoStatsBar(hub: container.hub),
          const Divider(height: 1),
          Expanded(child: DemoLogConsole(hub: container.hub)),
          const Divider(height: 1),
          DemoActionPanel(repository: container.demoRepository),
        ],
      ),
    );
  }
}
