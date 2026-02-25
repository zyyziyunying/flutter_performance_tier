import 'dart:io';

import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Platform field integrity', () {
    test(
      'android native handler keeps method-channel contract and keys',
      () async {
        final source = await File(_androidHandlerPath).readAsString();

        expect(source, contains(_channelName));
        expect(source, contains(_collectMethod));
        for (final key in _androidExpectedKeys) {
          expect(source, contains('"$key"'));
        }
      },
    );

    test('ios native handler keeps method-channel contract and keys', () async {
      final source = await File(_iosAppDelegatePath).readAsString();

      expect(source, contains(_channelName));
      expect(source, contains(_collectMethod));
      for (final key in _iosExpectedKeys) {
        expect(source, contains('"$key"'));
      }
    });

    test('parses complete android payload with deviceModel signal', () {
      final collectedAt = DateTime(2026, 2, 25, 12);
      final signals = DeviceSignals.fromMap(<String, Object?>{
        'platform': 'android',
        'deviceModel': 'Pixel 8 Pro',
        'totalRamBytes': 8 * _bytesPerGb,
        'isLowRamDevice': false,
        'mediaPerformanceClass': 13,
        'sdkInt': 35,
        'memoryPressureState': 'moderate',
        'memoryPressureLevel': 1,
      }, collectedAt: collectedAt);

      expect(signals.platform, 'android');
      expect(signals.deviceModel, 'Pixel 8 Pro');
      expect(signals.totalRamBytes, 8 * _bytesPerGb);
      expect(signals.totalRamMb, 8192);
      expect(signals.isLowRamDevice, isFalse);
      expect(signals.mediaPerformanceClass, 13);
      expect(signals.sdkInt, 35);
      expect(signals.thermalState, isNull);
      expect(signals.thermalStateLevel, isNull);
      expect(signals.isLowPowerModeEnabled, isNull);
      expect(signals.memoryPressureState, 'moderate');
      expect(signals.memoryPressureLevel, 1);
      expect(signals.toMap().keys, containsAll(_allSignalKeys));
    });

    test(
      'parses ios payload when optional mediaPerformanceClass is absent',
      () {
        final collectedAt = DateTime(2026, 2, 25, 12);
        final signals = DeviceSignals.fromMap(<String, Object?>{
          'platform': 'ios',
          'deviceModel': 'iPhone16,2',
          'totalRamBytes': '${6 * _bytesPerGb}',
          'isLowRamDevice': 'false',
          'sdkInt': 18,
          'thermalState': 'serious',
          'thermalStateLevel': 2,
          'isLowPowerModeEnabled': true,
          'memoryPressureState': 'critical',
          'memoryPressureLevel': 2,
        }, collectedAt: collectedAt);

        expect(signals.platform, 'ios');
        expect(signals.deviceModel, 'iPhone16,2');
        expect(signals.totalRamBytes, 6 * _bytesPerGb);
        expect(signals.isLowRamDevice, isFalse);
        expect(signals.mediaPerformanceClass, isNull);
        expect(signals.sdkInt, 18);
        expect(signals.thermalState, 'serious');
        expect(signals.thermalStateLevel, 2);
        expect(signals.isLowPowerModeEnabled, isTrue);
        expect(signals.memoryPressureState, 'critical');
        expect(signals.memoryPressureLevel, 2);
        expect(signals.toMap().keys, containsAll(_allSignalKeys));
      },
    );
  });
}

const String _androidHandlerPath =
    'android/app/src/main/kotlin/com/example/flutter_performance_tier/DeviceSignalChannelHandler.kt';
const String _iosAppDelegatePath = 'ios/Runner/AppDelegate.swift';

const String _channelName = 'performance_tier/device_signals';
const String _collectMethod = 'collectDeviceSignals';
const int _bytesPerGb = 1024 * 1024 * 1024;

const List<String> _androidExpectedKeys = <String>[
  'platform',
  'deviceModel',
  'totalRamBytes',
  'isLowRamDevice',
  'mediaPerformanceClass',
  'sdkInt',
  'memoryPressureState',
  'memoryPressureLevel',
];

const List<String> _iosExpectedKeys = <String>[
  'platform',
  'deviceModel',
  'totalRamBytes',
  'isLowRamDevice',
  'sdkInt',
  'thermalState',
  'thermalStateLevel',
  'isLowPowerModeEnabled',
  'memoryPressureState',
  'memoryPressureLevel',
];

const List<String> _allSignalKeys = <String>[
  'platform',
  'deviceModel',
  'totalRamBytes',
  'isLowRamDevice',
  'mediaPerformanceClass',
  'sdkInt',
  'thermalState',
  'thermalStateLevel',
  'isLowPowerModeEnabled',
  'memoryPressureState',
  'memoryPressureLevel',
  'collectedAt',
];
