import 'package:flutter/material.dart';
import 'package:scout_logger/scout_logger.dart';

import '../../data/demo_repository.dart';
import 'demo_button.dart';

class DemoActionPanel extends StatelessWidget {
  const DemoActionPanel({required this.repository, super.key});

  final DemoRepository repository;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Try the SDK', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  DemoButton(
                    icon: Icons.navigation_outlined,
                    label: 'UI trail',
                    onPressed: () => repository.runNavigationFlow(context),
                  ),
                  DemoButton(
                    icon: Icons.cloud_outlined,
                    label: 'Network OK',
                    onPressed: repository.networkSuccess,
                  ),
                  DemoButton(
                    icon: Icons.cloud_off_outlined,
                    label: 'Network err',
                    onPressed: repository.networkServerError,
                  ),
                  DemoButton(
                    icon: Icons.lock_outline,
                    label: '401 ignored',
                    onPressed: repository.networkIgnored401,
                  ),
                  DemoButton(
                    icon: Icons.security,
                    label: 'PII scrub',
                    onPressed: repository.networkPiiScrubDemo,
                  ),
                  DemoButton(
                    icon: Icons.queue,
                    label: 'Fill batch',
                    onPressed: repository.fillBatch,
                  ),
                  DemoButton(
                    icon: Icons.error_outline,
                    label: 'Error + vitals',
                    onPressed: repository.logSimulatedError,
                  ),
                  DemoButton(
                    icon: Icons.bolt,
                    label: 'Fatal urgent',
                    onPressed: repository.logSimulatedFatal,
                  ),
                  DemoButton(
                    icon: Icons.replay,
                    label: 'Fail urgent',
                    onPressed: () {
                      repository.armFailNextUrgent();
                      repository.logSimulatedFatal();
                    },
                  ),
                  DemoButton(
                    icon: Icons.block,
                    label: 'Fail batch',
                    onPressed: repository.armFailNextBatch,
                  ),
                  DemoButton(
                    icon: Icons.tune,
                    label: 'Level: warn',
                    onPressed: () => repository.setRemoteMinLevel(LogLevel.warn),
                  ),
                  DemoButton(
                    icon: Icons.tune,
                    label: 'Level: debug',
                    onPressed: () => repository.setRemoteMinLevel(LogLevel.debug),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
