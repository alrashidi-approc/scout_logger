import 'incident_occurrence_policy.dart';

/// Filters or mutates incident JSON before queue/upload.
typedef BeforeIncidentSend = Map<String, dynamic>? Function(
  Map<String, dynamic> incident,
);

/// Controls volume and richness of product-improvement telemetry.
class ProductInsightsPolicy {
  const ProductInsightsPolicy({
    this.sampleRate = 1.0,
    this.maxIncidentsPerSession = 200,
    this.trackAppLifecycle = true,
    this.beforeIncidentSend,
    this.occurrencePolicy = const IncidentOccurrencePolicy(),
  });

  /// Fraction of WARN/ERROR incidents kept (0–1). FATAL/CRITICAL always kept.
  final double sampleRate;
  final int maxIncidentsPerSession;
  final bool trackAppLifecycle;
  final BeforeIncidentSend? beforeIncidentSend;
  final IncidentOccurrencePolicy occurrencePolicy;
}
