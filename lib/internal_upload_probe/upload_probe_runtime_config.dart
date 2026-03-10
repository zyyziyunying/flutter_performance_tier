import 'internal_upload_probe_env.dart';
import 'upload_probe_auth_service.dart';

class UploadProbeRuntimeConfig {
  const UploadProbeRuntimeConfig({
    required this.uploadUri,
    required this.source,
    required this.authConfig,
  });

  static const String _uploadUrlFromDefine = String.fromEnvironment(
    'UPLOAD_PROBE_URL',
  );
  static const String _loginUrlFromDefine = String.fromEnvironment(
    'UPLOAD_PROBE_LOGIN_URL',
  );
  static const String _uploadTokenFromDefine = String.fromEnvironment(
    'UPLOAD_PROBE_TOKEN',
  );
  static const String _uploadUsernameFromDefine = String.fromEnvironment(
    'UPLOAD_PROBE_USERNAME',
  );
  static const String _uploadPasswordFromDefine = String.fromEnvironment(
    'UPLOAD_PROBE_PASSWORD',
  );
  static const String _uploadSourceFromDefine = String.fromEnvironment(
    'UPLOAD_PROBE_SOURCE',
  );
  static const String _authSessionKeyFromDefine = String.fromEnvironment(
    'UPLOAD_PROBE_AUTH_SESSION_KEY',
  );

  final Uri uploadUri;
  final String source;
  final UploadProbeAuthConfig authConfig;

  factory UploadProbeRuntimeConfig.resolve({
    UploadProbeEnvSource? envSource,
  }) {
    return UploadProbeRuntimeConfig.fromSources(
      envSource: envSource ?? SecureUploadProbeEnvSource.create(),
      uploadUrlFromDefine: _uploadUrlFromDefine,
      loginUrlFromDefine: _loginUrlFromDefine,
      uploadTokenFromDefine: _uploadTokenFromDefine,
      uploadUsernameFromDefine: _uploadUsernameFromDefine,
      uploadPasswordFromDefine: _uploadPasswordFromDefine,
      uploadSourceFromDefine: _uploadSourceFromDefine,
      authSessionKeyFromDefine: _authSessionKeyFromDefine,
    );
  }

  factory UploadProbeRuntimeConfig.fromSources({
    required UploadProbeEnvSource envSource,
    String uploadUrlFromDefine = '',
    String loginUrlFromDefine = '',
    String uploadTokenFromDefine = '',
    String uploadUsernameFromDefine = '',
    String uploadPasswordFromDefine = '',
    String uploadSourceFromDefine = '',
    String authSessionKeyFromDefine = '',
  }) {
    final source = envSource;
    final uploadUrl = _pickValue(
      defineValue: uploadUrlFromDefine,
      envValue: source.uploadUrl,
    );
    final loginUrl = _pickValue(
      defineValue: loginUrlFromDefine,
      envValue: source.loginUrl,
    );
    final uploadSource = _pickValue(
      defineValue: uploadSourceFromDefine,
      envValue: source.uploadSource,
    );
    final sessionKey = _pickValue(
      defineValue: authSessionKeyFromDefine,
      envValue: source.authSessionKey,
    );

    return UploadProbeRuntimeConfig(
      uploadUri: _parseRequiredUri(
        value: uploadUrl,
        variableName: 'UPLOAD_PROBE_URL',
      ),
      source: _requireNonEmpty(
        value: uploadSource,
        variableName: 'UPLOAD_PROBE_SOURCE',
      ),
      authConfig: UploadProbeAuthConfig(
        loginUrl: _requireNonEmpty(
          value: loginUrl,
          variableName: 'UPLOAD_PROBE_LOGIN_URL',
        ),
        tokenFromEnv: _pickValue(
          defineValue: uploadTokenFromDefine,
          envValue: source.uploadToken,
        ),
        username: _pickValue(
          defineValue: uploadUsernameFromDefine,
          envValue: source.uploadUsername,
        ),
        password: _pickValue(
          defineValue: uploadPasswordFromDefine,
          envValue: source.uploadPassword,
        ),
        sessionKey: _requireNonEmpty(
          value: sessionKey,
          variableName: 'UPLOAD_PROBE_AUTH_SESSION_KEY',
        ),
      ),
    );
  }

  static String _pickValue({
    required String defineValue,
    required String envValue,
  }) {
    if (defineValue.trim().isNotEmpty) {
      return defineValue;
    }
    return envValue;
  }

  static String _requireNonEmpty({
    required String value,
    required String variableName,
  }) {
    final normalized = value.trim();
    if (normalized.isNotEmpty) {
      return normalized;
    }
    throw StateError('$variableName is required.');
  }

  static Uri _parseRequiredUri({
    required String value,
    required String variableName,
  }) {
    final normalized = _requireNonEmpty(
      value: value,
      variableName: variableName,
    );
    final parsed = Uri.tryParse(normalized);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      return parsed;
    }
    throw FormatException('$variableName is not a valid absolute URI.');
  }
}
