import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/default_performance_tier_service_test_support.dart';

void main() {
  group('DefaultPerformanceTierService initialization baseline', () {
    test('returns first decision within 300ms budget', () async {
      const warmupRuns = 5;
      const measuredRuns = 40;
      final latenciesUs = <int>[];

      for (var i = 0; i < warmupRuns + measuredRuns; i++) {
        final service = DefaultPerformanceTierService(
          signalCollector: SequenceSignalCollector(<DeviceSignals>[
            androidSignals(
              ramBytes: 8 * bytesPerGb,
              mediaPerformanceClass: 13,
              sdkInt: 35,
            ),
          ]),
          configProvider: const DefaultConfigProvider(),
          engine: const RuleBasedTierEngine(),
          policyResolver: const DefaultPolicyResolver(),
        );

        final stopwatch = Stopwatch()..start();
        await service.initialize();
        await service.getCurrentDecision();
        stopwatch.stop();
        await service.dispose();

        if (i >= warmupRuns) {
          latenciesUs.add(stopwatch.elapsedMicroseconds);
        }
      }

      latenciesUs.sort();
      final p50Us = percentile(latenciesUs, percentile: 0.50);
      final p95Us = percentile(latenciesUs, percentile: 0.95);
      final maxUs = latenciesUs.last;
      final report = <String, Object>{
        'tag': 'PERF_TIER_TEST_RESULT',
        'suite': 'default_performance_tier_service.initialize_baseline',
        'warmupRuns': warmupRuns,
        'measuredRuns': measuredRuns,
        'metrics': <String, Object>{
          'p50Ms': toMillisecondsValue(p50Us),
          'p95Ms': toMillisecondsValue(p95Us),
          'maxMs': toMillisecondsValue(maxUs),
          'p50Us': p50Us,
          'p95Us': p95Us,
          'maxUs': maxUs,
        },
        'budget': const <String, Object>{'p95MsMax': 300},
        'result': p95Us <= 300000 ? 'pass' : 'fail',
      };
      debugPrint('PERF_TIER_TEST_RESULT ${jsonEncode(report)}');

      expect(
        p95Us,
        lessThanOrEqualTo(300000),
        reason:
            'Expected p95<=300ms but got p95=${toMilliseconds(p95Us)}ms, '
            'max=${toMilliseconds(maxUs)}ms.',
      );
    });
  });
}

int percentile(List<int> sortedValues, {required double percentile}) {
  if (sortedValues.isEmpty) {
    throw ArgumentError('sortedValues must not be empty.');
  }
  var index = (sortedValues.length * percentile).ceil() - 1;
  if (index < 0) {
    index = 0;
  }
  if (index >= sortedValues.length) {
    index = sortedValues.length - 1;
  }
  return sortedValues[index];
}

String toMilliseconds(int microseconds) {
  return (microseconds / 1000).toStringAsFixed(2);
}

double toMillisecondsValue(int microseconds) {
  return microseconds / 1000;
}
