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

    if (!Platform.isAndroid && !Platform.isIOS) {
      return DeviceSignals(
        platform: Platform.operatingSystem,
        collectedAt: now,
      );
    }

    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      _collectMethod,
    );
    final normalized = <String, dynamic>{
      'platform': Platform.operatingSystem,
      ...?result,
    };

    return DeviceSignals.fromMap(normalized, collectedAt: now);
  }
}
