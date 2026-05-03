import CoreGraphics
import FlutterMacOS

/// Method channel `ambilight/screen_capture` — stejný kontrakt jako Windows/Linux (viz `context/SCREEN_CAPTURE_CHANNEL.md`).
enum ScreenCaptureChannel {
  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "ambilight/screen_capture",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "listMonitors":
        result(Self.buildMonitorList())
      case "sessionInfo":
        result([
          "os": "macos",
          "sessionType": "quartz",
          "captureBackend": "cgdisplay_cgwindowlist",
          "note":
            "left/top jsou v souřadnicích s osou Y dolů (stejná konvence jako Win virtual screen). "
            + "Od macOS 10.15 může být potřeba Screen Recording v Soukromí a zabezpečení.",
        ])
      case "requestPermission":
        if #available(macOS 10.15, *) {
          result(CGRequestScreenCaptureAccess())
        } else {
          result(true)
        }
      case "capture":
        let args = call.arguments as? [String: Any]
        let monitorIndex = (args?["monitorIndex"] as? NSNumber)?.intValue ?? 1
        DispatchQueue.global(qos: .userInitiated).async {
          let payload = Self.capturePayload(monitorIndex: monitorIndex)
          DispatchQueue.main.async {
            if let payload = payload {
              result(payload)
            } else {
              result(
                FlutterError(
                  code: "capture_failed",
                  message: "Screen capture failed or permission denied",
                  details: nil
                ))
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Monitors

  private static func sortedActiveDisplays() -> [(CGDirectDisplayID, CGRect)] {
    let maxCount = 32
    var ids = [CGDirectDisplayID](repeating: 0, count: maxCount)
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(UInt32(maxCount), &ids, &count) == .success, count > 0 else {
      return []
    }
    let active = (0..<Int(count)).map { ids[$0] }
    let pairs = active.map { id -> (CGDirectDisplayID, CGRect) in (id, CGDisplayBounds(id)) }
    return pairs.sorted { a, b in
      if a.1.origin.x != b.1.origin.x { return a.1.origin.x < b.1.origin.x }
      return a.1.origin.y < b.1.origin.y
    }
  }

  /// Převod z Quartz (Y nahoru) na virtuální souřadnice s Y dolů (jako Windows `SM_*VIRTUALSCREEN`).
  private static func mapRectToEntry(bounds: CGRect, mssStyleIndex: Int, isPrimary: Bool, maxYQuartz: CGFloat)
    -> [String: Any]
  {
    let left = bounds.origin.x
    let top = maxYQuartz - bounds.maxY
    return [
      "mssStyleIndex": mssStyleIndex,
      "left": Int(left.rounded()),
      "top": Int(top.rounded()),
      "width": Int(bounds.width.rounded()),
      "height": Int(bounds.height.rounded()),
      "isPrimary": isPrimary,
    ]
  }

  private static func buildMonitorList() -> [[String: Any]] {
    let sorted = sortedActiveDisplays()
    guard !sorted.isEmpty else { return [] }
    let maxY = sorted.map { $0.1.maxY }.max() ?? 0
    var union = sorted[0].1
    for p in sorted.dropFirst() {
      union = union.union(p.1)
    }
    var list: [[String: Any]] = []
    list.append(mapRectToEntry(bounds: union, mssStyleIndex: 0, isPrimary: false, maxYQuartz: maxY))
    var idx = 1
    for (id, rect) in sorted {
      let primary = id == CGMainDisplayID()
      list.append(mapRectToEntry(bounds: rect, mssStyleIndex: idx, isPrimary: primary, maxYQuartz: maxY))
      idx += 1
    }
    return list
  }

  // MARK: - Capture

  private static func capturePayload(monitorIndex: Int) -> [String: Any]? {
    let sorted = sortedActiveDisplays()
    guard !sorted.isEmpty else { return nil }
    if monitorIndex <= 0 {
      var union = sorted[0].1
      for p in sorted.dropFirst() {
        union = union.union(p.1)
      }
      let img =
        CGWindowListCreateImage(
          union,
          .optionOnScreenOnly,
          kCGNullWindowID,
          [.bestResolution]
        )
        ?? CGDisplayCreateImage(CGMainDisplayID())
      guard let imgUnwrapped = img else { return nil }
      return encode(image: imgUnwrapped, resolvedMonitorIndex: 0)
    }
    let di = monitorIndex - 1
    let target: CGDirectDisplayID
    let resolvedIndex: Int
    if di < 0 || di >= sorted.count {
      target = sorted[0].0
      resolvedIndex = 1
    } else {
      target = sorted[di].0
      resolvedIndex = monitorIndex
    }
    guard let img = CGDisplayCreateImage(target) else { return nil }
    return encode(image: img, resolvedMonitorIndex: resolvedIndex)
  }

  private static func encode(image: CGImage, resolvedMonitorIndex: Int) -> [String: Any]? {
    let w = image.width
    let h = image.height
    guard w > 0, h > 0 else { return nil }
    guard let rgba = rgbaData(from: image) else { return nil }
    return [
      "width": w,
      "height": h,
      "monitorIndex": resolvedMonitorIndex,
      "rgba": FlutterStandardTypedData(bytes: rgba),
    ]
  }

  private static func rgbaData(from image: CGImage) -> Data? {
    let w = image.width
    let h = image.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * w
    var data = Data(count: w * h * bytesPerPixel)
    let ok = data.withUnsafeMutableBytes { raw -> Bool in
      guard let base = raw.baseAddress else { return false }
      guard let ctx = CGContext(
        data: base,
        width: w,
        height: h,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
        return false
      }
      ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
      return true
    }
    return ok ? data : nil
  }
}
