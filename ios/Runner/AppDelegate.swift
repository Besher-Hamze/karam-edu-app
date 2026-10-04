import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private var screenGuardChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    setupScreenGuard()
    return launched
  }

  private func setupScreenGuard() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "karam/screen_guard",
      binaryMessenger: controller.binaryMessenger
    )
    screenGuardChannel = channel

    channel.setMethodCallHandler { call, result in
      if call.method == "isCaptured" {
        result(UIScreen.main.isCaptured)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.screenGuardChannel?.invokeMethod("onCaptureChanged", arguments: UIScreen.main.isCaptured)
    }

    NotificationCenter.default.addObserver(
      forName: UIApplication.userDidTakeScreenshotNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.screenGuardChannel?.invokeMethod("onScreenshot", arguments: nil)
    }
  }
}

