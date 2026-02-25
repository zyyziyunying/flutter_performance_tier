import 'package:flutter/foundation.dart';

import 'scenario_policy.dart';

@immutable
class PerformancePolicy {
  const PerformancePolicy({
    required this.animationLevel,
    required this.mediaPreloadCount,
    required this.decodeConcurrency,
    required this.imageMaxSidePx,
    this.scenarioPolicies = const <ScenarioPolicy>[],
  });

  final int animationLevel;
  final int mediaPreloadCount;
  final int decodeConcurrency;
  final int imageMaxSidePx;
  final List<ScenarioPolicy> scenarioPolicies;

  factory PerformancePolicy.fromMap(Map<String, Object?> map) {
    final animationLevel = _asInt(map['animationLevel']);
    final mediaPreloadCount = _asInt(map['mediaPreloadCount']);
    final decodeConcurrency = _asInt(map['decodeConcurrency']);
    final imageMaxSidePx = _asInt(map['imageMaxSidePx']);
    final scenarioPolicies = _parseScenarioPolicies(map['scenarioPolicies']);
    if (animationLevel == null ||
        mediaPreloadCount == null ||
        decodeConcurrency == null ||
        imageMaxSidePx == null ||
        scenarioPolicies == null) {
      throw const FormatException('Invalid performance policy payload.');
    }
    return PerformancePolicy(
      animationLevel: animationLevel,
      mediaPreloadCount: mediaPreloadCount,
      decodeConcurrency: decodeConcurrency,
      imageMaxSidePx: imageMaxSidePx,
      scenarioPolicies: scenarioPolicies,
    );
  }

  ScenarioPolicy? scenarioById(String id) {
    for (final scenario in scenarioPolicies) {
      if (scenario.id == id) {
        return scenario;
      }
    }
    return null;
  }

  Map<String, Object> toMap() {
    return <String, Object>{
      'animationLevel': animationLevel,
      'mediaPreloadCount': mediaPreloadCount,
      'decodeConcurrency': decodeConcurrency,
      'imageMaxSidePx': imageMaxSidePx,
      'scenarioPolicies': scenarioPolicies
          .map((ScenarioPolicy policy) => policy.toMap())
          .toList(),
    };
  }
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

List<ScenarioPolicy>? _parseScenarioPolicies(Object? value) {
  if (value is! List) {
    return null;
  }
  final parsed = <ScenarioPolicy>[];
  for (final item in value) {
    if (item is Map) {
      final normalized = <String, Object?>{};
      for (final entry in item.entries) {
        final key = entry.key;
        if (key is String) {
          normalized[key] = entry.value;
        }
      }
      final scenario = ScenarioPolicy.tryParse(normalized);
      if (scenario != null) {
        parsed.add(scenario);
      }
    }
  }
  return parsed;
}
