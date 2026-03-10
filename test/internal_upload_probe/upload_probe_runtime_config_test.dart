import 'package:flutter_performance_tier/internal_upload_probe/internal_upload_probe_env.dart';
import 'package:flutter_performance_tier/internal_upload_probe/upload_probe_runtime_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UploadProbeRuntimeConfig', () {
    test('fromSources uses env values when defines are absent', () {
      final config = UploadProbeRuntimeConfig.fromSources(
        envSource: const _FakeUploadProbeEnvSource(
          uploadUrl: 'https://example.com/upload',
          loginUrl: 'https://example.com/user/login',
          uploadToken: 'env-token',
          uploadUsername: 'env-user',
          uploadPassword: 'env-password',
          uploadSource: 'env-source',
          authSessionKey: 'env-session-key',
        ),
      );

      expect(config.uploadUri, Uri.parse('https://example.com/upload'));
      expect(config.source, 'env-source');
      expect(config.authConfig.loginUrl, 'https://example.com/user/login');
      expect(config.authConfig.tokenFromEnv, 'env-token');
      expect(config.authConfig.username, 'env-user');
      expect(config.authConfig.password, 'env-password');
      expect(config.authConfig.sessionKey, 'env-session-key');
    });

    test('fromSources prefers non-empty dart-define values', () {
      final config = UploadProbeRuntimeConfig.fromSources(
        envSource: const _FakeUploadProbeEnvSource(
          uploadUrl: 'https://env.example/upload',
          loginUrl: 'https://env.example/user/login',
          uploadToken: 'env-token',
          uploadUsername: 'env-user',
          uploadPassword: 'env-password',
          uploadSource: 'env-source',
          authSessionKey: 'env-session-key',
        ),
        uploadUrlFromDefine: 'https://define.example/upload',
        loginUrlFromDefine: 'https://define.example/user/login',
        uploadTokenFromDefine: 'define-token',
        uploadUsernameFromDefine: 'define-user',
        uploadPasswordFromDefine: 'define-password',
        uploadSourceFromDefine: 'define-source',
        authSessionKeyFromDefine: 'define-session-key',
      );

      expect(config.uploadUri, Uri.parse('https://define.example/upload'));
      expect(config.source, 'define-source');
      expect(config.authConfig.loginUrl, 'https://define.example/user/login');
      expect(config.authConfig.tokenFromEnv, 'define-token');
      expect(config.authConfig.username, 'define-user');
      expect(config.authConfig.password, 'define-password');
      expect(config.authConfig.sessionKey, 'define-session-key');
    });

    test('fromSources rejects invalid upload uri', () {
      expect(
        () => UploadProbeRuntimeConfig.fromSources(
          envSource: const _FakeUploadProbeEnvSource(
            uploadUrl: 'not-a-uri',
            loginUrl: 'https://example.com/user/login',
            uploadToken: '',
            uploadUsername: '',
            uploadPassword: '',
            uploadSource: 'env-source',
            authSessionKey: 'env-session-key',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

class _FakeUploadProbeEnvSource implements UploadProbeEnvSource {
  const _FakeUploadProbeEnvSource({
    required this.uploadUrl,
    required this.loginUrl,
    required this.uploadToken,
    required this.uploadUsername,
    required this.uploadPassword,
    required this.uploadSource,
    required this.authSessionKey,
  });

  @override
  final String uploadUrl;

  @override
  final String loginUrl;

  @override
  final String uploadToken;

  @override
  final String uploadUsername;

  @override
  final String uploadPassword;

  @override
  final String uploadSource;

  @override
  final String authSessionKey;
}
