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
    setupBackgroundDownloads()
    return launched
  }

  private var downloadBackgroundTask: UIBackgroundTaskIdentifier = .invalid

  private func setupBackgroundDownloads() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "karam/background_download",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      if call.method == "begin" {
        self.beginDownloadBackgroundTask()
        result(nil)
      } else if call.method == "end" {
        self.endDownloadBackgroundTask()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func beginDownloadBackgroundTask() {
    if downloadBackgroundTask != .invalid { return }
    downloadBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "video-download") { [weak self] in
      self?.endDownloadBackgroundTask()
    }
  }

  private func endDownloadBackgroundTask() {
    if downloadBackgroundTask == .invalid { return }
    UIApplication.shared.endBackgroundTask(downloadBackgroundTask)
    downloadBackgroundTask = .invalid
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

