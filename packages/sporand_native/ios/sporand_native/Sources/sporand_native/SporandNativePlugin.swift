import Flutter
import UIKit

/// Registers the Pigeon host APIs of this package (auto-registered through
/// GeneratedPluginRegistrant; no Runner project changes are needed).
public class SporandNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    InputClockApiSetup.setUp(binaryMessenger: messenger, api: InputClockHost())
    ClipPlayerApiSetup.setUp(binaryMessenger: messenger, api: ClipPlayerHost())
  }
}
