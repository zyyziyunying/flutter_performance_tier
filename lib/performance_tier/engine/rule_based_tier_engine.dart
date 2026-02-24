import '../config/tier_config.dart';
import '../model/device_signals.dart';
import '../model/tier_confidence.dart';
import '../model/tier_decision.dart';
import '../model/tier_level.dart';
import 'tier_engine.dart';

class RuleBasedTierEngine implements TierEngine {
  const RuleBasedTierEngine();

  @override
  TierDecision evaluate({
    required DeviceSignals signals,
    required TierConfig config,
  }) {
    final reasons = <String>[];

    var tier = _resolveTierByRam(signals.totalRamBytes, config, reasons);

    var allowMediaClassUpgrade = true;
    if (signals.isLowRamDevice == true) {
      reasons.add('Android reported isLowRamDevice=true.');
      tier = TierLevel.t0Low;
      allowMediaClassUpgrade = false;
    } else if (signals.isLowRamDevice == false) {
      reasons.add('Android reported isLowRamDevice=false.');
    }

    if (allowMediaClassUpgrade) {
      final mediaPerformanceClass = signals.mediaPerformanceClass;
      if (mediaPerformanceClass != null &&
          mediaPerformanceClass >= config.ultraMediaPerformanceClass) {
        reasons.add(
          'mediaPerformanceClass=$mediaPerformanceClass >= '
          '${config.ultraMediaPerformanceClass}.',
        );
        tier = _maxTier(tier, TierLevel.t3Ultra);
      } else if (mediaPerformanceClass != null &&
          mediaPerformanceClass >= config.highMediaPerformanceClass) {
        reasons.add(
          'mediaPerformanceClass=$mediaPerformanceClass >= '
          '${config.highMediaPerformanceClass}.',
        );
        tier = _maxTier(tier, TierLevel.t2High);
      }
    }

    return TierDecision(
      tier: tier,
      confidence: _resolveConfidence(signals),
      deviceSignals: signals,
      reasons: reasons,
    );
  }

  TierLevel _resolveTierByRam(
    int? totalRamBytes,
    TierConfig config,
    List<String> reasons,
  ) {
    if (totalRamBytes == null) {
      reasons.add('totalRamBytes missing, fallback to mid tier.');
      return TierLevel.t1Mid;
    }

    reasons.add('totalRamBytes=$totalRamBytes.');

    if (totalRamBytes <= config.lowRamMaxBytes) {
      return TierLevel.t0Low;
    }
    if (totalRamBytes <= config.midRamMaxBytes) {
      return TierLevel.t1Mid;
    }
    if (totalRamBytes <= config.highRamMaxBytes) {
      return TierLevel.t2High;
    }
    return TierLevel.t3Ultra;
  }

  TierConfidence _resolveConfidence(DeviceSignals signals) {
    final hasRam = signals.totalRamBytes != null;
    final hasLowRam = signals.isLowRamDevice != null;
    final hasMpc = signals.mediaPerformanceClass != null;

    if (hasRam && hasLowRam && hasMpc) {
      return TierConfidence.high;
    }
    if (hasRam || hasLowRam || hasMpc) {
      return TierConfidence.medium;
    }
    return TierConfidence.low;
  }

  TierLevel _maxTier(TierLevel lhs, TierLevel rhs) {
    if (lhs.index >= rhs.index) {
      return lhs;
    }
    return rhs;
  }
}
