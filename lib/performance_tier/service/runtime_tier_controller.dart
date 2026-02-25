import 'package:flutter/foundation.dart';

import '../model/device_signals.dart';
import '../model/runtime_tier_observation.dart';
import '../model/tier_level.dart';

@immutable
class RuntimeTierControllerConfig {
  const RuntimeTierControllerConfig({
    this.downgradeDebounce = const Duration(seconds: 5),
    this.recoveryCooldown = const Duration(seconds: 30),
    this.upgradeDebounce = const Duration(seconds: 10),
    this.fairThermalStateLevel = 1,
    this.seriousThermalStateLevel = 2,
    this.criticalThermalStateLevel = 3,
    this.moderateMemoryPressureLevel = 1,
    this.criticalMemoryPressureLevel = 2,
  }) : assert(fairThermalStateLevel >= 0),
       assert(seriousThermalStateLevel >= fairThermalStateLevel),
       assert(criticalThermalStateLevel >= seriousThermalStateLevel),
       assert(moderateMemoryPressureLevel >= 0),
       assert(criticalMemoryPressureLevel >= moderateMemoryPressureLevel);

  final Duration downgradeDebounce;
  final Duration recoveryCooldown;
  final Duration upgradeDebounce;
  final int fairThermalStateLevel;
  final int seriousThermalStateLevel;
  final int criticalThermalStateLevel;
  final int moderateMemoryPressureLevel;
  final int criticalMemoryPressureLevel;
}

@immutable
class RuntimeTierAdjustment {
  RuntimeTierAdjustment({
    required this.tier,
    this.observation = const RuntimeTierObservation(),
    List<String> reasons = const <String>[],
  }) : reasons = List<String>.unmodifiable(reasons);

  final TierLevel tier;
  final RuntimeTierObservation observation;
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
  DateTime? _pendingUpgradeAt;
  DateTime? _lastDowngradeSignalAt;
  int? _pendingUpgradeTargetSteps;
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
    final activeSteps = _activeDowngradeSteps;
    if (activeSteps == null) {
      _pendingDowngradeAt ??= now;
      final pendingFor = now.difference(_pendingDowngradeAt!);
      if (pendingFor < config.downgradeDebounce) {
        final remaining = config.downgradeDebounce - pendingFor;
        return RuntimeTierAdjustment(
          tier: baseTier,
          observation: RuntimeTierObservation(
            status: RuntimeTierStatus.pending,
            triggerReason: signal.description,
          ),
          reasons: <String>[
            'Runtime downgrade pending: ${signal.description}; '
                'debounceRemainingMs=${remaining.inMilliseconds}.',
          ],
        );
      }

      _pendingDowngradeAt = null;
      _clearPendingUpgrade();
      _activeDowngradeSteps = signal.downgradeSteps;
      _activeSignalDescription = signal.description;
      _lastDowngradeSignalAt = now;

      final downgradedTier = _downgrade(baseTier, _activeDowngradeSteps!);
      return RuntimeTierAdjustment(
        tier: downgradedTier,
        observation: RuntimeTierObservation(
          status: RuntimeTierStatus.active,
          triggerReason: signal.description,
        ),
        reasons: <String>[
          'Runtime downgrade active: ${signal.description}; '
              'downgradeSteps=${_activeDowngradeSteps!}, '
              'tier=${baseTier.name}->${downgradedTier.name}.',
        ],
      );
    }

    _lastDowngradeSignalAt = now;
    _pendingDowngradeAt = null;

    if (signal.downgradeSteps >= activeSteps) {
      _clearPendingUpgrade();
      _activeDowngradeSteps = signal.downgradeSteps;
      _activeSignalDescription = signal.description;

      final downgradedTier = _downgrade(baseTier, _activeDowngradeSteps!);
      return RuntimeTierAdjustment(
        tier: downgradedTier,
        observation: RuntimeTierObservation(
          status: RuntimeTierStatus.active,
          triggerReason: signal.description,
        ),
        reasons: <String>[
          'Runtime downgrade active: ${signal.description}; '
              'downgradeSteps=${_activeDowngradeSteps!}, '
              'tier=${baseTier.name}->${downgradedTier.name}.',
        ],
      );
    }

