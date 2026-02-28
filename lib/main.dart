import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rust_net/flutter_rust_net.dart';

import 'performance_tier/performance_tier.dart';

void main() {
  runApp(const PerformanceTierDemoApp());
}

class PerformanceTierDemoApp extends StatelessWidget {
  const PerformanceTierDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Performance Tier Logs',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PerformanceTierDemoPage(),
    );
  }
}

class PerformanceTierDemoPage extends StatefulWidget {
  const PerformanceTierDemoPage({super.key});

  @override
  State<PerformanceTierDemoPage> createState() =>
      _PerformanceTierDemoPageState();
}

class _PerformanceTierDemoPageState extends State<PerformanceTierDemoPage> {
  static const String _rustUploadUrl = 'http://47.110.52.208:7777/upload';

  final List<String> _structuredLogs = <String>[];

  late final JsonLinePerformanceTierLogger _logger =
      JsonLinePerformanceTierLogger(
        prefix: 'PERF_TIER_LOG',
        emitter: _onStructuredLogLine,
      );
  late final DefaultPerformanceTierService _service =
      DefaultPerformanceTierService(logger: _logger);
  late final RustAdapter _rustAdapter = RustAdapter();
  late final BytesFirstNetworkClient _networkClient = BytesFirstNetworkClient(
    gateway: NetworkGateway(
      routingPolicy: const RoutingPolicy(),
      featureFlag: const NetFeatureFlag(
        enableRustChannel: true,
        enableFallback: true,
      ),
      dioAdapter: DioAdapter(),
      rustAdapter: _rustAdapter,
    ),
  );

  StreamSubscription<TierDecision>? _subscription;
  TierDecision? _decision;
  String? _error;
  String? _rustUploadError;
  String _rustUploadResult = 'Not run yet.';
  bool _initializing = true;
  bool _refreshing = false;
  bool _runningRustUpload = false;
  bool _allowUiUpdates = true;
  bool _rustEngineInitialized = false;

