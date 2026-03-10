import 'dart:async';
import 'dart:convert';

import 'package:common/common.dart';
import 'package:dio/dio.dart';

class UploadProbeAuthConfig {
  const UploadProbeAuthConfig({
    required this.loginUrl,
    required this.tokenFromEnv,
    required this.username,
    required this.password,
    this.sessionKey = 'flutter_performance_tier.upload_probe.auth_session_v1',
  });

  final String loginUrl;
  final String tokenFromEnv;
  final String username;
  final String password;
  final String sessionKey;

  String get normalizedToken => tokenFromEnv.trim();
  String get normalizedUsername => username.trim();
  String get normalizedPassword => password;

  bool get hasToken => normalizedToken.isNotEmpty;
  bool get hasCredentials =>
      normalizedUsername.isNotEmpty && password.isNotEmpty;
}

class UploadProbeLoginResult {
  const UploadProbeLoginResult({
    required this.statusCode,
    required this.token,
    this.refreshToken,
    this.expiresAtUtc,
    this.subjectId,
  });

  final int statusCode;
  final String token;
  final String? refreshToken;
  final DateTime? expiresAtUtc;
  final String? subjectId;
}

abstract interface class UploadProbeLoginGateway {
  Future<UploadProbeLoginResult> login({
    required String username,
    required String password,
  });
}

class DioUploadProbeLoginGateway implements UploadProbeLoginGateway {
  DioUploadProbeLoginGateway({
    required Dio dio,
    required this.loginUrl,
  }) : _dio = dio;

  final Dio _dio;
  final String loginUrl;

  @override
  Future<UploadProbeLoginResult> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Object?>(
      loginUrl,
      data: <String, String>{
        'username': username,
        'password': password,
      },
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (int? status) => status != null,
      ),
    );
    final payload = _normalizePayload(response.data);
    final statusCode = response.statusCode ?? -1;
    _assertLoginSucceeded(statusCode: statusCode, payload: payload);

    final token = _extractToken(payload);
    if (token == null || token.isEmpty) {
      throw FormatException(
        'Login succeeded but token is empty: ${_previewPayload(payload)}',
      );
    }

    return UploadProbeLoginResult(
      statusCode: statusCode,
      token: token,
      refreshToken: _extractRefreshToken(payload),
      expiresAtUtc: _extractExpiresAt(payload) ?? _readJwtExpireTime(token),
      subjectId: _extractSubjectId(payload) ?? username,
    );
  }

  void _assertLoginSucceeded({
    required int statusCode,
    required Object? payload,
  }) {
    if (statusCode < 200 || statusCode >= 300) {
      throw StateError(
        'Login failed(status=$statusCode), response=${_previewPayload(payload)}',
      );
    }

    final map = _normalizeObjectMap(payload);
    if (map == null) {
      return;
    }

    final code = map['code'];
    if (code is num && code.toInt() != 200) {
      throw StateError(
        'Login failed(code=${code.toInt()}), response=${_previewPayload(payload)}',
      );
    }
  }
}

class UploadProbePasswordLoginRefresher implements AuthTokenRefresher {
  UploadProbePasswordLoginRefresher({
    required UploadProbeLoginGateway loginGateway,
    required this.username,
    required this.password,
    this.onTrace,
  }) : _loginGateway = loginGateway;

  final UploadProbeLoginGateway _loginGateway;
  final String username;
  final String password;
  final void Function(String line)? onTrace;

  @override
  Future<AuthTokenPair> refresh(AuthTokenPair currentTokens) async {
    final result = await _loginGateway.login(
      username: username,
      password: password,
    );
    onTrace?.call(
      '[upload_probe_auth] password login refresh ok '
      'status=${result.statusCode} tokenLen=${result.token.length}',
    );
    return AuthTokenPair(
      accessToken: result.token,
      refreshToken: result.refreshToken ?? currentTokens.refreshToken,
    );
  }
}

class UploadProbeAuthService {
  UploadProbeAuthService({
    required CommonAuth auth,
    required UploadProbeAuthConfig config,
    required UploadProbeLoginGateway loginGateway,
    this.logger,
  })  : _auth = auth,
        _config = config,
        _loginGateway = loginGateway;

