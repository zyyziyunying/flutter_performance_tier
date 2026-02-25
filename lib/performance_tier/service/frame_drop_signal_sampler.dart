import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

abstract interface class FrameDropSignalSampler {
  void start();

  void stop();

  FrameDropSignalSnapshot currentSnapshot();
}

@immutable
class FrameDropSignalSnapshot {
  const FrameDropSignalSnapshot({
    this.state,
    this.level,
    this.dropRate,
    this.sampledFrameCount,
    this.droppedFrameCount,
  });

  final String? state;
  final int? level;
  final double? dropRate;
  final int? sampledFrameCount;
  final int? droppedFrameCount;

  bool get hasSignal {
    return state != null ||
        level != null ||
        dropRate != null ||
        sampledFrameCount != null ||
        droppedFrameCount != null;
  }
}

class DisabledFrameDropSignalSampler implements FrameDropSignalSampler {
  const DisabledFrameDropSignalSampler();

  @override
  FrameDropSignalSnapshot currentSnapshot() {
    return const FrameDropSignalSnapshot();
  }

  @override
  void start() {}

  @override
  void stop() {}
}

class SchedulerFrameDropSignalSampler implements FrameDropSignalSampler {
  SchedulerFrameDropSignalSampler({
    this.sampleWindow = const Duration(seconds: 30),
    this.targetFrameBudget = const Duration(microseconds: 16667),
    this.moderateDropRate = 0.12,
    this.criticalDropRate = 0.25,
    this.moderateDroppedFrameCount = 8,
    this.criticalDroppedFrameCount = 20,
    this.minSampledFrameCount = 60,
    DateTime Function()? now,
  }) : assert(!sampleWindow.isNegative),
       assert(targetFrameBudget > Duration.zero),
       assert(moderateDropRate >= 0 && moderateDropRate <= 1),
       assert(criticalDropRate >= moderateDropRate && criticalDropRate <= 1),
       assert(moderateDroppedFrameCount >= 0),
       assert(criticalDroppedFrameCount >= moderateDroppedFrameCount),
       assert(minSampledFrameCount >= 0),
       _now = now ?? DateTime.now;

  final Duration sampleWindow;
  final Duration targetFrameBudget;
  final double moderateDropRate;
  final double criticalDropRate;
  final int moderateDroppedFrameCount;
  final int criticalDroppedFrameCount;
  final int minSampledFrameCount;
  final DateTime Function() _now;

  final Queue<_FrameSample> _samples = ListQueue<_FrameSample>();
  int _droppedFramesInWindow = 0;
  bool _started = false;

  @override
  void start() {
    if (_started) {
      return;
    }
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void stop() {
    if (!_started) {
      return;
    }
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _started = false;
    _samples.clear();
    _droppedFramesInWindow = 0;
  }

  @override
  FrameDropSignalSnapshot currentSnapshot() {
    final now = _now();
    _trimWindow(now);

    final sampled = _samples.length;
    if (sampled < minSampledFrameCount) {
      return const FrameDropSignalSnapshot();
    }

    final dropped = _droppedFramesInWindow;
    final dropRate = sampled == 0 ? 0.0 : dropped / sampled;
    if (dropRate >= criticalDropRate || dropped >= criticalDroppedFrameCount) {
      return FrameDropSignalSnapshot(
        state: 'critical',
        level: 2,
        dropRate: dropRate,
        sampledFrameCount: sampled,
        droppedFrameCount: dropped,
      );
    }
    if (dropRate >= moderateDropRate || dropped >= moderateDroppedFrameCount) {
      return FrameDropSignalSnapshot(
        state: 'moderate',
        level: 1,
        dropRate: dropRate,
        sampledFrameCount: sampled,
        droppedFrameCount: dropped,
      );
    }
    return FrameDropSignalSnapshot(
      state: 'normal',
      level: 0,
      dropRate: dropRate,
      sampledFrameCount: sampled,
      droppedFrameCount: dropped,
    );
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_started || timings.isEmpty) {
      return;
    }
    final now = _now();
    for (final timing in timings) {
      final dropped = timing.totalSpan > targetFrameBudget;
      _samples.add(_FrameSample(timestamp: now, dropped: dropped));
      if (dropped) {
        _droppedFramesInWindow += 1;
      }
    }
    _trimWindow(now);
  }

  void _trimWindow(DateTime now) {
    if (sampleWindow <= Duration.zero) {
      _samples.clear();
      _droppedFramesInWindow = 0;
      return;
    }

    while (_samples.isNotEmpty &&
        now.difference(_samples.first.timestamp) > sampleWindow) {
      final removed = _samples.removeFirst();
      if (removed.dropped) {
        _droppedFramesInWindow -= 1;
      }
    }
    if (_droppedFramesInWindow < 0) {
      _droppedFramesInWindow = 0;
    }
  }
}

class _FrameSample {
  const _FrameSample({required this.timestamp, required this.dropped});

  final DateTime timestamp;
  final bool dropped;
}
