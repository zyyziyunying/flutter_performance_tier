import 'dart:async';
import 'dart:convert';

import 'package:common/log_upload.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'demo/performance_tier_demo_controller.dart';
import 'demo/performance_tier_diagnostics_scaffold.dart';

void main() {
  runApp(const PerformanceTierInternalUploadProbeApp());
}

class PerformanceTierInternalUploadProbeApp extends StatelessWidget {
  const PerformanceTierInternalUploadProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Performance Tier Internal Upload Probe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B6E4F),
        ),
        useMaterial3: true,
      ),
      home: const PerformanceTierInternalUploadProbePage(),
    );
  }
}

class PerformanceTierInternalUploadProbePage extends StatefulWidget {
  const PerformanceTierInternalUploadProbePage({super.key});

  @override
  State<PerformanceTierInternalUploadProbePage> createState() =>
      _PerformanceTierInternalUploadProbePageState();
}

class _PerformanceTierInternalUploadProbePageState
    extends State<PerformanceTierInternalUploadProbePage> {
  static const String _uploadUrl = 'http://47.110.52.208:7777/upload';
  static const String _loginUrl = 'http://47.110.52.208:7777/user/login';
  static const String _uploadTokenFromEnv = String.fromEnvironment(
    'UPLOAD_PROBE_TOKEN',
  );
  static const String _uploadUsername = String.fromEnvironment(
    'UPLOAD_PROBE_USERNAME',
  );
  static const String _uploadPassword = String.fromEnvironment(
    'UPLOAD_PROBE_PASSWORD',
  );

  late final PerformanceTierDemoController _controller =
      PerformanceTierDemoController();
  late final Dio _dio = Dio();
  late final LogUploadClient _logUploadClient = LogUploadClient(
    uploader: DioLogUploader(dio: _dio),
    defaults: const LogUploadDefaults(
      timeout: Duration(seconds: 30),
      fields: <String, String>{'source': 'flutter_performance_tier'},
    ),
  );

  String? _uploadError;
  String _uploadResult = 'Not run yet.';
  String? _cachedUploadToken;
  bool _runningUpload = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    unawaited(_controller.close());
    _dio.close(force: true);
    super.dispose();
  }

  Future<String> _resolveUploadToken() async {
    if (_cachedUploadToken != null && _cachedUploadToken!.isNotEmpty) {
      return _cachedUploadToken!;
    }
    if (_uploadTokenFromEnv.isNotEmpty) {
      _cachedUploadToken = _uploadTokenFromEnv;
      return _cachedUploadToken!;
    }
    if (_uploadUsername.isEmpty || _uploadPassword.isEmpty) {
      throw StateError(
        'Missing upload auth. Set UPLOAD_PROBE_TOKEN or '
        'UPLOAD_PROBE_USERNAME/UPLOAD_PROBE_PASSWORD via --dart-define.',
      );
    }

    final response = await _dio.post<Map<String, dynamic>>(
      _loginUrl,
      data: <String, String>{
        'username': _uploadUsername,
        'password': _uploadPassword,
      },
      options: Options(responseType: ResponseType.json),
    );
    final body = response.data;
    if (body == null) {
      throw StateError('Login response is empty.');
    }

    final code = body['code'];
    if (code is! num || code.toInt() != 200) {
      throw StateError(
        'Login failed: code=$code, message=${body['message'] ?? '-'}',
      );
    }

    final token = body['data'];
    if (token is! String || token.isEmpty) {
      throw StateError('Login succeeded but token is empty.');
    }

    _cachedUploadToken = token;
    _controller.recordDiagnosticLog(
      '[dio_upload_probe] login ok tokenLen=${token.length}',
    );
    return token;
  }

  Future<void> _runUploadProbe() async {
    if (_runningUpload) {
      return;
    }

    setState(() {
      _runningUpload = true;
      _uploadError = null;
    });

    try {
      final token = await _resolveUploadToken();
      final now = DateTime.now();
      final fileName = 'performance_tier_report_'
          '${now.toUtc().toIso8601String().replaceAll(':', '').replaceAll('.', '')}.json';
      final uploadResult = await _logUploadClient.upload(
        uploadUri: Uri.parse(_uploadUrl),
        fileContent: _controller.buildAiReport(
          extraSections: _buildUploadProbeReport(),
        ),
        token: token,
        fileName: fileName,
        fields: <String, String>{'generatedAt': now.toIso8601String()},
      );
      final detail = _logUploadClient.formatResultDetail(
        uploadResult,
        responsePreviewMaxLength: 400,
      );
      if (!uploadResult.success) {
        _controller.recordDiagnosticLog('[dio_upload_probe] failed: $detail');
        setState(() {
          _uploadError = detail;
        });
        return;
      }

      _controller.recordDiagnosticLog('[dio_upload_probe] success: $detail');
      setState(() {
        _uploadResult = detail;
      });
    } on DioException catch (error) {
      final errorText = _formatDioException(error);
      _controller.recordDiagnosticLog('[dio_upload_probe] failed: $errorText');
      setState(() {
        _uploadError = errorText;
      });
    } catch (error) {
      _controller.recordDiagnosticLog('[dio_upload_probe] failed: $error');
      setState(() {
        _uploadError = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _runningUpload = false;
        });
      }
    }
  }

  String _formatDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final responsePreview = _formatResponsePreview(error.response?.data);
    final message = error.message?.trim();
    final cause = error.error?.toString().trim();
    final details = <String>[
      'type=${error.type.name}',
      if (message != null && message.isNotEmpty) 'message=$message',
      if (cause != null && cause.isNotEmpty && cause != message) 'cause=$cause',
      'url=${error.requestOptions.uri}',
    ].join(', ');
    if (statusCode == null) {
      return details;
    }
    return '$details, status=$statusCode, response=$responsePreview';
  }

  String _formatResponsePreview(Object? data) {
    if (data == null) {
      return '-';
    }
    if (data is List<int>) {
      return _truncatePreview(utf8.decode(data, allowMalformed: true));
    }
    if (data is String) {
      return _truncatePreview(data);
    }
    if (data is Map || data is List) {
      final text = const JsonEncoder.withIndent('  ').convert(data);
      return _truncatePreview(text);
    }
    return _truncatePreview(data.toString());
  }

  String _truncatePreview(String text) {
    if (text.length <= 400) {
      return text;
    }
    return '${text.substring(0, 400)}...';
  }

  Map<String, Object?> _buildUploadProbeReport() {
    return <String, Object?>{
      'uploadProbe': <String, Object?>{
        'url': _uploadUrl,
        'client': _logUploadClient.clientLabel,
        'running': _runningUpload,
        'result': _uploadResult,
        if (_uploadError != null) 'error': _uploadError,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return PerformanceTierDiagnosticsScaffold(
          title: 'Performance Tier Internal Upload Probe',
          introText:
              'Internal validation entrypoint. The default main demo stays '
              'focused on local diagnostics, while this target keeps the '
              'upload probe workflow isolated.',
          headline: _controller.buildHeadline(),
          report: _controller.buildAiReport(
            extraSections: _buildUploadProbeReport(),
          ),
          error: _controller.error,
          isRefreshing: _controller.refreshing,
          onRefresh: _controller.refreshDecision,
          onCopyAiReport: () => _controller.copyAiReport(
            context,
            extraSections: _buildUploadProbeReport(),
          ),
          onCopyLatestLogLine: () => _controller.copyLatestLogLine(context),
          controlButtons: <Widget>[
            FilledButton.icon(
              onPressed: _runningUpload ? null : _runUploadProbe,
              icon: _runningUpload
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(
                _runningUpload ? 'Uploading...' : 'Run /upload probe',
              ),
            ),
          ],
          sectionsBeforeReport: <Widget>[
            Text(
              'Upload endpoint: $_uploadUrl',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_uploadError != null)
              Text(
                'Upload error: $_uploadError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            SelectableText(
              _uploadResult,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        );
      },
    );
  }
}
