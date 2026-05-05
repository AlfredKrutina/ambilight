import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

/// Import JSON zálohy: aktivace app + NSOpenPanel (spolehlivější než čistý file_picker při tray / sandbox).
enum ConfigBackupChannel {
  static func register(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "ambilight/config_backup",
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "pickImportJsonPath":
        DispatchQueue.main.async {
          Self.pickImportJson(result: result)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func pickImportJson(result: @escaping FlutterResult) {
    NSApp.activate(ignoringOtherApps: true)
    if let w = NSApp.mainWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
      w.makeKeyAndOrderFront(nil)
    }

    let dialog = NSOpenPanel()
    dialog.title = "Choose JSON backup"
    dialog.prompt = "Open"
    dialog.canChooseFiles = true
    dialog.canChooseDirectories = false
    dialog.allowsMultipleSelection = false
    dialog.showsHiddenFiles = false

    if let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
      dialog.directoryURL = downloads
    } else {
      dialog.directoryURL = FileManager.default.homeDirectoryForCurrentUser
    }

    if #available(macOS 11.0, *) {
      dialog.allowedContentTypes = [.json]
    } else {
      dialog.allowedFileTypes = ["json"]
    }

    let response = dialog.runModal()
    if response == .OK, let url = dialog.url {
      result(url.path)
    } else {
      result(nil)
    }
  }
}
