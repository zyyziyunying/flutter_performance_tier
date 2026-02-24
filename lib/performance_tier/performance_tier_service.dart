import 'model/tier_decision.dart';

abstract interface class PerformanceTierService {
  Future<void> initialize();

  Future<TierDecision> getCurrentDecision();

  Stream<TierDecision> watchDecision();

  Future<void> refresh();
}
