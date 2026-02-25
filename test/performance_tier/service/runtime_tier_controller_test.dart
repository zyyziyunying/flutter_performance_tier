import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuntimeTierController', () {
    test('keeps base tier when no runtime pressure signal', () {
      final clock = _FakeClock(DateTime(2026, 2, 25, 12, 0, 0));
      final controller = RuntimeTierController(now: clock.now);

      final adjustment = controller.adjust(
        baseTier: TierLevel.t3Ultra,
        signals: _iosSignals(
          collectedAt: clock.now(),
          thermalStateLevel: 0,
          isLowPowerModeEnabled: false,
        ),
      );

      expect(adjustment.tier, TierLevel.t3Ultra);
      expect(adjustment.reasons, isEmpty);
    });

    test('waits for debounce window before applying downgrade', () {
      final clock = _FakeClock(DateTime(2026, 2, 25, 12, 0, 0));
      final controller = RuntimeTierController(
        now: clock.now,
        config: const RuntimeTierControllerConfig(
          downgradeDebounce: Duration(seconds: 5),
          recoveryCooldown: Duration(seconds: 15),
        ),
      );

      final first = controller.adjust(
        baseTier: TierLevel.t3Ultra,
        signals: _iosSignals(
          collectedAt: clock.now(),
          isLowPowerModeEnabled: true,
        ),
      );
      expect(first.tier, TierLevel.t3Ultra);
      expect(first.reasons.single, contains('Runtime downgrade pending'));

      clock.advance(const Duration(seconds: 5));
      final second = controller.adjust(
        baseTier: TierLevel.t3Ultra,
        signals: _iosSignals(
          collectedAt: clock.now(),
          isLowPowerModeEnabled: true,
        ),
      );
      expect(second.tier, TierLevel.t2High);
      expect(second.reasons.single, contains('Runtime downgrade active'));
    });

    test('recovers in throttled upgrade steps after cooldown', () {
      final clock = _FakeClock(DateTime(2026, 2, 25, 12, 0, 0));
      final controller = RuntimeTierController(
        now: clock.now,
        config: const RuntimeTierControllerConfig(
          downgradeDebounce: Duration.zero,
          recoveryCooldown: Duration(seconds: 20),
          upgradeDebounce: Duration(seconds: 5),
        ),
      );

      final activated = controller.adjust(
        baseTier: TierLevel.t3Ultra,
        signals: _iosSignals(collectedAt: clock.now(), thermalStateLevel: 2),
      );
      expect(activated.tier, TierLevel.t1Mid);

      clock.advance(const Duration(seconds: 10));
      final inCooldown = controller.adjust(
        baseTier: TierLevel.t3Ultra,
        signals: _iosSignals(collectedAt: clock.now(), thermalStateLevel: 0),
      );
      expect(inCooldown.tier, TierLevel.t1Mid);
      expect(inCooldown.reasons.single, contains('Runtime cooldown active'));

      clock.advance(const Duration(seconds: 11));
      final firstUpgrade = controller.adjust(
        baseTier: TierLevel.t3Ultra,
        signals: _iosSignals(collectedAt: clock.now(), thermalStateLevel: 0),
      );
      expect(firstUpgrade.tier, TierLevel.t2High);
      expect(firstUpgrade.reasons.single, contains('Runtime upgrade step'));

      clock.advance(const Duration(seconds: 4));
      final pendingUpgrade = controller.adjust(
        baseTier: TierLevel.t3Ultra,
        signals: _iosSignals(collectedAt: clock.now(), thermalStateLevel: 0),
      );
      expect(pendingUpgrade.tier, TierLevel.t2High);
      expect(
        pendingUpgrade.reasons.single,
        contains('Runtime recovery pending'),
      );

      clock.advance(const Duration(seconds: 1));
      final recovered = controller.adjust(
        baseTier: TierLevel.t3Ultra,
        signals: _iosSignals(collectedAt: clock.now(), thermalStateLevel: 0),
      );
      expect(recovered.tier, TierLevel.t3Ultra);
      expect(recovered.reasons.single, contains('Runtime downgrade recovered'));
    });

    test('maps critical thermal pressure to the lowest tier', () {
      final clock = _FakeClock(DateTime(2026, 2, 25, 12, 0, 0));
      final controller = RuntimeTierController(
        now: clock.now,
        config: const RuntimeTierControllerConfig(
          downgradeDebounce: Duration.zero,
          recoveryCooldown: Duration.zero,
        ),
      );

      final adjustment = controller.adjust(
        baseTier: TierLevel.t3Ultra,
        signals: _iosSignals(
          collectedAt: clock.now(),
          thermalState: 'critical',
          thermalStateLevel: null,
        ),
      );

      expect(adjustment.tier, TierLevel.t0Low);
      expect(adjustment.reasons.single, contains('thermalState=critical'));
    });

    test('downgrades tier when memory pressure is critical', () {
      final clock = _FakeClock(DateTime(2026, 2, 25, 12, 0, 0));
      final controller = RuntimeTierController(
        now: clock.now,
        config: const RuntimeTierControllerConfig(
          downgradeDebounce: Duration.zero,
          recoveryCooldown: Duration.zero,
        ),
      );

      final adjustment = controller.adjust(
        baseTier: TierLevel.t3Ultra,
        signals: _iosSignals(
          collectedAt: clock.now(),
          thermalStateLevel: 0,
          isLowPowerModeEnabled: false,
          memoryPressureState: 'critical',
        ),
      );

      expect(adjustment.tier, TierLevel.t1Mid);
      expect(adjustment.reasons.single, contains('memoryPressure=critical'));
    });
  });
}

DeviceSignals _iosSignals({
  required DateTime collectedAt,
  int? thermalStateLevel,
  String? thermalState,
  bool? isLowPowerModeEnabled,
  String? memoryPressureState,
  int? memoryPressureLevel,
}) {
  return DeviceSignals(
    platform: 'ios',
    collectedAt: collectedAt,
    thermalStateLevel: thermalStateLevel,
    thermalState: thermalState,
    isLowPowerModeEnabled: isLowPowerModeEnabled,
    memoryPressureState: memoryPressureState,
    memoryPressureLevel: memoryPressureLevel,
  );
}

class _FakeClock {
  _FakeClock(this._value);

  DateTime _value;

  DateTime now() => _value;

  void advance(Duration delta) {
    _value = _value.add(delta);
  }
}
