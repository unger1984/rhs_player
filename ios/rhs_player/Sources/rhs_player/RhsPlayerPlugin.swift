import Flutter
import MediaPlayer
import UIKit

public final class RhsPlayerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = RhsPlayerPlugin()
    let platformChannel = FlutterMethodChannel(
      name: "rhs_player",
      binaryMessenger: registrar.messenger()
    )
    let utilityChannel = FlutterMethodChannel(
      name: "rhsplayer/channel",
      binaryMessenger: registrar.messenger()
    )

    registrar.addMethodCallDelegate(instance, channel: platformChannel)
    registrar.addMethodCallDelegate(instance, channel: utilityChannel)
    registrar.register(
      RhsPlayerViewFactory(messenger: registrar.messenger()),
      withId: "rhsplayer/native_view"
    )
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "setBrightness":
      setBrightness(call.arguments, result: result)
    case "setVolume":
      setVolume(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setBrightness(_ arguments: Any?, result: FlutterResult) {
    guard let args = arguments as? [String: Any],
      let delta = args["value"] as? Double
    else {
      result(FlutterError(code: "ARG_ERROR", message: "Не задано изменение яркости", details: nil))
      return
    }

    let brightness = min(max(UIScreen.main.brightness + CGFloat(delta), 0.01), 1.0)
    UIScreen.main.brightness = brightness
    result(Double(brightness))
  }

  private func setVolume(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any],
      let delta = args["value"] as? Double
    else {
      result(
        FlutterError(code: "ARG_ERROR", message: "Не задано изменение громкости", details: nil))
      return
    }

    let volumeView = MPVolumeView(frame: .zero)
    guard let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first else {
      result(
        FlutterError(
          code: "NO_VOLUME_SLIDER", message: "Системная громкость недоступна", details: nil))
      return
    }

    let volume = min(max(slider.value + Float(delta), 0), 1)
    DispatchQueue.main.async {
      slider.value = volume
      result(Double(volume))
    }
  }
}
