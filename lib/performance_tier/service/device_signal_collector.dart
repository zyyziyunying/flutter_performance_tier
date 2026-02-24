import '../model/device_signals.dart';

abstract interface class DeviceSignalCollector {
  Future<DeviceSignals> collect();
}
