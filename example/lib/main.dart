import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:scout_logger/scout_logger.dart';

import 'demo_log_hub.dart';

late final ScoutLogger logger;
late final Dio dio;
final DemoLogHub hub = DemoLogHub.instance;
final Random _rng = Random();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logger = await ScoutAppLogger.init(
    ScoutLoggerConfig.blackbox(
      flavor: 'demo',
      autoResolveAppInfo: true,
      appContext: const BlackboxAppContext(
        appVersion: '0.0.0',
        buildNumber: '0',
        packageName: 'com.scoutlogger.demo',
        globalMetadata: <String, dynamic>{'demo': true},
      ),
      dispatchPolicy: const LogDispatchPolicy(
        mode: LogDispatchMode.chronoBatch,
        batchSize: 5,
        batchWindow: Duration(seconds: 15),
      ),
      encryptionKey: 'demo_encryption_key_change_in_production',
      minimumLevel: LogLevel.debug,
      onBatchIncidents: hub.handleBatchJson,
      onUrgentIncident: hub.handleUrgentJson,
      // emailReporting: EmailReportingConfig.gmail(
      //   username: 'alerts@company.com',
      //   appPassword: 'your-gmail-app-password',
      //   fromAddress: 'alerts@company.com',
      //   toAddresses: <String>['team@company.com'],
      //   levels: <LogLevel>{LogLevel.error, LogLevel.fatal},
      // ),
      runtimeVitalsProbe: () async => <String, dynamic>{
        'batteryLevel': 55 + _rng.nextInt(40).toDouble(),
        'chargingState': _rng.nextBool() ? 'charging' : 'unplugged',
        'thermalState': 'nominal',
        'freeRamBytes': 200000000 + _rng.nextInt(100000000),
      },
    ),
  );
  logger.bindUser(
    userId: 'demo-user-1',
    sessionId: 'demo-session',
    metadata: <String, dynamic>{'tenant': 'demo', 'role': 'tester'},
  );
  dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12)));
  dio.attachScoutLogger(logger);
  hub.status('Blackbox ready — each ERROR+ emits one full incident JSON');
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scout App Logger Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      navigatorObservers: <NavigatorObserver>[logger.navigatorObserver],
      home: const DemoHomePage(),
      routes: <String, WidgetBuilder>{
        '/details': (_) => const DemoDetailsPage(),
        '/checkout': (_) => const DemoCheckoutPage(),
      },
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  @override
  void initState() {
    super.initState();
    hub.addListener(_onHubChanged);
  }

  @override
  void dispose() {
    hub.removeListener(_onHubChanged);
    super.dispose();
  }

  void _onHubChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scout App Logger'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Clear console',
            onPressed: hub.clear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _StatsBar(),
          const Divider(height: 1),
          Expanded(child: _LogConsole()),
          const Divider(height: 1),
          _ActionPanel(),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          _StatChip(
            icon: Icons.cloud_upload_outlined,
            label: 'Batches',
            value: '${hub.batchUploadCount}',
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: Icons.bolt,
            label: 'Urgent',
            value: '${hub.emergencyCount}',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Batch: 5 logs or 15s · encrypted queue · PII scrub · breadcrumbs',
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text('$label $value'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _LogConsole extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (hub.entries.isEmpty) {
      return Center(
        child: Text(
          'Handler output appears here\n(batch uploads, urgent webhooks, status)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: hub.entries.length,
      itemBuilder: (BuildContext context, int index) {
        final DemoLogEntry entry = hub.entries[index];
        return _LogTile(entry: entry);
      },
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final DemoLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = switch (entry.channel) {
      'emergency' => colors.error,
      'batch' => colors.primary,
      _ => colors.tertiary,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.15),
          child: Icon(_iconFor(entry.channel), color: accent, size: 20),
        ),
        title: Text(entry.summary, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          <String>[
            _formatTime(entry.at),
            if (entry.metadataPreview != null) entry.metadataPreview!,
            if (entry.envelope?.message != null) entry.envelope!.message,
          ].join('\n'),
        ),
        isThreeLine: entry.metadataPreview != null || entry.envelope != null,
      ),
    );
  }

  IconData _iconFor(String channel) => switch (channel) {
        'emergency' => Icons.warning_amber_rounded,
        'batch' => Icons.inventory_2_outlined,
        _ => Icons.info_outline,
      };

  String _formatTime(DateTime value) {
    final String h = value.hour.toString().padLeft(2, '0');
    final String m = value.minute.toString().padLeft(2, '0');
    final String s = value.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

class _ActionPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Try the SDK', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _DemoButton(
                    icon: Icons.navigation_outlined,
                    label: 'UI trail',
                    onPressed: () => _navFlow(context),
                  ),
                  _DemoButton(
                    icon: Icons.cloud_outlined,
                    label: 'Network OK',
                    onPressed: _networkSuccess,
                  ),
                  _DemoButton(
                    icon: Icons.cloud_off_outlined,
                    label: 'Network err',
                    onPressed: _networkError,
                  ),
                  _DemoButton(
                    icon: Icons.security,
                    label: 'PII scrub',
                    onPressed: _networkPii,
                  ),
                  _DemoButton(
                    icon: Icons.queue,
                    label: 'Fill batch',
                    onPressed: _fillBatch,
                  ),
                  _DemoButton(
                    icon: Icons.error_outline,
                    label: 'Error + vitals',
                    onPressed: _logError,
                  ),
                  _DemoButton(
                    icon: Icons.bolt,
                    label: 'Fatal urgent',
                    onPressed: _logFatal,
                  ),
                  _DemoButton(
                    icon: Icons.replay,
                    label: 'Fail urgent',
                    onPressed: () {
                      hub.failNextEmergency = true;
                      _logFatal();
                    },
                  ),
                  _DemoButton(
                    icon: Icons.block,
                    label: 'Fail batch',
                    onPressed: () {
                      hub.failNextBatch = true;
                      hub.status('Next batch upload will fail (then retry)');
                    },
                  ),
                  _DemoButton(
                    icon: Icons.tune,
                    label: 'Level: warn',
                    onPressed: () async {
                      await logger.updateLogLevelsRemote(minimumLevel: LogLevel.warn);
                      hub.status('Remote min level → WARN (info/debug dropped)');
                    },
                  ),
                  _DemoButton(
                    icon: Icons.tune,
                    label: 'Level: debug',
                    onPressed: () async {
                      await logger.updateLogLevelsRemote(minimumLevel: LogLevel.debug);
                      hub.status('Remote min level → DEBUG');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _navFlow(BuildContext context) async {
    logger.navigatorObserver.addManualBreadcrumb('DEMO_TAP', metadata: <String, dynamic>{'screen': 'home'});
    final NavigatorState nav = Navigator.of(context);
    await nav.pushNamed('/details');
    await nav.pushNamed('/checkout');
    nav.popUntil((Route<dynamic> r) => r.isFirst);
    hub.status('Navigation flow complete — breadcrumbs recorded');
  }

  Future<void> _networkSuccess() async {
    hub.status('GET https://httpbin.org/get …');
    await dio.get<dynamic>('https://httpbin.org/get');
  }

  Future<void> _networkError() async {
    hub.status('GET https://httpbin.org/status/503 …');
    try {
      await dio.get<dynamic>('https://httpbin.org/status/503');
    } on DioException {
      // Interceptor logs the failure.
    }
  }

  Future<void> _networkPii() async {
    hub.status('POST with password/token (scrubbed in log metadata)');
    try {
      await dio.post<dynamic>(
        'https://httpbin.org/post',
        data: <String, dynamic>{
          'email': 'user@example.com',
          'password': 'secret123',
          'token': 'abc',
        },
      );
    } on DioException {
      //
    }
  }

  Future<void> _fillBatch() async {
    hub.status('Enqueueing 6 INFO logs (batch size = 5) …');
    for (int i = 0; i < 6; i++) {
      await logger.log(
        domain: Domain.internal,
        category: LogCategory.logic,
        level: LogLevel.info,
        message: 'demo batch item $i',
        metadata: <String, dynamic>{'index': i},
      );
    }
  }

  Future<void> _logError() async {
    await logger.log(
      domain: Domain.internal,
      category: LogCategory.logic,
      level: LogLevel.error,
      message: 'Simulated checkout failure',
      metadata: <String, dynamic>{'step': 'payment'},
      stackTrace: StackTrace.current.toString(),
    );
  }

  Future<void> _logFatal() async {
    await logger.log(
      domain: Domain.internal,
      category: LogCategory.systemCrash,
      level: LogLevel.fatal,
      message: 'Simulated fatal — bypasses batch queue',
      stackTrace: StackTrace.current.toString(),
    );
  }
}

class _DemoButton extends StatelessWidget {
  const _DemoButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

class DemoDetailsPage extends StatelessWidget {
  const DemoDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product details')),
      body: Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).pushNamed('/checkout'),
          child: const Text('Go to checkout'),
        ),
      ),
    );
  }
}

class DemoCheckoutPage extends StatelessWidget {
  const DemoCheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: const Center(child: Text('Breadcrumbs include this route on errors')),
    );
  }
}
