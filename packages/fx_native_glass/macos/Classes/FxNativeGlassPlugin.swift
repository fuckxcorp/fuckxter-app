import Cocoa
import FlutterMacOS
import SwiftUI

public class FxNativeGlassPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "site.fuckxter/native_glass", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(FxNativeGlassPlugin(), channel: channel)
    registrar.register(GlassFactory(), withId: "site.fuckxter/glass")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "available" else { result(FlutterMethodNotImplemented); return }
    #if compiler(>=6.2)
    if #available(macOS 26.0, *) { result(true); return }
    #endif
    result(false)
  }
}

private class GlassFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
    let params = args as? [String: Any] ?? [:]
    #if compiler(>=6.2)
    if #available(macOS 26.0, *) {
      let dark = params["dark"] as? Bool ?? false
      let radius = params["radius"] as? Double ?? 20
      return PassthroughHost(rootView:
        Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
          .glassEffect(.regular, in: .rect(cornerRadius: radius))
          .environment(\.colorScheme, dark ? .dark : .light))
    }
    #endif
    return NSView()
  }
}

private class PassthroughHost<Content: View>: NSHostingView<Content> {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
