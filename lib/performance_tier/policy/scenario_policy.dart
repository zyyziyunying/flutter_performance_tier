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

  Map<String, Object> toMap() {
    return <String, Object>{
      'id': id,
      'displayName': displayName,
      'knobs': knobs,
      'acceptanceTargets': acceptanceTargets,
    };
  }
}