  factory UploadProbeAuthService.memory({
    required UploadProbeAuthConfig config,
    required UploadProbeLoginGateway loginGateway,
    void Function(String line)? logger,
  }) {
    return UploadProbeAuthService(
      auth: CommonAuth.memory(
        tokenRefresher: config.hasCredentials
            ? UploadProbePasswordLoginRefresher(
                loginGateway: loginGateway,
                username: config.normalizedUsername,
                password: config.normalizedPassword,
                onTrace: logger,
              )
            : null,
      ),
      config: config,
      loginGateway: loginGateway,
      logger: logger,
    );
  }

  factory UploadProbeAuthService.secureStorage({
    required UploadProbeAuthConfig config,
    required Dio dio,
    void Function(String line)? logger,
  }) {
    final loginGateway = DioUploadProbeLoginGateway(
      dio: dio,
      loginUrl: config.loginUrl,
    );
    return UploadProbeAuthService(
      auth: CommonAuth.secureStorage(
        sessionKey: config.sessionKey,
        tokenRefresher: config.hasCredentials
            ? UploadProbePasswordLoginRefresher(
                loginGateway: loginGateway,
                username: config.normalizedUsername,
                password: config.normalizedPassword,
                onTrace: logger,
              )
            : null,
      ),
      config: config,
      loginGateway: loginGateway,
      logger: logger,
    );
  }

  final CommonAuth _auth;
  final UploadProbeAuthConfig _config;
  final UploadProbeLoginGateway _loginGateway;
  final void Function(String line)? logger;

  AuthState get currentState => _auth.currentState;

  Stream<AuthState> watchState() => _auth.watchState();

  Future<void> bootstrap() async {
    await _auth.bootstrap();
    await _seedSessionFromEnvTokenIfNeeded();
    await _normalizeSessionExpiry(_auth.currentState.session);
  }

  Future<String> resolveAccessToken() async {
    await _seedSessionFromEnvTokenIfNeeded();

    final currentSession = await _normalizeSessionExpiry(
      _auth.currentState.session,
    );
    if (currentSession != null && currentSession.expiresAt == null) {
      logger?.call(
        '[upload_probe_auth] reuse cached session without explicit expiry',
      );
      return currentSession.tokens.accessToken;
    }

    final validatedSession = await _auth.ensureValidSession();
    final normalizedSession = await _normalizeSessionExpiry(validatedSession);
    if (normalizedSession != null) {
      return normalizedSession.tokens.accessToken;
    }

    if (_config.hasToken) {
      throw StateError(
        'UPLOAD_PROBE_TOKEN is missing or expired. '
        'Provide UPLOAD_PROBE_USERNAME/UPLOAD_PROBE_PASSWORD via secure env '
        'or --dart-define to renew it, or replace the token.',
      );
    }
    if (!_config.hasCredentials) {
      throw StateError(
        'Missing upload auth. Set UPLOAD_PROBE_TOKEN or '
        'UPLOAD_PROBE_USERNAME/UPLOAD_PROBE_PASSWORD via secure env '
        'or --dart-define.',
      );
    }

    final loginResult =
        await _loginAndPersist(reason: 'initial password login');
    return loginResult.token;
  }

  Future<void> clearSession() => _auth.clearSession();

  Future<void> dispose() => _auth.dispose();

  Future<UploadProbeLoginResult> _loginAndPersist({
    required String reason,
  }) async {
    final loginResult = await _loginGateway.login(
      username: _config.normalizedUsername,
      password: _config.normalizedPassword,
    );
    final session = AuthSession(
      tokens: AuthTokenPair(
        accessToken: loginResult.token,
        refreshToken: loginResult.refreshToken,
      ),
      expiresAt:
          loginResult.expiresAtUtc ?? _readJwtExpireTime(loginResult.token),
      subjectId: loginResult.subjectId ?? _config.normalizedUsername,
    );
    await _auth.setSession(session);
    logger?.call(
      '[upload_probe_auth] $reason ok '
      'status=${loginResult.statusCode} tokenLen=${loginResult.token.length}',
    );
    return loginResult;
  }

  Future<void> _seedSessionFromEnvTokenIfNeeded() async {
    if (!_config.hasToken) {
      return;
    }

    final token = _config.normalizedToken;
    final session = _auth.currentState.session;
    if (session?.tokens.accessToken == token) {
      return;
    }

    await _auth.setSession(
      AuthSession(
        tokens: AuthTokenPair(accessToken: token),
        expiresAt: _readJwtExpireTime(token),
        subjectId: _config.hasCredentials ? _config.normalizedUsername : null,
      ),
    );
    logger?.call('[upload_probe_auth] seeded session from UPLOAD_PROBE_TOKEN');
  }

