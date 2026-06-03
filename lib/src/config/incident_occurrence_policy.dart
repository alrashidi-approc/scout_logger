/// Suppresses repeat uploads/emails for the same [groupingKey]; sends rollups with counts.
class IncidentOccurrencePolicy {
  const IncidentOccurrencePolicy({
    this.enabled = true,
    this.rollupCooldown = const Duration(minutes: 15),
    this.suppressDuplicateUpload = true,
    this.suppressDuplicateUrgent = true,
  });

  final bool enabled;
  final Duration rollupCooldown;
  final bool suppressDuplicateUpload;
  final bool suppressDuplicateUrgent;
}
