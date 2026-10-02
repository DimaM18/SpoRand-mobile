import Flutter
import UIKit

/// Registers the Pigeon host APIs of this package (auto-registered through
/// GeneratedPluginRegistrant; no Runner project changes are needed). The
/// input clock lives in the mobile_kit_clock plugin.
public class SporandNativePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    ClipPlayerApiSetup.setUp(binaryMessenger: messenger, api: ClipPlayerHost())
    MusicAppApiSetup.setUp(binaryMessenger: messenger, api: MusicAppHost())
  }
}
