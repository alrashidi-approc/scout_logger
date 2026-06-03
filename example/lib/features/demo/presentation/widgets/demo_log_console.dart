import 'package:flutter/material.dart';

import '../../../../core/logging/demo_log_hub.dart';
import 'demo_log_tile.dart';

class DemoLogConsole extends StatelessWidget {
  const DemoLogConsole({required this.hub, super.key});

  final DemoLogHub hub;

  @override
  Widget build(BuildContext context) {
    if (hub.entries.isEmpty) {
      return Center(
        child: Text(
          'Handler output appears here\n(batch uploads, urgent webhooks, status)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: hub.entries.length,
      itemBuilder: (BuildContext context, int index) {
        return DemoLogTile(entry: hub.entries[index]);
      },
    );
  }
}
