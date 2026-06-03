import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/log_models.dart';

/// Builds human-readable fingerprint components for dashboards and alerts.
List<String> buildFingerprint({
  required LogCategory category,
  required String message,
  String? stackTrace,
  Map<String, String> tags = const <String, String>{},
}) {
  final List<String> parts = <String>[
    category.name,
    _normalizeMessage(message),
  ];
  final String? frame = _topStackFrame(stackTrace);
  if (frame != null) {
    parts.add(frame);
  }
  for (final MapEntry<String, String> tag in tags.entries) {
    parts.add('${tag.key}:${tag.value}');
  }
  return parts;
}

/// Stable hash for backend dedupe/grouping (same inputs → same key).
String computeGroupingKey({
  required String message,
  String? stackTrace,
  List<String> fingerprint = const <String>[],
}) {
  final String normalizedStack = _normalizeStack(stackTrace ?? '');
  final String payload =
      '$message|$normalizedStack|${fingerprint.join('|')}';
  return sha256.convert(utf8.encode(payload)).toString();
}

String _normalizeMessage(String message) {
  final String trimmed = message.trim();
  if (trimmed.length <= 120) {
    return trimmed;
  }
  return trimmed.substring(0, 120);
}

String _normalizeStack(String stack) {
  return stack
      .split('\n')
      .take(8)
      .map((String line) => line.replaceAll(RegExp(r':\d+'), ':N'))
      .join('\n');
}

String? _topStackFrame(String? stackTrace) {
  if (stackTrace == null || stackTrace.isEmpty) {
    return null;
  }
  for (final String line in stackTrace.split('\n')) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    return trimmed.length <= 160 ? trimmed : trimmed.substring(0, 160);
  }
  return null;
}
