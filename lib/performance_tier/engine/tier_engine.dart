import '../config/tier_config.dart';
import '../model/device_signals.dart';
import '../model/tier_decision.dart';

abstract interface class TierEngine {
  TierDecision evaluate({
    required DeviceSignals signals,
    required TierConfig config,
  });
}
