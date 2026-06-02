import 'dart:collection';
import 'dart:convert';

import '../models/log_models.dart';

class BreadcrumbStore {
  BreadcrumbStore({required int maxEntries})
      : _maxEntries = maxEntries,
        _queue = ListQueue<Breadcrumb>(maxEntries);

  final int _maxEntries;
  final ListQueue<Breadcrumb> _queue;

  void add(Breadcrumb breadcrumb) {
    if (_queue.length == _maxEntries) {
      _queue.removeFirst();
    }
    _queue.addLast(breadcrumb);
  }

  String? currentRouteHint() {
    for (final Breadcrumb breadcrumb in _queue.toList().reversed) {
      if (breadcrumb.label.startsWith('NAV_')) {
        final Object? route = breadcrumb.metadata['to'];
        if (route is String && route.isNotEmpty) {
          return route;
        }
      }
    }
    return null;
  }

  List<Breadcrumb> deepCopy() {
    final String encoded = jsonEncode(_queue.map((b) => b.toJson()).toList());
    final List<dynamic> decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .map(
          (item) => Breadcrumb(
            label: item['label'] as String,
            timestamp: DateTime.parse(item['timestamp'] as String),
            metadata: Map<String, dynamic>.from(
              item['metadata'] as Map<String, dynamic>? ?? <String, dynamic>{},
            ),
          ),
        )
        .toList(growable: false);
  }
}
