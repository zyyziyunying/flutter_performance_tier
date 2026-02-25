import 'package:flutter/foundation.dart';

@immutable
class DeviceSignals {
  const DeviceSignals({
    required this.platform,
    required this.collectedAt,
    this.deviceModel,
    this.totalRamBytes,
    this.isLowRamDevice,
    this.mediaPerformanceClass,
    this.sdkInt,
    this.thermalState,
    this.thermalStateLevel,
    this.isLowPowerModeEnabled,
    this.memoryPressureState,
    this.memoryPressureLevel,
    this.frameDropState,
    this.frameDropLevel,
    this.frameDropRate,
    this.frameDroppedCount,
    this.frameSampledCount,
  });

  final String platform;
  final String? deviceModel;
  final int? totalRamBytes;
  final bool? isLowRamDevice;
  final int? mediaPerformanceClass;
  final int? sdkInt;
  final String? thermalState;
  final int? thermalStateLevel;
  final bool? isLowPowerModeEnabled;
  final String? memoryPressureState;
  final int? memoryPressureLevel;
  final String? frameDropState;
  final int? frameDropLevel;
  final double? frameDropRate;
  final int? frameDroppedCount;
  final int? frameSampledCount;
  final DateTime collectedAt;

  int? get totalRamMb => totalRamBytes == null ? null : totalRamBytes! ~/ _mb;

  DeviceSignals copyWith({
    String? platform,
    String? deviceModel,
    int? totalRamBytes,
    bool? isLowRamDevice,
    int? mediaPerformanceClass,
    int? sdkInt,
    String? thermalState,
    int? thermalStateLevel,
    bool? isLowPowerModeEnabled,
    String? memoryPressureState,
    int? memoryPressureLevel,
    String? frameDropState,
    int? frameDropLevel,
    double? frameDropRate,
    int? frameDroppedCount,
    int? frameSampledCount,
    DateTime? collectedAt,
  }) {
    return DeviceSignals(
      platform: platform ?? this.platform,
      deviceModel: deviceModel ?? this.deviceModel,
      totalRamBytes: totalRamBytes ?? this.totalRamBytes,
      isLowRamDevice: isLowRamDevice ?? this.isLowRamDevice,
      mediaPerformanceClass:
          mediaPerformanceClass ?? this.mediaPerformanceClass,
      sdkInt: sdkInt ?? this.sdkInt,
      thermalState: thermalState ?? this.thermalState,
      thermalStateLevel: thermalStateLevel ?? this.thermalStateLevel,
      isLowPowerModeEnabled:
          isLowPowerModeEnabled ?? this.isLowPowerModeEnabled,
      memoryPressureState: memoryPressureState ?? this.memoryPressureState,
      memoryPressureLevel: memoryPressureLevel ?? this.memoryPressureLevel,
      frameDropState: frameDropState ?? this.frameDropState,
      frameDropLevel: frameDropLevel ?? this.frameDropLevel,
      frameDropRate: frameDropRate ?? this.frameDropRate,
      frameDroppedCount: frameDroppedCount ?? this.frameDroppedCount,
      frameSampledCount: frameSampledCount ?? this.frameSampledCount,
      collectedAt: collectedAt ?? this.collectedAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'platform': platform,
      'deviceModel': deviceModel,
      'totalRamBytes': totalRamBytes,
      'isLowRamDevice': isLowRamDevice,
      'mediaPerformanceClass': mediaPerformanceClass,
      'sdkInt': sdkInt,
      'thermalState': thermalState,
      'thermalStateLevel': thermalStateLevel,
      'isLowPowerModeEnabled': isLowPowerModeEnabled,
      'memoryPressureState': memoryPressureState,
      'memoryPressureLevel': memoryPressureLevel,
      'frameDropState': frameDropState,
      'frameDropLevel': frameDropLevel,
      'frameDropRate': frameDropRate,
      'frameDroppedCount': frameDroppedCount,
      'frameSampledCount': frameSampledCount,
      'collectedAt': collectedAt.toIso8601String(),
    };
  }

  factory DeviceSignals.fromMap(
    Map<String, dynamic> map, {
    required DateTime collectedAt,
  }) {
    return DeviceSignals(
      platform: _asString(map['platform']) ?? 'unknown',
      deviceModel: _asString(map['deviceModel']),
      totalRamBytes: _asInt(map['totalRamBytes']),
      isLowRamDevice: _asBool(map['isLowRamDevice']),
      mediaPerformanceClass: _asInt(map['mediaPerformanceClass']),
      sdkInt: _asInt(map['sdkInt']),
      thermalState: _asString(map['thermalState']),
      thermalStateLevel: _asInt(map['thermalStateLevel']),
      isLowPowerModeEnabled: _asBool(map['isLowPowerModeEnabled']),
      memoryPressureState: _asString(map['memoryPressureState']),
      memoryPressureLevel: _asInt(map['memoryPressureLevel']),
      frameDropState: _asString(map['frameDropState']),
      frameDropLevel: _asInt(map['frameDropLevel']),
      frameDropRate: _asDouble(map['frameDropRate']),
      frameDroppedCount: _asInt(map['frameDroppedCount']),
      frameSampledCount: _asInt(map['frameSampledCount']),
      collectedAt: collectedAt,
    );
  }

  static const int _mb = 1024 * 1024;

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      if (value.toLowerCase() == 'true') {
        return true;
      }
      if (value.toLowerCase() == 'false') {
        return false;
      }
    }
    return null;
  }

  static String? _asString(Object? value) {
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }
}
