import 'dart:async';

import 'package:common/common.dart';
import 'package:flutter/material.dart';

import 'demo/performance_tier_demo_controller.dart';
import 'demo/performance_tier_diagnostics_scaffold.dart';
import 'internal_upload_probe/upload_probe_client.dart';
import 'internal_upload_probe/upload_probe_runtime_config.dart';

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
  late final PerformanceTierDemoController _controller =
      PerformanceTierDemoController();
  late final UploadProbeRuntimeConfig _config =
      UploadProbeRuntimeConfig.resolve();
  late final UploadProbeClient _uploadProbeClient =
      UploadProbeClient.secureStorage(
    config: _config,
    logger: _controller.recordDiagnosticLog,
  );
  StreamSubscription<AuthState>? _authStateSubscription;

  String? _uploadError;
  String _uploadResult = 'Not run yet.';
  bool _runningUpload = false;
  bool _clearingSession = false;
  String _authStatus = AuthStatus.unknown.name;
  String _authTokenPreview = '-';
  String _authSubject = '-';
  String _authExpiresAt = '-';

  @override
  void initState() {
    super.initState();
    _updateAuthStateFields(_uploadProbeClient.currentState);
    _authStateSubscription =
        _uploadProbeClient.watchState().listen(_onAuthState);
    unawaited(_uploadProbeClient.bootstrap());
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    unawaited(_authStateSubscription?.cancel());
    unawaited(_uploadProbeClient.dispose());
    unawaited(_controller.close());
    super.dispose();
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
      final result = await _uploadProbeClient.uploadReport(
        reportContent: _controller.buildAiReport(
          extraSections: _buildUploadProbeReport(),
        ),
      );
      if (!result.success) {
        setState(() {
          _uploadError = result.error ?? result.detail;
        });
        return;
      }

      setState(() {
        _uploadResult = result.detail;
      });
    } finally {
      if (mounted) {
        setState(() {
          _runningUpload = false;
        });
      }
    }
  }

  Future<void> _clearAuthSession() async {
    if (_clearingSession) {
      return;
    }

    setState(() {
      _clearingSession = true;
      _uploadError = null;
    });

    try {
      await _uploadProbeClient.clearSession();
      _controller.recordDiagnosticLog('[upload_probe_auth] session cleared');
    } catch (error) {
      setState(() {
        _uploadError = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _clearingSession = false;
        });
      }
    }
  }

  void _onAuthState(AuthState state) {
    if (!mounted) {
      return;
    }
    setState(() {
      _updateAuthStateFields(state);
    });
  }

  void _updateAuthStateFields(AuthState state) {
    _authStatus = state.status.name;
    _authTokenPreview = _previewToken(state.session?.tokens.accessToken);
    _authSubject = state.session?.subjectId ?? '-';
    _authExpiresAt = _formatExpiresAt(state.session?.expiresAt);
  }

  String _previewToken(String? token) {
    if (token == null || token.isEmpty) {
      return '-';
    }
    if (token.length <= 24) {
      return token;
    }
    return '${token.substring(0, 24)}...';
  }

  String _formatExpiresAt(DateTime? value) {
    if (value == null) {
      return '-';
    }
    return value.toLocal().toIso8601String();
  }

  Map<String, Object?> _buildUploadProbeReport() {
    return <String, Object?>{
      'auth': <String, Object?>{
        'status': _authStatus,
        'subjectId': _authSubject == '-' ? null : _authSubject,
        'accessTokenPreview': _authTokenPreview,
        'expiresAt': _authExpiresAt == '-' ? null : _authExpiresAt,
        'loginUrl': _config.authConfig.loginUrl,
        'hasTokenFromEnv': _config.authConfig.hasToken,
        'hasPasswordCredentials': _config.authConfig.hasCredentials,
      },
      'uploadProbe': <String, Object?>{
        'url': _config.uploadUri.toString(),
        'source': _config.source,
        'client': _uploadProbeClient.clientLabel,
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
            OutlinedButton.icon(
              onPressed:
                  _runningUpload || _clearingSession ? null : _clearAuthSession,
              icon: _clearingSession
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: Text(
                _clearingSession ? 'Clearing...' : 'Clear auth session',
              ),
            ),
          ],
          sectionsBeforeReport: <Widget>[
            Text(
              'Upload endpoint: ${_config.uploadUri}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Login endpoint: ${_config.authConfig.loginUrl}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Upload source: ${_config.source}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Auth status: $_authStatus',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Auth subject: $_authSubject',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Auth expiresAt: $_authExpiresAt',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Auth token: $_authTokenPreview',
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
