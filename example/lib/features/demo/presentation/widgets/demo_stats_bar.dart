import 'package:flutter/material.dart';

import '../../../../core/logging/demo_log_hub.dart';

class DemoStatsBar extends StatelessWidget {
  const DemoStatsBar({required this.hub, super.key});

  final DemoLogHub hub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          _StatChip(
            icon: Icons.cloud_upload_outlined,
            label: 'Batches',
            value: '${hub.batchUploadCount}',
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.bolt,
            label: 'Urgent',
            value: '${hub.emergencyCount}',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Batch: 5 logs or 15s · encrypted queue · PII scrub · breadcrumbs',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}
