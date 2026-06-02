/// How the host app wants logs delivered to backend servers.
enum LogDispatchMode {
  /// Queue encrypted logs; upload in batches (count + time window).
  chronoBatch,

  /// Upload each log individually as soon as possible (still queued if offline).
  perLog,
}

class LogDispatchPolicy {
  const LogDispatchPolicy({
    this.mode = LogDispatchMode.chronoBatch,
    this.batchSize = 50,
    this.batchWindow = const Duration(seconds: 120),
    this.wifiOnlySync = false,
    this.maxRetryBackoffSeconds = 300,
  });

  final LogDispatchMode mode;
  final int batchSize;
  final Duration batchWindow;
  final bool wifiOnlySync;
  final int maxRetryBackoffSeconds;
}
