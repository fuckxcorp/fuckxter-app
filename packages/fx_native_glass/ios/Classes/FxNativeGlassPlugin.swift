import Flutter
import SwiftUI
import UIKit

public class FxNativeGlassPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "site.fuckxter/native_glass", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(FxNativeGlassPlugin(), channel: channel)
    registrar.register(GlassFactory(), withId: "site.fuckxter/glass")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "available" else { result(FlutterMethodNotImplemented); return }
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) { result(true); return }
    #endif
    result(false)
  }
}

private class GlassFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    GlassView(frame: frame, params: args as? [String: Any] ?? [:])
  }
}

private class GlassView: NSObject, FlutterPlatformView {
  private var host: UIViewController?
  private let surface: UIView

  init(frame: CGRect, params: [String: Any]) {
    #if compiler(>=6.2)
    if #available(iOS 26.0, *) {
      let dark = params["dark"] as? Bool ?? false
      let radius = params["radius"] as? Double ?? 20
      let controller = UIHostingController(rootView:
        Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
          .glassEffect(.regular, in: .rect(cornerRadius: radius))
          .environment(\.colorScheme, dark ? .dark : .light))
      controller.view.backgroundColor = .clear
      controller.view.isUserInteractionEnabled = false
      controller.view.frame = frame
      host = controller
      surface = controller.view
      super.init()
      return
    }
    #endif
    surface = UIView(frame: frame)
    super.init()
  }

  func view() -> UIView { surface }
}
