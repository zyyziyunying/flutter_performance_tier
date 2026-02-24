import 'package:flutter/foundation.dart';

@immutable
class PerformancePolicy {
  const PerformancePolicy({
    required this.animationLevel,
    required this.mediaPreloadCount,
    required this.decodeConcurrency,
    required this.imageMaxSidePx,
  });

  final int animationLevel;
  final int mediaPreloadCount;
  final int decodeConcurrency;
  final int imageMaxSidePx;

  Map<String, Object> toMap() {
    return <String, Object>{
      'animationLevel': animationLevel,
      'mediaPreloadCount': mediaPreloadCount,
      'decodeConcurrency': decodeConcurrency,
      'imageMaxSidePx': imageMaxSidePx,
    };
  }
}
