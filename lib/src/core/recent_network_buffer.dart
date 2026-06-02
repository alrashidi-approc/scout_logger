class RecentNetworkBuffer {
  RecentNetworkBuffer({this.maxEntries = 8});

  final int maxEntries;
  final List<Map<String, dynamic>> _entries = <Map<String, dynamic>>[];

  void record(Map<String, dynamic> summary) {
    _entries.add(summary);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }

  List<Map<String, dynamic>> snapshot() =>
      List<Map<String, dynamic>>.unmodifiable(_entries);
}
