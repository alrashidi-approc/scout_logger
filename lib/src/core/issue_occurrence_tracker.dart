import '../config/incident_occurrence_policy.dart';

enum IncidentDispatchReason { first, rollup, suppressed }

class IncidentOccurrenceDecision {
  const IncidentOccurrenceDecision({
    required this.reason,
    required this.totalCount,
    required this.pendingSinceLastReport,
    this.firstSeenAt,
    this.lastSeenAt,
  });

  final IncidentDispatchReason reason;
  final int totalCount;
  final int pendingSinceLastReport;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;

  bool get shouldUpload => reason != IncidentDispatchReason.suppressed;
  bool get isRollup => reason == IncidentDispatchReason.rollup;
}

class _IssueRecord {
  _IssueRecord({required this.firstSeenAt}) : lastSeenAt = firstSeenAt;

  int totalCount = 0;
  int pendingSinceLastReport = 0;
  DateTime firstSeenAt;
  DateTime lastSeenAt;
  DateTime? lastDispatchedAt;
}

/// In-session registry keyed by [groupingKey].
class IssueOccurrenceTracker {
  IssueOccurrenceTracker({IncidentOccurrencePolicy policy = const IncidentOccurrencePolicy()})
      : _policy = policy;

  final IncidentOccurrencePolicy _policy;
  final Map<String, _IssueRecord> _records = <String, _IssueRecord>{};

  IncidentOccurrenceDecision evaluate({
    required String groupingKey,
    required DateTime now,
  }) {
    if (!_policy.enabled) {
      return IncidentOccurrenceDecision(
        reason: IncidentDispatchReason.first,
        totalCount: 1,
        pendingSinceLastReport: 1,
        firstSeenAt: now,
        lastSeenAt: now,
      );
    }

    final _IssueRecord record = _records.putIfAbsent(
      groupingKey,
      () => _IssueRecord(firstSeenAt: now),
    );
    record.totalCount++;
    record.pendingSinceLastReport++;
    record.lastSeenAt = now;

    if (record.totalCount == 1) {
      record.lastDispatchedAt = now;
      record.pendingSinceLastReport = 0;
      return IncidentOccurrenceDecision(
        reason: IncidentDispatchReason.first,
        totalCount: 1,
        pendingSinceLastReport: 1,
        firstSeenAt: record.firstSeenAt,
        lastSeenAt: record.lastSeenAt,
      );
    }

    final DateTime? lastDispatch = record.lastDispatchedAt;
    final bool rollupDue = lastDispatch == null ||
        now.difference(lastDispatch) >= _policy.rollupCooldown;

    if (rollupDue) {
      final int pending = record.pendingSinceLastReport;
      record.lastDispatchedAt = now;
      record.pendingSinceLastReport = 0;
      return IncidentOccurrenceDecision(
        reason: IncidentDispatchReason.rollup,
        totalCount: record.totalCount,
        pendingSinceLastReport: pending,
        firstSeenAt: record.firstSeenAt,
        lastSeenAt: record.lastSeenAt,
      );
    }

    if (_policy.suppressDuplicateUpload) {
      return IncidentOccurrenceDecision(
        reason: IncidentDispatchReason.suppressed,
        totalCount: record.totalCount,
        pendingSinceLastReport: record.pendingSinceLastReport,
        firstSeenAt: record.firstSeenAt,
        lastSeenAt: record.lastSeenAt,
      );
    }

    final int pending = record.pendingSinceLastReport;
    record.lastDispatchedAt = now;
    record.pendingSinceLastReport = 0;
    return IncidentOccurrenceDecision(
      reason: IncidentDispatchReason.rollup,
      totalCount: record.totalCount,
      pendingSinceLastReport: pending,
      firstSeenAt: record.firstSeenAt,
      lastSeenAt: record.lastSeenAt,
    );
  }

  bool shouldSendUrgent({
    required String groupingKey,
    required IncidentOccurrenceDecision decision,
  }) {
    if (!_policy.enabled || !_policy.suppressDuplicateUrgent) {
      return decision.shouldUpload;
    }
    return decision.reason == IncidentDispatchReason.first;
  }
}
