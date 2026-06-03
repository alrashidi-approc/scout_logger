/// Mutable tags and contexts attached to every incident (Sentry-style scope).
class IncidentScope {
  final Map<String, String> tags = <String, String>{};
  final Map<String, Map<String, dynamic>> contexts =
      <String, Map<String, dynamic>>{};

  void setTag(String key, String value) => tags[key] = value;

  void removeTag(String key) => tags.remove(key);

  void setContext(String name, Map<String, dynamic> data) {
    contexts[name] = Map<String, dynamic>.from(data);
  }

  void removeContext(String name) => contexts.remove(name);

  void clear() {
    tags.clear();
    contexts.clear();
  }

  Map<String, String> snapshotTags() => Map<String, String>.from(tags);

  Map<String, Map<String, dynamic>> snapshotContexts() => contexts.map(
        (String key, Map<String, dynamic> value) =>
            MapEntry<String, Map<String, dynamic>>(
          key,
          Map<String, dynamic>.from(value),
        ),
      );
}
