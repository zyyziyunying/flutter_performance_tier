import 'dart:io';

import 'package:flutter/services.dart';

import '../model/device_signals.dart';
import 'device_signal_collector.dart';

class MethodChannelDeviceSignalCollector implements DeviceSignalCollector {
  MethodChannelDeviceSignalCollector({
    MethodChannel methodChannel = const MethodChannel(_channelName),
  }) : _methodChannel = methodChannel;

  static const String _channelName = 'performance_tier/device_signals';
  static const String _collectMethod = 'collectDeviceSignals';

  final MethodChannel _methodChannel;

  @override
  Future<DeviceSignals> collect() async {
    final now = DateTime.now();

    if (!Platform.isAndroid) {
      return DeviceSignals(
        platform: Platform.operatingSystem,
        collectedAt: now,
      );
    }

    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      _collectMethod,
    );

    return DeviceSignals.fromMap(
      result ?? const <String, dynamic>{},
      collectedAt: now,
    );
  }
}
