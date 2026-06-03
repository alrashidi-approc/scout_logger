import 'package:scout_logger/scout_logger.dart';

import '../bootstrap/scout_bootstrap.dart';
import '../logging/demo_log_hub.dart';
import '../network/api_client.dart';
import '../../features/demo/data/demo_repository.dart';

/// Application-wide dependencies (init once in [main]).
class AppContainer {
  AppContainer._({
    required this.logger,
    required this.apiClient,
    required this.hub,
    required this.demoRepository,
  });

  final ScoutLogger logger;
  final ApiClient apiClient;
  final DemoLogHub hub;
  final DemoRepository demoRepository;

  static AppContainer? _instance;

  static AppContainer get instance {
    final AppContainer? value = _instance;
    if (value == null) {
      throw StateError('Call AppContainer.init() before using the app.');
    }
    return value;
  }

  static Future<AppContainer> init() async {
    if (_instance != null) {
      return _instance!;
    }

    final DemoLogHub hub = DemoLogHub.instance;
    final ScoutLogger logger = await ScoutBootstrap.init(hub);
    final ApiClient apiClient = ApiClient.create(logger);
    final DemoRepository demoRepository = DemoRepository(
      logger: logger,
      apiClient: apiClient,
      hub: hub,
    );

    _instance = AppContainer._(
      logger: logger,
      apiClient: apiClient,
      hub: hub,
      demoRepository: demoRepository,
    );

    hub.status(
      'Blackbox ready — network: errorsOnly (401/403/404 ignored); ERROR+ → incident JSON',
    );

    return _instance!;
  }
}
