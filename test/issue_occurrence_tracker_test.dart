import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/config/incident_occurrence_policy.dart';
import 'package:scout_logger/src/core/issue_occurrence_tracker.dart';

void main() {
  test('first occurrence uploads once', () {
    final IssueOccurrenceTracker tracker = IssueOccurrenceTracker();
    final DateTime t0 = DateTime(2026, 1, 1, 12);

    final IncidentOccurrenceDecision first = tracker.evaluate(
      groupingKey: 'payment|error',
      now: t0,
    );

    expect(first.reason, IncidentDispatchReason.first);
    expect(first.totalCount, 1);
    expect(first.shouldUpload, isTrue);
  });

  test('repeats suppressed until rollup cooldown', () {
    final IssueOccurrenceTracker tracker = IssueOccurrenceTracker(
      policy: const IncidentOccurrencePolicy(rollupCooldown: Duration(minutes: 15)),
    );
    final DateTime t0 = DateTime(2026, 1, 1, 12);

    tracker.evaluate(groupingKey: 'k', now: t0);
    final IncidentOccurrenceDecision dup = tracker.evaluate(
      groupingKey: 'k',
      now: t0.add(const Duration(seconds: 5)),
    );

    expect(dup.reason, IncidentDispatchReason.suppressed);
    expect(dup.totalCount, 2);
    expect(dup.shouldUpload, isFalse);
  });

  test('rollup sends count after cooldown', () {
    final IssueOccurrenceTracker tracker = IssueOccurrenceTracker(
      policy: const IncidentOccurrencePolicy(rollupCooldown: Duration(minutes: 15)),
    );
    final DateTime t0 = DateTime(2026, 1, 1, 12);

    tracker.evaluate(groupingKey: 'k', now: t0);
    tracker.evaluate(groupingKey: 'k', now: t0.add(const Duration(minutes: 1)));
    final IncidentOccurrenceDecision rollup = tracker.evaluate(
      groupingKey: 'k',
      now: t0.add(const Duration(minutes: 16)),
    );

    expect(rollup.reason, IncidentDispatchReason.rollup);
    expect(rollup.totalCount, 3);
    expect(rollup.pendingSinceLastReport, 2);
    expect(rollup.shouldUpload, isTrue);
  });

  test('urgent only on first when suppressDuplicateUrgent', () {
    final IssueOccurrenceTracker tracker = IssueOccurrenceTracker(
      policy: const IncidentOccurrencePolicy(suppressDuplicateUrgent: true),
    );
    final DateTime t0 = DateTime(2026, 1, 1, 12);

    final IncidentOccurrenceDecision first = tracker.evaluate(groupingKey: 'k', now: t0);
    final IncidentOccurrenceDecision rollup = tracker.evaluate(
      groupingKey: 'k',
      now: t0.add(const Duration(hours: 1)),
    );

    expect(tracker.shouldSendUrgent(groupingKey: 'k', decision: first), isTrue);
    expect(tracker.shouldSendUrgent(groupingKey: 'k', decision: rollup), isFalse);
  });
}
