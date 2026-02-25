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
  final DateTime collectedAt;

  int? get totalRamMb => totalRamBytes == null ? null : totalRamBytes! ~/ _mb;

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
