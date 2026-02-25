import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class PerformanceTierLogRecord {
  const PerformanceTierLogRecord({
    required this.event,
    required this.timestamp,
    this.sessionId,
    this.payload = const <String, Object?>{},
  });

  final String event;
  final DateTime timestamp;
  final String? sessionId;
  final Map<String, Object?> payload;

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'event': event,
      'timestamp': timestamp.toIso8601String(),
      if (sessionId != null) 'sessionId': sessionId,
      'payload': payload,
    };
  }
}

abstract interface class PerformanceTierLogger {
  void log(PerformanceTierLogRecord record);
}

typedef PerformanceTierLogEmitter = void Function(String line);

class JsonLinePerformanceTierLogger implements PerformanceTierLogger {
  JsonLinePerformanceTierLogger({
    this.prefix = 'PERF_TIER_LOG',
    PerformanceTierLogEmitter? emitter,
    bool pretty = false,
  }) : _emitter = emitter ?? debugPrint,
       _encoder = pretty
           ? const JsonEncoder.withIndent('  ')
           : const JsonEncoder();

  final String prefix;
  final PerformanceTierLogEmitter _emitter;
  final JsonEncoder _encoder;

  @override
  void log(PerformanceTierLogRecord record) {
    _emitter('$prefix ${_encoder.convert(record.toMap())}');
  }
}

class SilentPerformanceTierLogger implements PerformanceTierLogger {
  const SilentPerformanceTierLogger();

  @override
  void log(PerformanceTierLogRecord record) {}
}
