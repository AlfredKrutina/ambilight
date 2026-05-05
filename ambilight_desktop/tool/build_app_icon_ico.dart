// Zpětná kompatibilita: dříve jen ICO; macOS + Windows teď jednotně ve `sync_desktop_app_icons.dart`.
// Spuštění z kořene projektu: `dart run tool/build_app_icon_ico.dart` (deleguje na sync).
import 'sync_desktop_app_icons.dart' as sync;

Future<void> main(List<String> args) async {
  await sync.main(args);
}
