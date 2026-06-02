import 'package:flutter_test/flutter_test.dart';
import 'package:scout_logger/src/core/crash_hooks.dart';
import 'package:scout_logger/src/models/log_models.dart';

void main() {
  test('deduplicates identical crashes in short window', () async {
    DateTime now = DateTime(2026, 6, 2, 12, 0, 0);
    int emitted = 0;
    final CrashHooks hooks = CrashHooks(
      ({
        required Domain domain,
        required LogCategory category,
        required LogLevel level,
        required String message,
        Map<String, dynamic> metadata = const <String, dynamic>{},
        String? stackTrace,
        bool immediateDispatch = false,
      }) async {
        emitted++;
      },
      nowProvider: () => now,
    );

    await hooks.recordForTest(message: 'boom', stackTrace: 'stack');
    await hooks.recordForTest(message: 'boom', stackTrace: 'stack');
    now = now.add(const Duration(seconds: 3));
    await hooks.recordForTest(message: 'boom', stackTrace: 'stack');

    expect(emitted, 2);
  });
}
