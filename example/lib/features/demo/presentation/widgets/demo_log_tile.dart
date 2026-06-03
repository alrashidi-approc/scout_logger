import 'package:flutter/material.dart';

import '../../../../core/logging/demo_log_entry.dart';

class DemoLogTile extends StatelessWidget {
  const DemoLogTile({required this.entry, super.key});

  final DemoLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = switch (entry.channel) {
      'emergency' => colors.error,
      'batch' => colors.primary,
      _ => colors.tertiary,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.15),
          child: Icon(_iconFor(entry.channel), color: accent, size: 20),
        ),
        title: Text(entry.summary, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          <String>[
            _formatTime(entry.at),
            if (entry.metadataPreview != null) entry.metadataPreview!,
            if (entry.envelope?.message != null) entry.envelope!.message,
          ].join('\n'),
        ),
        isThreeLine: entry.metadataPreview != null || entry.envelope != null,
      ),
    );
  }

  IconData _iconFor(String channel) => switch (channel) {
        'emergency' => Icons.warning_amber_rounded,
        'batch' => Icons.inventory_2_outlined,
        _ => Icons.info_outline,
      };

  String _formatTime(DateTime value) {
    final String h = value.hour.toString().padLeft(2, '0');
    final String m = value.minute.toString().padLeft(2, '0');
    final String s = value.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
