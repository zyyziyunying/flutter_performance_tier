import 'package:common/common.dart';
import 'package:dio/dio.dart';

import 'upload_probe_auth_service.dart';
import 'upload_probe_runtime_config.dart';

class UploadProbeRunResult {
  const UploadProbeRunResult._({
    required this.success,
    required this.detail,
    this.error,
  });

  const UploadProbeRunResult.success(String detail)
      : this._(success: true, detail: detail);

  const UploadProbeRunResult.failure(String detail)
      : this._(success: false, detail: detail, error: detail);

  final bool success;
  final String detail;
  final String? error;
}

class UploadProbeClient {
  UploadProbeClient({
    required this.config,
    required UploadProbeAuthService authService,
    required LogUploadClient logUploadClient,
    required Dio dio,
    required bool ownsDio,
    this.logger,
    DateTime Function()? nowProvider,
  })  : _authService = authService,
        _logUploadClient = logUploadClient,
        _dio = dio,
        _ownsDio = ownsDio,
        _nowProvider = nowProvider ?? DateTime.now;

  factory UploadProbeClient.secureStorage({
    required UploadProbeRuntimeConfig config,
    Dio? dio,
    void Function(String line)? logger,
    DateTime Function()? nowProvider,
  }) {
    final resolvedDio = dio ?? Dio();
    return UploadProbeClient(
      config: config,
      authService: UploadProbeAuthService.secureStorage(
        config: config.authConfig,
        dio: resolvedDio,
        logger: logger,
      ),
      logUploadClient: LogUploadClient(
        uploader: DioLogUploader(dio: resolvedDio),
        defaults: LogUploadDefaults(
          timeout: const Duration(seconds: 30),
          fields: <String, String>{'source': config.source},
        ),
      ),
      dio: resolvedDio,
      ownsDio: dio == null,
      logger: logger,
      nowProvider: nowProvider,
    );
  }

  final UploadProbeRuntimeConfig config;
  final UploadProbeAuthService _authService;
  final LogUploadClient _logUploadClient;
  final Dio _dio;
  final bool _ownsDio;
  final void Function(String line)? logger;
  final DateTime Function() _nowProvider;

  AuthState get currentState => _authService.currentState;

  String get clientLabel => _logUploadClient.clientLabel;

  Stream<AuthState> watchState() => _authService.watchState();

  Future<void> bootstrap() => _authService.bootstrap();

  Future<UploadProbeRunResult> uploadReport({
    required String reportContent,
    Map<String, String> fields = const <String, String>{},
  }) async {
    final now = _nowProvider();
    try {
      final token = await _authService.resolveAccessToken();
      final result = await _logUploadClient.upload(
        uploadUri: config.uploadUri,
        fileContent: reportContent,
        fileName: _buildFileName(now),
        token: token,
        fields: <String, String>{
          'generatedAt': now.toIso8601String(),
          ...fields,
        },
      );
      final detail = _logUploadClient.formatResultDetail(
        result,
        responsePreviewMaxLength: 400,
      );
      if (result.success) {
        logger?.call('[dio_upload_probe] success: $detail');
        return UploadProbeRunResult.success(detail);
      }

      logger?.call('[dio_upload_probe] failed: $detail');
      return UploadProbeRunResult.failure(detail);
    } on DioException catch (error) {
      final detail = _formatDioException(error);
      logger?.call('[dio_upload_probe] failed: $detail');
      return UploadProbeRunResult.failure(detail);
    } catch (error) {
      final detail = '$error';
      logger?.call('[dio_upload_probe] failed: $detail');
      return UploadProbeRunResult.failure(detail);
    }
  }

  Future<void> clearSession() => _authService.clearSession();

  Future<void> dispose() async {
    await _authService.dispose();
    _logUploadClient.close(force: true);
    if (_ownsDio) {
      _dio.close(force: true);
    }
  }

  String _buildFileName(DateTime now) {
    final timestamp =
        now.toUtc().toIso8601String().replaceAll(':', '').replaceAll('.', '');
    return 'performance_tier_report_$timestamp.json';
  }

  String _formatDioException(DioException error) {
    final statusCode = error.response?.statusCode;
    final responsePreview = _truncatePreview(
      error.response?.data.toLogUploadResponseBody() ?? '-',
    );
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

  String _truncatePreview(String text) {
    if (text.length <= 400) {
      return text;
    }
    return '${text.substring(0, 400)}...';
  }
}
