import Flutter
import UIKit
import Darwin

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let deviceSignalsChannelName = "performance_tier/device_signals"
  private static let collectDeviceSignalsMethod = "collectDeviceSignals"
  private static let lowRamThresholdBytes = Int64(3 * 1024 * 1024 * 1024)

  private var deviceSignalsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: Self.deviceSignalsChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == Self.collectDeviceSignalsMethod else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(self?.collectDeviceSignals())
    }
    deviceSignalsChannel = channel
  }

  private func collectDeviceSignals() -> [String: Any] {
    let processInfo = ProcessInfo.processInfo
    let totalRamBytes = Int64(min(processInfo.physicalMemory, UInt64(Int64.max)))
    let isLowRamDevice = totalRamBytes <= Self.lowRamThresholdBytes
    let majorVersion = processInfo.operatingSystemVersion.majorVersion

    return [
      "platform": "ios",
      "deviceModel": deviceModelIdentifier(),
      "totalRamBytes": totalRamBytes,
      "isLowRamDevice": isLowRamDevice,
      "sdkInt": majorVersion,
    ]
  }

  private func deviceModelIdentifier() -> String? {
    var systemInfo = utsname()
    uname(&systemInfo)

    let identifier = withUnsafePointer(to: &systemInfo.machine) { pointer in
      pointer.withMemoryRebound(to: CChar.self, capacity: Int(_SYS_NAMELEN)) {
        String(cString: $0)
      }
    }
    return identifier.isEmpty ? nil : identifier
  }
}
