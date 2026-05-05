// Reference implementace pro macOS Runner (po `flutter create --platforms=macos`).
// 1) Přidej tento soubor do Xcode targetu Runner.
// 2) V MainFlutterWindow.awakeFromNib() po RegisterGeneratedPlugins zavolej:
//    ScreenCaptureChannel.register(binaryMessenger: flutterViewController.engine.binaryMessenger)

import Cocoa
import CoreGraphics
import FlutterMacOS

enum ScreenCaptureChannel {
  private static let name = "ambilight/screen_capture"

  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: name, binaryMessenger: binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "sessionInfo":
        let m: [String: Any] = [
          "os": "macos",
          "sessionType": "macos",
          "captureBackend": "cgdisplay_create_image",
          "note":
            "Uses CGDisplayCreateImage (deprecated on newer macOS; replace with ScreenCaptureKit when raising deployment target). Grant Screen Recording in System Settings → Privacy & Security.",
        ]
        result(m)
      case "requestPermission":
        if #available(macOS 10.15, *) {
          let _ = CGRequestScreenCaptureAccess()
        }
        result(true)
      case "listMonitors":
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        guard CGGetActiveDisplayList(32, &ids, &count) == .success, count > 0 else {
          result([])
          return
        }
        var list: [[String: Any]] = []
        var union = CGRect.null
        for i in 0..<Int(count) {
          let id = ids[i]
          union = union.union(CGDisplayBounds(id))
        }
        list.append([
          "mssStyleIndex": 0,
          "left": Int(floor(union.origin.x)),
          "top": Int(floor(union.origin.y)),
          "width": Int(union.size.width),
          "height": Int(union.size.height),
          "isPrimary": false,
        ])
        var idx = 1
        for i in 0..<Int(count) {
          let id = ids[i]
          let b = CGDisplayBounds(id)
          let primary = CGDisplayIsMain(id) != 0
          list.append([
            "mssStyleIndex": idx,
            "left": Int(floor(b.origin.x)),
            "top": Int(floor(b.origin.y)),
            "width": Int(b.size.width),
            "height": Int(b.size.height),
            "isPrimary": primary,
          ])
          idx += 1
        }
        result(list)
      case "capture":
        let args = call.arguments as? [String: Any]
        let monitorIndex = (args?["monitorIndex"] as? NSNumber)?.intValue ?? 1
        if #available(macOS 10.15, *) {
          _ = CGRequestScreenCaptureAccess()
        }
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        guard CGGetActiveDisplayList(32, &ids, &count) == .success, count > 0 else {
          result(FlutterError(code: "capture_failed", message: "No displays", details: nil))
          return
        }
        let targetId: CGDirectDisplayID
        if monitorIndex <= 0 {
          targetId = CGMainDisplayID()
        } else {
          let ix = min(max(1, monitorIndex), Int(count)) - 1
          targetId = ids[ix]
        }
        guard let image = CGDisplayCreateImage(targetId) else {
          result(FlutterError(code: "capture_failed", message: "CGDisplayCreateImage failed", details: nil))
          return
        }
        let w = image.width
        let h = image.height
        let rowBytes = w * 4
        var rgba = [UInt8](repeating: 0, count: rowBytes * h)
        rgba.withUnsafeMutableBytes { raw in
          guard let ctx = CGContext(
            data: raw.baseAddress,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: rowBytes,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else { return }
          ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        result([
          "width": w,
          "height": h,
          "monitorIndex": monitorIndex <= 0 ? 0 : monitorIndex,
          "rgba": FlutterStandardTypedData(bytes: Data(rgba)),
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
