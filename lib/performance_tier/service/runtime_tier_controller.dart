import 'package:flutter/foundation.dart';

import '../model/device_signals.dart';
import '../model/tier_level.dart';

@immutable
class RuntimeTierControllerConfig {
  const RuntimeTierControllerConfig({
    this.downgradeDebounce = const Duration(seconds: 5),
    this.recoveryCooldown = const Duration(seconds: 30),
    this.fairThermalStateLevel = 1,
    this.seriousThermalStateLevel = 2,
    this.criticalThermalStateLevel = 3,
  }) : assert(fairThermalStateLevel >= 0),
       assert(seriousThermalStateLevel >= fairThermalStateLevel),
       assert(criticalThermalStateLevel >= seriousThermalStateLevel);

  final Duration downgradeDebounce;
  final Duration recoveryCooldown;
  final int fairThermalStateLevel;
  final int seriousThermalStateLevel;
  final int criticalThermalStateLevel;
}

@immutable
class RuntimeTierAdjustment {
  RuntimeTierAdjustment({
    required this.tier,
    List<String> reasons = const <String>[],
  }) : reasons = List<String>.unmodifiable(reasons);

  final TierLevel tier;
  final List<String> reasons;
}

class RuntimeTierController {
  RuntimeTierController({
    this.config = const RuntimeTierControllerConfig(),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final RuntimeTierControllerConfig config;
  final DateTime Function() _now;

  DateTime? _pendingDowngradeAt;
  DateTime? _lastDowngradeSignalAt;
  int? _activeDowngradeSteps;
  String? _activeSignalDescription;

  RuntimeTierAdjustment adjust({
    required TierLevel baseTier,
    required DeviceSignals signals,
  }) {
    final now = _now();
    final signal = _resolveRuntimeSignal(signals);

    if (signal.downgradeSteps > 0) {
      return _handleDowngradeSignal(
        signal: signal,
        now: now,
        baseTier: baseTier,
      );
    }

    return _handleNoDowngradeSignal(now: now, baseTier: baseTier);
  }

  RuntimeTierAdjustment _handleDowngradeSignal({
    required _RuntimePressureSignal signal,
    required DateTime now,
    required TierLevel baseTier,
  }) {
    if (_activeDowngradeSteps == null) {
      _pendingDowngradeAt ??= now;
      final pendingFor = now.difference(_pendingDowngradeAt!);
      if (pendingFor < config.downgradeDebounce) {
        final remaining = config.downgradeDebounce - pendingFor;
        return RuntimeTierAdjustment(
          tier: baseTier,
          reasons: <String>[
            'Runtime downgrade pending: ${signal.description}; '
                'debounceRemainingMs=${remaining.inMilliseconds}.',
          ],
        );
      }
    }

    _pendingDowngradeAt = null;
    _activeDowngradeSteps = signal.downgradeSteps;
    _activeSignalDescription = signal.description;
    _lastDowngradeSignalAt = now;

    final downgradedTier = _downgrade(baseTier, _activeDowngradeSteps!);
    return RuntimeTierAdjustment(
      tier: downgradedTier,
      reasons: <String>[
        'Runtime downgrade active: ${signal.description}; '
            'downgradeSteps=${_activeDowngradeSteps!}, '
            'tier=${baseTier.name}->${downgradedTier.name}.',
      ],
    );
  }

  RuntimeTierAdjustment _handleNoDowngradeSignal({
    required DateTime now,
    required TierLevel baseTier,
  }) {
    _pendingDowngradeAt = null;

    final activeSteps = _activeDowngradeSteps;
    if (activeSteps == null) {
      return RuntimeTierAdjustment(tier: baseTier);
    }

    final lastSignalAt = _lastDowngradeSignalAt;
    if (lastSignalAt == null) {
      _clearActiveDowngrade();
      return RuntimeTierAdjustment(tier: baseTier);
    }

    final elapsed = now.difference(lastSignalAt);
    if (elapsed < config.recoveryCooldown) {
      final downgradedTier = _downgrade(baseTier, activeSteps);
      final remaining = config.recoveryCooldown - elapsed;
      return RuntimeTierAdjustment(
        tier: downgradedTier,
        reasons: <String>[
          'Runtime cooldown active: ${_activeSignalDescription ?? 'runtime pressure'}; '
              'cooldownRemainingMs=${remaining.inMilliseconds}, '
              'tier=${baseTier.name}->${downgradedTier.name}.',
        ],
      );
    }

    final recoveredFrom = _activeSignalDescription ?? 'runtime pressure';
    _clearActiveDowngrade();
    return RuntimeTierAdjustment(
      tier: baseTier,
      reasons: <String>[
        'Runtime downgrade recovered after cooldown: $recoveredFrom.',
      ],
    );
  }

  _RuntimePressureSignal _resolveRuntimeSignal(DeviceSignals signals) {
    var downgradeSteps = 0;
    final reasons = <String>[];

    final thermalStateLevel = _resolveThermalStateLevel(signals);
    if (thermalStateLevel != null) {
      if (thermalStateLevel >= config.criticalThermalStateLevel) {
        downgradeSteps = 3;
        reasons.add('thermalState=critical(level=$thermalStateLevel)');
      } else if (thermalStateLevel >= config.seriousThermalStateLevel) {
        downgradeSteps = 2;
        reasons.add('thermalState=serious(level=$thermalStateLevel)');
      } else if (thermalStateLevel >= config.fairThermalStateLevel) {
        downgradeSteps = 1;
        reasons.add('thermalState=fair(level=$thermalStateLevel)');
      }
    }

    if (signals.isLowPowerModeEnabled == true) {
      if (downgradeSteps < 1) {
        downgradeSteps = 1;
      }
      reasons.add('lowPowerMode=true');
    }

    final description = reasons.isEmpty
        ? 'runtime pressure'
        : reasons.join(', ');
    return _RuntimePressureSignal(
      downgradeSteps: downgradeSteps,
      description: description,
    );
  }

  int? _resolveThermalStateLevel(DeviceSignals signals) {
    final numericLevel = signals.thermalStateLevel;
    if (numericLevel != null) {
      if (numericLevel < 0) {
        return 0;
      }
      return numericLevel;
    }

    final thermalState = signals.thermalState?.trim().toLowerCase();
    if (thermalState == null || thermalState.isEmpty) {
      return null;
    }

    return switch (thermalState) {
      'critical' => config.criticalThermalStateLevel,
      'serious' || 'severe' => config.seriousThermalStateLevel,
      'fair' || 'moderate' => config.fairThermalStateLevel,
      'nominal' || 'normal' => 0,
      _ => null,
    };
  }

  TierLevel _downgrade(TierLevel tier, int steps) {
    var index = tier.index - steps;
    if (index < 0) {
      index = 0;
    }
    return TierLevel.values[index];
  }

  void _clearActiveDowngrade() {
    _activeDowngradeSteps = null;
    _activeSignalDescription = null;
    _lastDowngradeSignalAt = null;
  }
}

class _RuntimePressureSignal {
  const _RuntimePressureSignal({
    required this.downgradeSteps,
    required this.description,
  });

  final int downgradeSteps;
  final String description;
}
