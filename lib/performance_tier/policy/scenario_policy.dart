import 'package:flutter/foundation.dart';

@immutable
class ScenarioPolicy {
  const ScenarioPolicy({
    required this.id,
    required this.displayName,
    required this.knobs,
    required this.acceptanceTargets,
  });

  final String id;
  final String displayName;
  final Map<String, Object> knobs;
  final Map<String, Object> acceptanceTargets;

  factory ScenarioPolicy.fromMap(Map<String, Object?> map) {
    final parsed = tryParse(map);
    if (parsed == null) {
      throw const FormatException('Invalid scenario policy payload.');
    }
    return parsed;
  }

  static ScenarioPolicy? tryParse(Map<String, Object?> map) {
    final id = _asNonEmptyString(map['id']);
    final displayName = _asNonEmptyString(map['displayName']);
    final knobs = _asObjectMap(map['knobs']);
    final acceptanceTargets = _asObjectMap(map['acceptanceTargets']);
    if (id == null ||
        displayName == null ||
        knobs == null ||
        acceptanceTargets == null) {
      return null;
    }

    return ScenarioPolicy(
      id: id,
      displayName: displayName,
      knobs: knobs,
      acceptanceTargets: acceptanceTargets,
    );
  }

  Map<String, Object> toMap() {
    return <String, Object>{
      'id': id,
      'displayName': displayName,
      'knobs': knobs,
      'acceptanceTargets': acceptanceTargets,
    };
  }
}

String? _asNonEmptyString(Object? value) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  return null;
}

Map<String, Object>? _asObjectMap(Object? value) {
  if (value is Map) {
    final normalized = <String, Object>{};
    for (final entry in value.entries) {
      final key = entry.key;
      final fieldValue = entry.value;
      if (key is String && fieldValue is Object) {
        normalized[key] = fieldValue;
      }
    }
    return normalized;
  }
  return null;
}