  @override
  void initState() {
    super.initState();
    _subscription = _service.watchDecision().listen(
      _onDecision,
      onError: (Object error, StackTrace stackTrace) {
        if (!_canUpdateUi) {
          return;
        }
        setState(() {
          _initializing = false;
          _error = 'watchDecision failed: $error';
        });
      },
    );
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _allowUiUpdates = false;
    unawaited(_subscription?.cancel());
    unawaited(_service.dispose());
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _service.initialize();
      if (!_canUpdateUi) {
        return;
      }
      setState(() {
        _initializing = false;
      });
    } catch (error) {
      if (!_canUpdateUi) {
        return;
      }
      setState(() {
        _initializing = false;
        _error = 'Initialization failed: $error';
      });
    }
  }

  Future<void> _refreshDecision() async {
    if (_refreshing) {
      return;
    }
    setState(() {
      _refreshing = true;
    });
    try {
      await _service.refresh();
    } catch (error) {
      if (!_canUpdateUi) {
        return;
      }
      setState(() {
        _error = 'Refresh failed: $error';
      });
    } finally {
      if (_canUpdateUi) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _onDecision(TierDecision decision) {
    if (!_canUpdateUi) {
      return;
    }
    setState(() {
      _decision = decision;
      _error = null;
      _initializing = false;
    });
  }

  void _onStructuredLogLine(String line) {
    debugPrint(line);
    _structuredLogs.insert(0, line);
    if (_structuredLogs.length > 200) {
      _structuredLogs.removeRange(200, _structuredLogs.length);
    }
    if (!_canUpdateUi) {
      return;
    }
    setState(() {});
  }

  Future<void> _copyAiReport() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final report = _buildAiReport();
    await Clipboard.setData(ClipboardData(text: report));
    if (!_canUpdateUi || messenger == null) {
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('AI report copied.')));
  }

  Future<void> _copyLatestLogLine() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final latest = _structuredLogs.isEmpty ? '' : _structuredLogs.first;
    await Clipboard.setData(ClipboardData(text: latest));
    if (!_canUpdateUi || messenger == null) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Latest log line copied.')),
    );
  }

  bool get _canUpdateUi => _allowUiUpdates && mounted;

  Future<void> _runRustUploadProbe() async {
    if (_runningRustUpload) {
      return;
    }
    setState(() {
      _runningRustUpload = true;
      _rustUploadError = null;
    });

    try {
      String? initWarning;
      try {
        await _ensureRustEngineInitialized();
      } catch (error) {
        initWarning = '$error';
      }

      final body = _buildMultipartPayload(
        fieldName: 'file',
        fileName: 'performance_tier_probe.txt',
        fileContent:
            'probe from flutter_performance_tier @ ${DateTime.now().toIso8601String()}',
      );
      final idempotencyKey =
          'performance-tier-upload-${DateTime.now().microsecondsSinceEpoch}';

      final response = await _networkClient.requestRaw(
        NetRequest(
          method: 'POST',
          url: _rustUploadUrl,
          headers: <String, String>{
            'content-type': 'multipart/form-data; boundary=${body.boundary}',
            'content-length': body.bytes.length.toString(),
            'idempotency-key': idempotencyKey,
          },
          body: body.bytes,
        ),
      );

      final responseText = _formatResponsePreview(response.bodyBytes);
      final routeReason = response.routeReason ?? '-';
      final fallbackSuffix = response.fromFallback ? ' (fallback)' : '';
      final initSuffix = initWarning == null ? '' : '\ninitWarning=$initWarning';
      final result = 'status=${response.statusCode}, '
          'channel=${response.channel.name}$fallbackSuffix, '
          'route=$routeReason, '
          'costMs=${response.costMs}, '
          'bytes=${response.bridgeBytes}\n'
          'response=$responseText$initSuffix';

      _onStructuredLogLine(
        '[rust_upload_probe] status=${response.statusCode} channel=${response.channel.name} '
        'fallback=${response.fromFallback} route=$routeReason',
      );
      if (!_canUpdateUi) {
        return;
      }
      setState(() {
        _rustUploadResult = result;
      });
    } catch (error) {
      _onStructuredLogLine('[rust_upload_probe] failed: $error');
      if (!_canUpdateUi) {
        return;
      }
      setState(() {
        _rustUploadError = '$error';
      });
    } finally {
      if (_canUpdateUi) {
        setState(() {
          _runningRustUpload = false;
        });
      }
    }
  }

  Future<void> _ensureRustEngineInitialized() async {
    if (_rustEngineInitialized) {
      return;
    }
    await _rustAdapter.initializeEngine(
      options: const RustEngineInitOptions(
        baseUrl: 'http://47.110.52.208:7777',
      ),
    );
    _rustEngineInitialized = true;
    _onStructuredLogLine('[rust_upload_probe] rust engine initialized');
  }

  _MultipartPayload _buildMultipartPayload({
    required String fieldName,
    required String fileName,
    required String fileContent,
  }) {
    final boundary = '----flutter-rust-net-${DateTime.now().microsecondsSinceEpoch}';
    final content = StringBuffer()
      ..writeln('--$boundary')
      ..writeln(
        'Content-Disposition: form-data; name="$fieldName"; filename="$fileName"',
      )
      ..writeln('Content-Type: text/plain; charset=utf-8')
      ..writeln()
      ..write(fileContent)
      ..writeln()
      ..write('--$boundary--\r\n');
    return _MultipartPayload(
      boundary: boundary,
      bytes: Uint8List.fromList(utf8.encode(content.toString())),
    );
  }

  String _formatResponsePreview(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) {
      return '-';
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    if (text.length <= 400) {
      return text;
    }
    return '${text.substring(0, 400)}...';
  }

  String _buildAiReport() {
    final report = <String, Object?>{
      'status': _error == null ? 'ok' : 'error',
      'generatedAt': DateTime.now().toIso8601String(),
      'initializing': _initializing,
      if (_decision != null) 'decision': _decision!.toMap(),
      if (_error != null) 'error': _error,
      'recentStructuredLogs': _structuredLogs.take(40).toList(),
      'rustUploadProbe': <String, Object?>{
        'url': _rustUploadUrl,
        'running': _runningRustUpload,
        'rustInitialized': _rustEngineInitialized,
        'result': _rustUploadResult,
        if (_rustUploadError != null) 'error': _rustUploadError,
      },
    };
    return const JsonEncoder.withIndent('  ').convert(report);
  }

  String _buildHeadline() {
    if (_initializing && _decision == null) {
      return 'Initializing service and waiting for first decision...';
    }
    if (_decision == null) {
      return _error ?? 'No decision yet.';
    }
    final decision = _decision!;
    return 'tier=${decision.tier.name}, '
        'confidence=${decision.confidence.name}, '
        'runtime=${decision.runtimeObservation.status.wireName}';
  }

  @override
  Widget build(BuildContext context) {
    final report = _buildAiReport();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Tier Logs'),
        actions: <Widget>[
          IconButton(
            onPressed: _refreshing ? null : _refreshDecision,
            tooltip: 'Refresh decision',
            icon: _refreshing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _copyAiReport,
            tooltip: 'Copy AI report',
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Panel mode removed. Structured output only.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(_buildHeadline()),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Last Error: $_error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _copyLatestLogLine,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy latest log'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _runningRustUpload ? null : _runRustUploadProbe,
                  icon: _runningRustUpload
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _runningRustUpload
                        ? 'Uploading...'
                        : 'Run Rust /upload probe',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rust upload endpoint: $_rustUploadUrl',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_rustUploadError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Upload error: $_rustUploadError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            SelectableText(
              _rustUploadResult,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            Text(
              'AI Diagnostics JSON',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    report,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MultipartPayload {
  const _MultipartPayload({required this.boundary, required this.bytes});

  final String boundary;
  final Uint8List bytes;
}
