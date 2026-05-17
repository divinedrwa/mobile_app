import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Expose the device's true hardware resolution so Flutter can detect
    // and counteract iOS Display Zoom.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DisplayInfoPlugin") {
      let channel = FlutterMethodChannel(
        name: "com.app.gatepass/display",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { (call, result) in
        if call.method == "getNativeScreenInfo" {
          let screen = UIScreen.main
          result([
            "nativeWidth": screen.nativeBounds.width,
            "nativeHeight": screen.nativeBounds.height,
            "nativeScale": screen.nativeScale,
          ])
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
