import Cocoa
import FlutterMacOS

/// CI / SDK bez funkčního Swift modulu HomeKit — kanál odpovídá „nepodporováno“.
#if AMBILIGHT_CI_NO_HOMEKIT || !canImport(HomeKit)

final class HomeKitChannel: NSObject {
    static func register(binaryMessenger: FlutterBinaryMessenger) {
        let ch = FlutterMethodChannel(name: "ambilight/homekit", binaryMessenger: binaryMessenger)
        ch.setMethodCallHandler { call, result in
            switch call.method {
            case "isSupported":
                result(false)
            case "listLights":
                result([])
            case "setLightColor":
                result(
                    FlutterError(
                        code: "unsupported",
                        message: "HomeKit not available in this build",
                        details: nil
                    ))
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}

#endif
