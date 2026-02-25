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

    tier = _applySdkVersionCaps(
      tier: tier,
      sdkInt: signals.sdkInt,
      config: config,
      reasons: reasons,
    );
    tier = _applyModelTierCaps(
      tier: tier,
      deviceModel: signals.deviceModel,
      config: config,
      reasons: reasons,
    );

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

  TierLevel _minTier(TierLevel lhs, TierLevel rhs) {
    if (lhs.index <= rhs.index) {
      return lhs;
    }
    return rhs;
  }

  TierLevel _applySdkVersionCaps({
    required TierLevel tier,
    required int? sdkInt,
    required TierConfig config,
    required List<String> reasons,
  }) {
    if (sdkInt == null) {
      return tier;
    }

    var resolvedTier = tier;
    if (config.minSdkForUltraTier > 0 &&
        sdkInt < config.minSdkForUltraTier &&
        resolvedTier.index > TierLevel.t2High.index) {
      reasons.add(
        'sdkInt=$sdkInt < minSdkForUltraTier=${config.minSdkForUltraTier}, '
        'cap to ${TierLevel.t2High.name}.',
      );
      resolvedTier = _minTier(resolvedTier, TierLevel.t2High);
    }
    if (config.minSdkForHighTier > 0 &&
        sdkInt < config.minSdkForHighTier &&
        resolvedTier.index > TierLevel.t1Mid.index) {
      reasons.add(
        'sdkInt=$sdkInt < minSdkForHighTier=${config.minSdkForHighTier}, '
        'cap to ${TierLevel.t1Mid.name}.',
      );
      resolvedTier = _minTier(resolvedTier, TierLevel.t1Mid);
    }
    return resolvedTier;
  }

  TierLevel _applyModelTierCaps({
    required TierLevel tier,
    required String? deviceModel,
    required TierConfig config,
    required List<String> reasons,
  }) {
    if (deviceModel == null || deviceModel.isEmpty) {
      return tier;
    }

    var resolvedTier = tier;
    for (final rule in config.modelTierCaps) {
      if (!rule.matches(deviceModel)) {
        continue;
      }
      final cappedTier = _minTier(resolvedTier, rule.maxTier);
      reasons.add(
        'deviceModel="$deviceModel" matched "${rule.pattern}", '
        'max tier=${rule.maxTier.name}.',
      );
      resolvedTier = cappedTier;
      break;
    }
    return resolvedTier;
  }
}
