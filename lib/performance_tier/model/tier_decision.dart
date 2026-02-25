import 'package:flutter/foundation.dart';

import 'device_signals.dart';
import 'runtime_tier_observation.dart';
import 'tier_confidence.dart';
import 'tier_level.dart';

@immutable
class TierDecision {
  TierDecision({
    required this.tier,
    required this.confidence,
    required this.deviceSignals,
    List<String> reasons = const <String>[],
    Map<String, Object?> appliedPolicies = const <String, Object?>{},
    this.runtimeObservation = const RuntimeTierObservation(),
    DateTime? decidedAt,
  }) : reasons = List<String>.unmodifiable(reasons),
       appliedPolicies = Map<String, Object?>.unmodifiable(appliedPolicies),
       decidedAt = decidedAt ?? DateTime.now();

  final TierLevel tier;
  final TierConfidence confidence;
  final DeviceSignals deviceSignals;
  final List<String> reasons;
  final Map<String, Object?> appliedPolicies;
  final RuntimeTierObservation runtimeObservation;
  final DateTime decidedAt;

  TierDecision copyWith({
    TierLevel? tier,
    TierConfidence? confidence,
    DeviceSignals? deviceSignals,
    List<String>? reasons,
    Map<String, Object?>? appliedPolicies,
    RuntimeTierObservation? runtimeObservation,
    DateTime? decidedAt,
  }) {
    return TierDecision(
      tier: tier ?? this.tier,
      confidence: confidence ?? this.confidence,
      deviceSignals: deviceSignals ?? this.deviceSignals,
      reasons: reasons ?? this.reasons,
      appliedPolicies: appliedPolicies ?? this.appliedPolicies,
      runtimeObservation: runtimeObservation ?? this.runtimeObservation,
      decidedAt: decidedAt ?? this.decidedAt,
    );
  }
}
