import 'package:flutter_performance_tier/performance_tier/performance_tier.dart';

const int bytesPerGb = 1024 * 1024 * 1024;

class SequenceSignalCollector implements DeviceSignalCollector {
  SequenceSignalCollector(List<DeviceSignals> signals)
    : _signals = List<DeviceSignals>.from(signals);

  final List<DeviceSignals> _signals;
  int collectCallCount = 0;

  @override
  Future<DeviceSignals> collect() async {
    collectCallCount += 1;
    if (_signals.isEmpty) {
      throw StateError('No more fake signals.');
    }
    if (_signals.length == 1) {
      return _signals.first;
    }
    return _signals.removeAt(0);
  }
}

class ThrowingSignalCollector implements DeviceSignalCollector {
  ThrowingSignalCollector(this._error);

  final Object _error;
  int collectCallCount = 0;

  @override
  Future<DeviceSignals> collect() async {
    collectCallCount += 1;
    throw _error;
  }
}

class RecordingConfigProvider implements ConfigProvider {
  RecordingConfigProvider(this._config);

  final TierConfig _config;
  int loadCallCount = 0;

  @override
  Future<TierConfig> load() async {
    loadCallCount += 1;
    return _config;
  }
}

class RecordingTierEngine implements TierEngine {
  RecordingTierEngine({required this.decisionFactory});

  final TierDecision Function({
    required DeviceSignals signals,
    required TierConfig config,
  })
  decisionFactory;
  int evaluateCallCount = 0;

  @override
  TierDecision evaluate({
    required DeviceSignals signals,
    required TierConfig config,
  }) {
    evaluateCallCount += 1;
    return decisionFactory(signals: signals, config: config);
  }
}

class RecordingPolicyResolver implements PolicyResolver {
  RecordingPolicyResolver(this._policy);

  final PerformancePolicy _policy;
  final List<TierLevel> resolveCalls = <TierLevel>[];

  @override
  PerformancePolicy resolve(TierLevel tier) {
    resolveCalls.add(tier);
    return _policy;
  }
}

class RecordingLogger implements PerformanceTierLogger {
  final List<PerformanceTierLogRecord> records = <PerformanceTierLogRecord>[];

  @override
  void log(PerformanceTierLogRecord record) {
    records.add(record);
  }
}

DeviceSignals androidSignals({
  required int ramBytes,
  required int sdkInt,
  required int mediaPerformanceClass,
  bool isLowRamDevice = false,
  String deviceModel = 'Pixel 8 Pro',
  int? thermalStateLevel,
  bool? isLowPowerModeEnabled,
  String? memoryPressureState,
  int? memoryPressureLevel,
  String? frameDropState,
  int? frameDropLevel,
  double? frameDropRate,
  int? frameDroppedCount,
  int? frameSampledCount,
}) {
  return DeviceSignals(
    platform: 'android',
    deviceModel: deviceModel,
    totalRamBytes: ramBytes,
    isLowRamDevice: isLowRamDevice,
    mediaPerformanceClass: mediaPerformanceClass,
    sdkInt: sdkInt,
    thermalStateLevel: thermalStateLevel,
    isLowPowerModeEnabled: isLowPowerModeEnabled,
    memoryPressureState: memoryPressureState,
    memoryPressureLevel: memoryPressureLevel,
    frameDropState: frameDropState,
    frameDropLevel: frameDropLevel,
    frameDropRate: frameDropRate,
    frameDroppedCount: frameDroppedCount,
    frameSampledCount: frameSampledCount,
    collectedAt: DateTime(2026),
  );
}

class SequenceFrameDropSignalSampler implements FrameDropSignalSampler {
  SequenceFrameDropSignalSampler(List<FrameDropSignalSnapshot> snapshots)
    : _snapshots = List<FrameDropSignalSnapshot>.from(snapshots);

  final List<FrameDropSignalSnapshot> _snapshots;
  int startCallCount = 0;
  int stopCallCount = 0;
  int currentSnapshotCallCount = 0;

  @override
  FrameDropSignalSnapshot currentSnapshot() {
    currentSnapshotCallCount += 1;
    if (_snapshots.isEmpty) {
      return const FrameDropSignalSnapshot();
    }
    if (_snapshots.length == 1) {
      return _snapshots.first;
    }
    return _snapshots.removeAt(0);
  }

  @override
  void start() {
    startCallCount += 1;
  }

  @override
  void stop() {
    stopCallCount += 1;
  }
}