    return _handleUpgradeThrottle(
      now: now,
      baseTier: baseTier,
      targetDowngradeSteps: signal.downgradeSteps,
      targetDescription: signal.description,
    );
  }

  RuntimeTierAdjustment _handleNoDowngradeSignal({
    required DateTime now,
    required TierLevel baseTier,
  }) {
    _pendingDowngradeAt = null;

    final activeSteps = _activeDowngradeSteps;
    if (activeSteps == null) {
      _clearPendingUpgrade();
      return RuntimeTierAdjustment(
        tier: baseTier,
        observation: const RuntimeTierObservation(
          status: RuntimeTierStatus.inactive,
        ),
      );
    }

    return _handleUpgradeThrottle(
      now: now,
      baseTier: baseTier,
      targetDowngradeSteps: 0,
      targetDescription: 'no runtime pressure',
    );
  }

  RuntimeTierAdjustment _handleUpgradeThrottle({
    required DateTime now,
    required TierLevel baseTier,
    required int targetDowngradeSteps,
    required String targetDescription,
  }) {
    final activeSteps = _activeDowngradeSteps;
    if (activeSteps == null || targetDowngradeSteps >= activeSteps) {
      return RuntimeTierAdjustment(
        tier: baseTier,
        observation: const RuntimeTierObservation(
          status: RuntimeTierStatus.inactive,
        ),
      );
    }

    if (targetDowngradeSteps == 0) {
      final lastSignalAt = _lastDowngradeSignalAt;
      if (lastSignalAt != null) {
        if (_pendingUpgradeTargetSteps != targetDowngradeSteps) {
          _pendingUpgradeTargetSteps = targetDowngradeSteps;
          _pendingUpgradeAt = now;
        }
        _pendingUpgradeAt ??= now;

        final elapsed = now.difference(lastSignalAt);
        if (elapsed < config.recoveryCooldown) {
          final downgradedTier = _downgrade(baseTier, activeSteps);
          final remaining = config.recoveryCooldown - elapsed;
          final triggerReason = _activeSignalDescription ?? 'runtime pressure';
          return RuntimeTierAdjustment(
            tier: downgradedTier,
            observation: RuntimeTierObservation(
              status: RuntimeTierStatus.cooldown,
              triggerReason: triggerReason,
            ),
            reasons: <String>[
              'Runtime cooldown active: $triggerReason; '
                  'cooldownRemainingMs=${remaining.inMilliseconds}, '
                  'tier=${baseTier.name}->${downgradedTier.name}.',
            ],
          );
        }
      }
    }

    if (_pendingUpgradeTargetSteps != targetDowngradeSteps) {
      _pendingUpgradeTargetSteps = targetDowngradeSteps;
      _pendingUpgradeAt = now;
    }
    _pendingUpgradeAt ??= now;

    final pendingFor = now.difference(_pendingUpgradeAt!);
    if (pendingFor < config.upgradeDebounce) {
      final downgradedTier = _downgrade(baseTier, activeSteps);
      final remaining = config.upgradeDebounce - pendingFor;
      final reasonPrefix = targetDowngradeSteps == 0
          ? 'Runtime recovery pending'
          : 'Runtime upgrade pending';
      final triggerReason = targetDowngradeSteps == 0
          ? (_activeSignalDescription ?? 'runtime pressure')
          : targetDescription;
      return RuntimeTierAdjustment(
        tier: downgradedTier,
        observation: RuntimeTierObservation(
          status: RuntimeTierStatus.recoveryPending,
          triggerReason: triggerReason,
        ),
        reasons: <String>[
          '$reasonPrefix: $triggerReason; '
              'upgradeDebounceRemainingMs=${remaining.inMilliseconds}, '
              'tier=${baseTier.name}->${downgradedTier.name}.',
        ],
      );
    }

    final nextSteps = activeSteps - 1;
    if (nextSteps <= 0) {
      final recoveredFrom = _activeSignalDescription ?? 'runtime pressure';
      _clearActiveDowngrade();
      return RuntimeTierAdjustment(
        tier: baseTier,
        observation: RuntimeTierObservation(
          status: RuntimeTierStatus.recovered,
          triggerReason: recoveredFrom,
        ),
        reasons: <String>[
          'Runtime downgrade recovered after throttled upgrade: $recoveredFrom.',
        ],
      );
    }

    _activeDowngradeSteps = nextSteps;
    if (targetDowngradeSteps > 0 && nextSteps <= targetDowngradeSteps) {
      _activeSignalDescription = targetDescription;
    }
    _pendingUpgradeAt = now;
    final downgradedTier = _downgrade(baseTier, nextSteps);
    final triggerReason = targetDowngradeSteps == 0
        ? (_activeSignalDescription ?? 'runtime pressure')
        : targetDescription;
    return RuntimeTierAdjustment(
      tier: downgradedTier,
      observation: RuntimeTierObservation(
        status: RuntimeTierStatus.active,
        triggerReason: triggerReason,
      ),
      reasons: <String>[
        'Runtime upgrade step applied: $triggerReason; '
            'downgradeSteps=$activeSteps->$nextSteps, '
            'targetDowngradeSteps=$targetDowngradeSteps, '
            'tier=${baseTier.name}->${downgradedTier.name}.',
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

    final memoryPressureLevel = _resolveMemoryPressureLevel(signals);
    if (memoryPressureLevel != null) {
      if (memoryPressureLevel >= config.criticalMemoryPressureLevel) {
        if (downgradeSteps < 2) {
          downgradeSteps = 2;
        }
        reasons.add('memoryPressure=critical(level=$memoryPressureLevel)');
      } else if (memoryPressureLevel >= config.moderateMemoryPressureLevel) {
        if (downgradeSteps < 1) {
          downgradeSteps = 1;
        }
        reasons.add('memoryPressure=moderate(level=$memoryPressureLevel)');
      }
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

  int? _resolveMemoryPressureLevel(DeviceSignals signals) {
    final numericLevel = signals.memoryPressureLevel;
    if (numericLevel != null) {
      if (numericLevel < 0) {
        return 0;
      }
      return numericLevel;
    }

    final memoryPressureState = signals.memoryPressureState
        ?.trim()
        .toLowerCase();
    if (memoryPressureState == null || memoryPressureState.isEmpty) {
      return null;
    }

    return switch (memoryPressureState) {
      'critical' || 'severe' || 'high' => config.criticalMemoryPressureLevel,
      'moderate' ||
      'warning' ||
      'elevated' => config.moderateMemoryPressureLevel,
      'nominal' || 'normal' || 'none' || 'low' => 0,
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
    _clearPendingUpgrade();
  }

  void _clearPendingUpgrade() {
    _pendingUpgradeAt = null;
    _pendingUpgradeTargetSteps = null;
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
