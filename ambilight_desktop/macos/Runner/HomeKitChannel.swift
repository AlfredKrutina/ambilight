import Cocoa
import FlutterMacOS
import HomeKit

/// MethodChannel `ambilight/homekit` — výpis světel a zápis barvy (macOS + HomeKit entitlement).
final class HomeKitChannel: NSObject, HMHomeManagerDelegate {
    private static var retained: HomeKitChannel?
    private var homeManager: HMHomeManager?

    static func register(binaryMessenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(name: "ambilight/homekit", binaryMessenger: binaryMessenger)
        let inst = HomeKitChannel()
        retained = inst
        inst.homeManager = HMHomeManager()
        inst.homeManager?.delegate = inst
        ch.setMethodCallHandler { call, result in
            inst.handle(call: call, result: result)
        }
        _ = inst.homeManager?.homes
    }

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {}

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            result(true)
        case "listLights":
            result(exportLights())
        case "setLightColor":
            guard let args = call.arguments as? [String: Any],
                  let uuidStr = args["uuid"] as? String,
                  let r = args["r"] as? Int,
                  let g = args["g"] as? Int,
                  let b = args["b"] as? Int,
                  let bp = args["brightnessPct"] as? Int
            else {
                result(FlutterError(code: "args", message: "Invalid arguments", details: nil))
                return
            }
            setColor(uuidString: uuidStr, r: r, g: g, b: b, brightnessPct: bp, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func exportLights() -> [[String: String]] {
        var out: [[String: String]] = []
        guard let homes = homeManager?.homes else { return out }
        for home in homes {
            for acc in home.accessories {
                let hasBulb = acc.services.contains { $0.serviceType == HMServiceTypeLightbulb }
                guard hasBulb else { continue }
                let sid = acc.uniqueIdentifier.uuidString
                out.append(["uuid": sid, "name": acc.name])
            }
        }
        return out
    }

    private func setColor(
        uuidString: String,
        r: Int,
        g: Int,
        b: Int,
        brightnessPct: Int,
        result: @escaping FlutterResult
    ) {
        guard let uid = UUID(uuidString: uuidString) else {
            result(FlutterError(code: "uuid", message: "Bad UUID", details: nil))
            return
        }
        guard let homes = homeManager?.homes else {
            result(false)
            return
        }
        var targetAcc: HMAccessory?
        outer: for home in homes {
            for acc in home.accessories where acc.uniqueIdentifier == uid {
                targetAcc = acc
                break outer
            }
        }
        guard let acc = targetAcc,
              let svc = acc.services.first(where: { $0.serviceType == HMServiceTypeLightbulb })
        else {
            result(FlutterError(code: "missing", message: "Accessory or light service not found", details: nil))
            return
        }

        let color = NSColor(
            calibratedRed: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: 1.0
        )
        var hue: CGFloat = 0
        var sat: CGFloat = 0
        var bri: CGFloat = 0
        color.getHue(&hue, saturation: &sat, brightness: &bri, alpha: nil)

        let chars = svc.characteristics
        guard let onChar = chars.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) else {
            result(FlutterError(code: "chars", message: "No power characteristic", details: nil))
            return
        }

        func writeChar(_ char: HMCharacteristic?, value: Any, done: @escaping (Error?) -> Void) {
            guard let char = char else {
                done(nil)
                return
            }
            if !char.properties.contains(HMCharacteristicPropertyWritable) {
                done(nil)
                return
            }
            char.writeValue(value) { err in
                done(err)
            }
        }

        let hueDeg = NSNumber(value: Double(hue * 360.0))
        let satPct = NSNumber(value: Double(sat * 100.0))
        let bp = min(100, max(0, brightnessPct))
        let briUser = CGFloat(bp) / 100.0
        let briEffective = max(0.01, bri * briUser)
        let briNum = NSNumber(value: Double(briEffective * 100.0))

        writeChar(onChar, value: true) { err1 in
            if err1 != nil {
                result(false)
                return
            }
            let briChar = chars.first { $0.characteristicType == HMCharacteristicTypeBrightness }
            writeChar(briChar, value: briNum) { err2 in
                if err2 != nil {
                    result(false)
                    return
                }
                let hueChar = chars.first { $0.characteristicType == HMCharacteristicTypeHue }
                let satChar = chars.first { $0.characteristicType == HMCharacteristicTypeSaturation }
                writeChar(hueChar, value: hueDeg) { err3 in
                    if err3 != nil {
                        result(true)
                        return
                    }
                    writeChar(satChar, value: satPct) { err4 in
                        if err4 != nil {
                            result(true)
                        } else {
                            result(true)
                        }
                    }
                }
            }
        }
    }
}