  Future<AuthSession?> _normalizeSessionExpiry(AuthSession? session) async {
    if (session == null) {
      return null;
    }

    final expiresAt = _readJwtExpireTime(session.tokens.accessToken);
    if (_sameMoment(session.expiresAt, expiresAt)) {
      return session;
    }

    final normalizedSession = session.copyWith(expiresAt: expiresAt);
    await _auth.setSession(normalizedSession);
    return normalizedSession;
  }
}

Object? _normalizePayload(Object? raw) {
  if (raw is! String) {
    return raw;
  }
  try {
    return jsonDecode(raw);
  } catch (_) {
    return raw;
  }
}

String? _extractToken(Object? payload) {
  if (payload is String && payload.trim().isNotEmpty) {
    return payload.trim();
  }
  final map = _normalizeObjectMap(payload);
  if (map == null) {
    return null;
  }
  return _extractNestedString(
    map,
    directKeys: const <String>[
      'token',
      'accessToken',
      'access_token',
      'jwt',
      'bearerToken',
    ],
  );
}

String? _extractRefreshToken(Object? payload) {
  final map = _normalizeObjectMap(payload);
  if (map == null) {
    return null;
  }
  return _extractNestedString(
    map,
    directKeys: const <String>['refreshToken', 'refresh_token'],
  );
}

String? _extractSubjectId(Object? payload) {
  final map = _normalizeObjectMap(payload);
  if (map == null) {
    return null;
  }
  return _extractNestedString(
    map,
    directKeys: const <String>['subjectId', 'subject_id', 'userId', 'id'],
  );
}

DateTime? _extractExpiresAt(Object? payload) {
  final map = _normalizeObjectMap(payload);
  if (map == null) {
    return null;
  }

  final raw = _extractNestedValue(
    map,
    directKeys: const <String>[
      'expiresAt',
      'expires_at',
      'expireAt',
      'expire_at',
      'exp',
    ],
  );
  return _parseDateTimeLike(raw);
}

String? _extractNestedString(
  Map<String, Object?> map, {
  required List<String> directKeys,
}) {
  final value = _extractNestedValue(map, directKeys: directKeys);
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

Object? _extractNestedValue(
  Map<String, Object?> map, {
  required List<String> directKeys,
}) {
  for (final key in directKeys) {
    final value = map[key];
    if (value != null) {
      return value;
    }
  }

  for (final key in const <String>['data', 'result', 'payload']) {
    final nested = _normalizeObjectMap(map[key]);
    if (nested == null) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      continue;
    }
    final nestedValue = _extractNestedValue(nested, directKeys: directKeys);
    if (nestedValue != null) {
      return nestedValue;
    }
  }
  return null;
}

Map<String, Object?>? _normalizeObjectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    final normalized = <String, Object?>{};
    for (final entry in value.entries) {
      normalized[entry.key.toString()] = entry.value;
    }
    return normalized;
  }
  return null;
}

DateTime? _parseDateTimeLike(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is int) {
    return _fromUnixLikeTimestamp(value);
  }
  if (value is num) {
    return _fromUnixLikeTimestamp(value.toInt());
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parsedInt = int.tryParse(trimmed);
    if (parsedInt != null) {
      return _fromUnixLikeTimestamp(parsedInt);
    }

    final parsedDate = DateTime.tryParse(trimmed);
    return parsedDate?.toUtc();
  }
  return null;
}

DateTime _fromUnixLikeTimestamp(int value) {
  final milliseconds = value >= 1000000000000 ? value : value * 1000;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

DateTime? _readJwtExpireTime(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    return null;
  }
  try {
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final payload = jsonDecode(decoded);
    final map = _normalizeObjectMap(payload);
    if (map == null) {
      return null;
    }
    final exp = map['exp'];
    return _parseDateTimeLike(exp);
  } catch (_) {
    return null;
  }
}

bool _sameMoment(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return left == right;
  }
  return left.toUtc().millisecondsSinceEpoch ==
      right.toUtc().millisecondsSinceEpoch;
}

String _previewPayload(Object? payload) {
  final text = switch (payload) {
    null => '-',
    String value => value,
    Map() || List() => const JsonEncoder.withIndent('  ').convert(payload),
    _ => payload.toString(),
  };
  if (text.length <= 320) {
    return text;
  }
  return '${text.substring(0, 320)}...';
}
