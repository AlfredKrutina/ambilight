// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'AmbiLight';

  @override
  String get languageLabel => 'Jazyk';

  @override
  String get languageSystem => 'Podle systému';

  @override
  String get languageEnglish => 'Angličtina';

  @override
  String get languageCzech => 'Čeština';

  @override
  String get cancel => 'Zrušit';

  @override
  String get save => 'Uložit';

  @override
  String get close => 'Zavřít';

  @override
  String get done => 'Hotovo';

  @override
  String get next => 'Další';

  @override
  String get back => 'Zpět';

  @override
  String get skip => 'Přeskočit';

  @override
  String get settings => 'Nastavení';

  @override
  String get help => 'Nápověda';

  @override
  String get add => 'Přidat';

  @override
  String get delete => 'Smazat';

  @override
  String get edit => 'Upravit';

  @override
  String get verify => 'Ověřit';

  @override
  String get refresh => 'Obnovit';

  @override
  String get send => 'Odeslat';

  @override
  String get remove => 'Odebrat';

  @override
  String get scanning => 'Skenuji…';

  @override
  String get measuring => 'Měřím…';

  @override
  String get findingCom => 'Hledám COM…';

  @override
  String get navOverview => 'Přehled';

  @override
  String get navDevices => 'Zařízení';

  @override
  String get navSettings => 'Nastavení';

  @override
  String get navAbout => 'O aplikaci';

  @override
  String get navOverviewTooltip => 'Domů — režimy a náhled zařízení';

  @override
  String get navDevicesTooltip => 'Discovery, pásky a kalibrace';

  @override
  String get navSettingsTooltip => 'Režimy, integrace a záloha konfigurace';

  @override
  String get navAboutTooltip => 'Verze a základní informace';

  @override
  String get navigationSection => 'Navigace';

  @override
  String get outputOn => 'Výstup zapnutý';

  @override
  String get outputOff => 'Výstup vypnutý';

  @override
  String get tooltipColorsOn => 'Vypnout posílání barev na pásky';

  @override
  String get tooltipColorsOff => 'Zapnout posílání barev na pásky';

  @override
  String allOutputsOnline(Object online, Object total) {
    return 'Všechna výstupní zařízení připojená ($online/$total).';
  }

  @override
  String someOutputsOffline(Object online, Object total) {
    return 'Část výstupů offline ($online/$total) — zkontroluj USB nebo Wi‑Fi.';
  }

  @override
  String get footerNoOutputs => 'Žádné výstupní zařízení (volitelné)';

  @override
  String get footerUsbOne => 'USB';

  @override
  String footerUsbMany(Object count) {
    return '$count× USB';
  }

  @override
  String get footerWifiOne => 'Wi‑Fi';

  @override
  String footerWifiMany(Object count) {
    return '$count× Wi‑Fi';
  }

  @override
  String get pathCopiedSnackbar => 'Cesta zkopírována do schránky';

  @override
  String get aboutTitle => 'O aplikaci';

  @override
  String get aboutSubtitle =>
      'AmbiLight Desktop — ovládání LED pásků z Windows (USB i Wi‑Fi).';

  @override
  String get aboutBody =>
      'Desktopový klient ve Flutteru, sladěný s firmware pro ESP32. Průvodce v aplikaci tě provedou páskem, segmenty obrazovky a kalibrací.';

  @override
  String get aboutAppName => 'AmbiLight Desktop';

  @override
  String get showOnboardingAgain => 'Znovu zobrazit úvodní průvodce';

  @override
  String get crashLogFileLabel => 'Soubor crash / diagnostického logu:';

  @override
  String get copyLogPath => 'Zkopírovat cestu k logu';

  @override
  String get debugSection => 'Ladění';

  @override
  String engineTickDebug(Object tick) {
    return 'Čítač snímků engine: $tick\n(Obnovuje se při změně připojení zařízení, novém snímku obrazovky nebo v intervalu ~4 s.)';
  }

  @override
  String versionLoadError(Object error) {
    return 'Verzi nelze načíst: $error';
  }

  @override
  String versionLine(Object version, Object build) {
    return 'Verze: $version ($build)';
  }

  @override
  String buildLine(Object mode, Object channel) {
    return 'Build: $mode · kanál: $channel';
  }

  @override
  String gitLine(Object sha) {
    return 'Git: $sha';
  }

  @override
  String get semanticsCloseScanOverlay => 'Zavřít náhled oblasti snímání';

  @override
  String get scanZonesChip => 'Náhled zón';

  @override
  String bootstrapFailed(Object detail) {
    return 'Aplikace se nespustila: $detail';
  }

  @override
  String configLoadFailed(Object detail) {
    return 'Načtení konfigurace selhalo, používám výchozí: $detail';
  }

  @override
  String get configFileUnusableBanner =>
      'Konfigurační soubor je poškozený nebo nekompatibilní — používám výchozí nastavení. Obnov zálohu v části Import / export.';

  @override
  String configSaveFailed(Object detail) {
    return 'Uložení konfigurace selhalo: $detail';
  }

  @override
  String configInvalidJsonImport(Object detail) {
    return 'Neplatný JSON konfigurace: $detail';
  }

  @override
  String configApplyFailed(Object detail) {
    return 'Nastavení se nepodařilo aplikovat: $detail';
  }

  @override
  String configAutosaveFailed(Object detail) {
    return 'Automatické uložení nastavení selhalo: $detail';
  }

  @override
  String get screenCaptureRepeatedFailureBanner =>
      'Snímání obrazovky opakovaně selhává. Zkontroluj oprávnění (Windows: nastavení soukromí) a výběr monitoru.';

  @override
  String faultUiError(Object detail) {
    return 'Chyba rozhraní: $detail';
  }

  @override
  String get faultUncaughtAsync => 'Neodchycená chyba v asynchronním kódu.';

  @override
  String get errorWidgetTitle =>
      'Chyba při vykreslení widgetu. Aplikace dál běží.\n\n';

  @override
  String get closeBannerTooltip => 'Zavřít';

  @override
  String settingsDevicesSaveFailed(Object detail) {
    return 'Uložení seznamu zařízení selhalo: $detail';
  }

  @override
  String get semanticsSelected => ', vybráno';

  @override
  String get homeOverviewTitle => 'Přehled';

  @override
  String get homeOverviewSubtitle =>
      'Zapni výstup, vyber režim a zkontroluj připojení. Podrobná konfigurace je v záložkách Zařízení a Nastavení.';

  @override
  String get homeModeTitle => 'Režim';

  @override
  String get homeModeSubtitle =>
      'Klepnutím na dlaždici změníš aktivní režim. Ikona tužky v rohu otevře Nastavení přímo pro daný režim.';

  @override
  String get homeIntegrationsTitle => 'Integrace';

  @override
  String get homeIntegrationsSubtitle =>
      'Hudba (Spotify OAuth + volitelně barvy z přehrávače v systému), Home Assistant a firmware ESP — úpravy detailů v příslušných záložkách Nastavení.';

  @override
  String get homeDevicesTitle => 'Zařízení';

  @override
  String get homeDevicesSubtitle =>
      'Rychlý náhled stavu. Úpravy pásku, discovery a sítě jsou v hlavní sekci „Zařízení“ v navigaci.';

  @override
  String get homeDevicesEmpty =>
      'Žádné výstupní zařízení — běžný stav, dokud nepřipojíš pásek.\n\nMůžeš nastavovat režimy, presety a zálohu. Pro odesílání barev přidej zařízení v „Zařízení“ (Discovery nebo ručně).';

  @override
  String get modeLightTitle => 'Světlo';

  @override
  String get modeLightSubtitle => 'Statické efekty, zóny, dýchání';

  @override
  String get modeScreenTitle => 'Obrazovka';

  @override
  String get modeScreenSubtitle => 'Ambilight ze snímku monitoru';

  @override
  String get modeMusicTitle => 'Hudba';

  @override
  String get modeMusicSubtitle => 'FFT, melodie, barvy';

  @override
  String get modePcHealthTitle => 'PC Health';

  @override
  String get modePcHealthSubtitle => 'Teploty, zátěž, vizualizace';

  @override
  String modeSettingsTooltip(Object mode) {
    return 'Nastavení režimu „$mode“';
  }

  @override
  String get homeLedOutputTitle => 'Výstup na LED';

  @override
  String get homeLedOutputOnBody =>
      'Barvy se posílají na všechna aktivní zařízení.';

  @override
  String get homeLedOutputOffBody => 'Vypnuto — pásky dostanou černou.';

  @override
  String get homeServiceTitle => 'Služba';

  @override
  String get homeBackgroundTitle => 'Běží na pozadí';

  @override
  String get homeBackgroundBody =>
      'Aplikace průběžně připravuje barvy pro pásky. Stav se mění při přepnutí režimu nebo připojení zařízení.';

  @override
  String get integrationSettingsButton => 'Nastavení';

  @override
  String get musicCardTitle => 'Hudba';

  @override
  String get spotifyConnected => 'Spotify: připojeno';

  @override
  String get spotifyDisconnected => 'Spotify: nepřipojeno';

  @override
  String get spotifyHintNeedClientId =>
      'Client ID doplníš v Nastavení → Spotify.';

  @override
  String get spotifyHintLogin =>
      '„Přihlásit“ otevře prohlížeč; na Windows lze barvy brát i z přehrávače v systému (viz nápověda).';

  @override
  String get spotifyOAuthTitle => 'Spotify integration (OAuth)';

  @override
  String get spotifyOAuthSubtitle =>
      'Zapne dotazování účtu; vypnutím se zastaví polling.';

  @override
  String get spotifyAlbumColorsTitle => 'Album colors via Spotify';

  @override
  String get spotifyAlbumColorsSubtitle =>
      'V režimu Hudba má přednost před FFT, pokud API vrátí obal.';

  @override
  String get signIn => 'Přihlásit';

  @override
  String get signOut => 'Odpojit';

  @override
  String get haCardTitle => 'Home Assistant';

  @override
  String get haStatusOff => 'Integrace vypnutá.';

  @override
  String haStatusOnOk(Object count) {
    return 'Zapnuto · $count světel v mapě.';
  }

  @override
  String get haStatusOnNeedUrl => 'Zapnuto — doplň URL a token v Nastavení.';

  @override
  String get haDetailOk =>
      'REST API do Home Assistant; barvy z engine mapuješ na entity light.*.';

  @override
  String get haDetailNeedUrl =>
      'Nejdřív URL instance a dlouho žijící token (profil uživatele v HA).';

  @override
  String get fwCardTitle => 'Firmware';

  @override
  String get fwManifestLabel => 'Manifest (OTA)';

  @override
  String get fwManifestHint =>
      'Stažení binárek, příkaz OTA přes UDP nebo flash přes USB (esptool).';

  @override
  String get kindUsb => 'USB';

  @override
  String get kindWifi => 'Wi‑Fi';

  @override
  String get deviceConnected => 'připojeno';

  @override
  String get deviceDisconnected => 'nepřipojeno';

  @override
  String deviceLedSubtitle(Object kind, Object count) {
    return '$kind · $count LED';
  }

  @override
  String deviceStripStateLine(Object info, Object state) {
    return '$info · $state';
  }

  @override
  String get settingsPageTitle => 'Nastavení';

  @override
  String get settingsRailSubtitle =>
      'Vyber téma vlevo — tlačítko Použít nepotřebuješ.';

  @override
  String get settingsPersistHint =>
      'Engine a posuvníky reagují hned; na disk se zapíše krátce po poslední změně. Presety obrazovky a hudby se tím nemění.';

  @override
  String get settingsSidebarBasics => 'Základ';

  @override
  String get settingsSidebarModes => 'Režimy';

  @override
  String get settingsSidebarIntegrations => 'Integrace';

  @override
  String get tabGlobal => 'Globální';

  @override
  String get tabDevices => 'Zařízení';

  @override
  String get tabLight => 'Světlo';

  @override
  String get tabScreen => 'Obrazovka';

  @override
  String get tabMusic => 'Hudba';

  @override
  String get tabPcHealth => 'PC Health';

  @override
  String get tabSpotify => 'Spotify';

  @override
  String get tabSmartHome => 'Smart Home';

  @override
  String get tabFirmware => 'Firmware';

  @override
  String get globalSectionTitle => 'Globální';

  @override
  String get globalSectionSubtitle =>
      'Chování po startu, vzhled a výkon. Import a export konfigurace najdeš níže.';

  @override
  String get startModeLabel => 'Výchozí režim po startu';

  @override
  String get startModeLight => 'Světlo';

  @override
  String get startModeScreen => 'Obrazovka (Ambilight)';

  @override
  String get startModeMusic => 'Hudba';

  @override
  String get startModePcHealth => 'PC Health';

  @override
  String get themeLabel => 'Vzhled aplikace';

  @override
  String get themeHelper =>
      'Tmavě modrý = dřívější výchozí vzhled. SnowRunner = neutrální šedý tmavý režim.';

  @override
  String get themeSnowrunner => 'Tmavý (SnowRunner)';

  @override
  String get themeDarkBlue => 'Tmavě modrý';

  @override
  String get themeLight => 'Světlý';

  @override
  String get themeCoffee => 'Coffee';

  @override
  String get uiAnimationsTitle => 'Animace rozhraní';

  @override
  String get uiAnimationsSubtitle =>
      'Krátké přechody mezi sekcemi. Vypni při opakované práci — respektuje i systémové snížení animací.';

  @override
  String get performanceModeTitle => 'Režim výkonu';

  @override
  String get performanceModeSubtitle =>
      'Při snímání monitoru (Obrazovka nebo Hudba se zdrojem „monitor“) je hlavní smyčka omezená (výchozí ~25 FPS); níže „Tick obrazovky ve výkonu“ vyměníš CPU za plynulejší pásek. Delší intervaly Spotify / PC Health a šetrnější USB fronta. Čistě režim Světlo zůstává rychlejší (~62 Hz). Bez výkonového režimu nastav frekvenci níže (60 / 120 / 240 FPS). „Animace rozhraní“ mění jen Material přechody.';

  @override
  String performanceScreenLoopPeriodLabel(Object ms) {
    return 'Tick obrazovky ve výkonu (ms): $ms';
  }

  @override
  String get performanceScreenLoopPeriodHint =>
      'Nižší ms = vyšší FPS na pásek a vyšší zátěž CPU (16–40 ms). Platí jen ve výkonovém režimu při snímání monitoru.';

  @override
  String get screenRefreshRateTitle => 'Frekvence Ambilight smyčky';

  @override
  String get screenRefreshRateSubtitle =>
      'Hlavní smyčka při vypnutém výkonovém režimu — snímání i výstup na pásky.';

  @override
  String get screenRefreshRateDisabledHint =>
      'Vypni výkonový režim pro změnu (ve výkonu uprav „Tick obrazovky ve výkonu“ výše).';

  @override
  String get screenRefreshRateHz60 => '60 FPS';

  @override
  String get screenRefreshRateHz120 => '120 FPS';

  @override
  String get screenRefreshRateHz240 => '240 FPS';

  @override
  String get autostartTitle => 'Spustit s Windows';

  @override
  String get autostartSubtitle => 'Autostart aplikace po přihlášení k účtu.';

  @override
  String get trayDisableOutput => 'Vypnout výstup';

  @override
  String get trayEnableOutput => 'Zapnout výstup';

  @override
  String trayModeLine(Object mode) {
    return 'Režim: $mode';
  }

  @override
  String get trayScreenPresetsSection => 'Obrazovka — presety';

  @override
  String get trayMusicPresetsSection => 'Hudba — presety';

  @override
  String get trayMusicUnlockColors => 'Odemknout barvy (hudba)';

  @override
  String get trayMusicCancelLockPending =>
      'Zrušit zamykání barev (čeká na snímek)';

  @override
  String get trayMusicLockColorsShort => 'Zamknout barvy (hudba)';

  @override
  String get traySettingsEllipsis => 'Nastavení…';

  @override
  String get trayQuit => 'Ukončit';

  @override
  String get startMinimizedTitle => 'Spustit minimalizovaně';

  @override
  String get captureMethodLabel => 'Metoda snímání obrazovky (pokročilé)';

  @override
  String get captureMethodHint => 'např. mss, dxcam';

  @override
  String get captureMethodHelper =>
      'Desktop používá nativní zásuvný modul snímání. Na Windows volíš GDI vs DXGI v Nastavení → Obrazovka.';

  @override
  String get captureMethodNativeMss => 'Nativní snímání (výchozí · mss)';

  @override
  String captureMethodCustomSaved(Object name) {
    return 'Uložená hodnota: $name';
  }

  @override
  String get screenMonitorVirtualDesktopChoice =>
      '0 · Virtuální plocha (všechny monitory)';

  @override
  String get screenMonitorRefreshTooltip => 'Obnovit seznam monitorů';

  @override
  String get screenMonitorListFallbackHint =>
      'Seznam monitorů nelze načíst — níže ruční MSS indexy. Zkus „Obnovit“.';

  @override
  String get onboardWelcomeTitle => 'Vítej v AmbiLight';

  @override
  String get onboardWelcomeBody =>
      'Tato aplikace řídí tvoje LED pásky z Windows — přes USB (sériový port) nebo přes síť (UDP). Firmware na ESP32 zůstává stejný jako u starších klientů; jen ovládání je tady hezčí a přehlednější.';

  @override
  String get onboardHowTitle => 'Jak to celé funguje';

  @override
  String get onboardHowBody =>
      'AmbiLight bere barvy z obrazovky, mikrofonu, PC senzorů nebo statických efektů a posílá je jako RGB data na kontrolér. V horní liště zapínáš a vypínáš samotný výstup — když je vypnutý, pásek nedostává nové příkazy z aplikace.';

  @override
  String get onboardOutputTitle => 'Výstup zapnutý / vypnutý';

  @override
  String get onboardOutputBody =>
      'Tlačítko „Výstup zapnutý“ v hlavičce je hlavní pojistka: vypni ho, když chceš pásek nechat v klidu, nebo při řešení problémů s připojením. Zapni ho až máš nastavené zařízení a režim.';

  @override
  String get onboardModesTitle => 'Režimy';

  @override
  String get onboardModesBody =>
      'Světlo — statické barvy a efekty. Obrazovka — ambilight ze snímku monitoru (segmenty a hloubka okraje v Nastavení). Hudba — FFT a melodie z mikrofonu nebo systému. PC Health — vizualizace teplot a zátěže.';

  @override
  String get onboardDevicesTitle => 'Zařízení';

  @override
  String get onboardDevicesBody =>
      'Na stránce Zařízení přidáš pásky, spustíš discovery a nastavíš počet LED, offset a výchozí monitor. USB používá COM port a baud rate; Wi‑Fi vyžaduje IP a UDP port (stejné jako ve firmware).';

  @override
  String get onboardScreenTitle => 'Obrazovka a zóny';

  @override
  String get onboardScreenBody =>
      'V Nastavení → obrazovka určíš, jak hluboko se bere okraj, padding a případně jednotlivé segmenty na pásku. Náhled oblasti snímání (malý překryv) pomůže zkontrolovat geometrii bez hádání.';

  @override
  String get onboardMusicTitle => 'Hudba a Spotify';

  @override
  String get onboardMusicBody =>
      'Hudba umí barvy z mikrofonu nebo z výstupu zvukové karty. Spotify je volitelná integrace — Client ID získáš v dashboardu vývojáře Spotify; podrobný návod je v aplikaci u nastavení Spotify.';

  @override
  String get onboardSmartTitle => 'PC Health a chytrá světla';

  @override
  String get onboardSmartBody =>
      'PC Health čte senzory (teploty, zátěž) a mapuje je na barvy. Chytrá světla umí Home Assistant: po zadání URL a tokenu můžeš synchronizovat barvy i na další lampy v místnosti.';

  @override
  String get onboardFirmwareTitle => 'Nastavení a firmware';

  @override
  String get onboardFirmwareBody =>
      'Globální nastavení obsahuje téma vzhledu, výkonový režim, metodu snímání obrazovky a manifest firmware (OTA odkazy). Konfiguraci můžeš exportovat/importovat jako JSON — před experimenty si ji zálohuj.';

  @override
  String get onboardReadyTitle => 'Jdeš na to';

  @override
  String get onboardReadyBody =>
      'Průvodce průběžně najdeš znovu v záložce O aplikaci. Doporučený postup: přidej zařízení → zkontroluj výstup → vyber režim Obrazovka nebo Světlo → doladíš jas v nastavení.';

  @override
  String get onboardStartUsing => 'Začít používat';

  @override
  String onboardProgress(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get onboardIllustColorsToStrip => 'Barvy jedou na pásek';

  @override
  String get onboardIllustMiniBackup => 'Záloha JSON';

  @override
  String get onboardIllustCpuLabel => 'CPU';

  @override
  String get onboardIllustGpuLabel => 'GPU';

  @override
  String get onboardOutputTourOnlyHint =>
      'Jen náhled — skutečný přepínač výstupu je v horní liště aplikace.';

  @override
  String onboardSlideDotA11y(int n, int total) {
    return 'Přejít na krok $n z $total';
  }

  @override
  String get onboardScreenHuePreview => 'Náhled odstínu';

  @override
  String get onboardSettingsSnackModes =>
      'Aktivní režim vybereš na přehledu (dlaždice nahoře).';

  @override
  String get onboardSettingsSnackFirmware =>
      'Firmware a OTA: Nastavení → Firmware.';

  @override
  String get onboardSettingsSnackBackup =>
      'Záloha JSON: Nastavení → Globální → Export.';

  @override
  String get onboardConnectivityUsbTap =>
      'USB: COM port nastavíš v záložce Zařízení.';

  @override
  String get onboardConnectivityWifiTap =>
      'Wi‑Fi: IP a UDP port v Zařízeních (stejně jako ve firmware).';

  @override
  String get onboardKeysHint =>
      'Klávesnice: šipky mění krok, Esc přeskočí průvodce.';

  @override
  String get devicesPageTitle => 'Zařízení';

  @override
  String get devicesActionsTitle => 'Actions';

  @override
  String get discoveryWizardLabel => 'Discovery — průvodce';

  @override
  String get segmentsLabel => 'Segments';

  @override
  String get calibrationLabel => 'Calibration';

  @override
  String get screenPresetLabel => 'Preset obrazovky';

  @override
  String get addWifiManual => 'Přidat Wi-Fi ručně';

  @override
  String get findAmbilightCom => 'Find Ambilight (COM)';

  @override
  String get devicesIntro =>
      'Správa pásků: discovery, Wi‑Fi a kalibrace. Uložením se zapíše konfigurace a znovu se navážou transporty.';

  @override
  String get saveDeviceTitle => 'Uložit zařízení';

  @override
  String get invalidIp => 'Neplatná IP adresa.';

  @override
  String get pongTimeout => 'PONG nepřišel (timeout).';

  @override
  String pongResult(Object version, Object leds) {
    return 'PONG: FW $version, LED $leds';
  }

  @override
  String get verifyPong => 'Ověřit PONG';

  @override
  String get enterValidIpv4 => 'Enter a valid IPv4 address.';

  @override
  String get deviceSaved => 'Zařízení uloženo.';

  @override
  String get resetWifiTitle => 'Reset Wi‑Fi?';

  @override
  String get resetWifiBody =>
      'Odešle RESET_WIFI přes UDP na zařízení. Používej jen pokud víš, co děláš.';

  @override
  String get sendResetWifi => 'Odeslat RESET_WIFI';

  @override
  String get resetWifiSent => 'RESET_WIFI odeslán.';

  @override
  String get resetWifiFailed => 'Odeslání se nezdařilo.';

  @override
  String removeFailed(Object error) {
    return 'Odebrání se nepodařilo: $error';
  }

  @override
  String deviceRemoved(Object name) {
    return 'Zařízení „$name“ bylo odebráno.';
  }

  @override
  String get pongMissing => 'PONG nepřišel.';

  @override
  String firmwareFromPong(Object version) {
    return 'Firmware (z PONG): $version';
  }

  @override
  String get comScanHandshake => 'Hledám COM s handshake 0xAA / 0xBB…';

  @override
  String get comScanNoReply => 'Žádný port neodpověděl (Ambilight handshake).';

  @override
  String serialPortSet(Object port) {
    return 'Nastaven sériový port: $port';
  }

  @override
  String comScanUsbDeviceDefaultName(Object port) {
    return 'USB ($port)';
  }

  @override
  String comScanUsbDeviceAdded(Object port) {
    return 'Přidáno USB zařízení na $port. Název můžeš změnit v seznamu.';
  }

  @override
  String firmwareLabel(Object version) {
    return 'Firmware: $version';
  }

  @override
  String get discoveryTitle => 'Discovery (D9)';

  @override
  String get discoveryRescan => 'Scan again';

  @override
  String get discoveryScanning => 'Skenuji…';

  @override
  String get discoveryNoReply => 'Žádné zařízení neodpovědělo (UDP 4210).';

  @override
  String discoveryAdded(Object name) {
    return 'Přidáno: $name';
  }

  @override
  String get discoveryAdd => 'Přidat';

  @override
  String get discoverySelectHint =>
      'Projdi síť na UDP 4210; nalezená zařízení se zobrazí níže.';

  @override
  String get zoneEditorTitle => 'Editor zón / segmentů (D11)';

  @override
  String get zoneEditorAddSegment => 'Přidat segment';

  @override
  String zoneEditorSaved(Object count) {
    return 'Uloženo $count segmentů.';
  }

  @override
  String zoneEditorIntro(Object max) {
    return 'Max LED index: $max. Každý segment: LED rozsah, hrana, monitor, hloubka skenu, obrácený směr, mapování pixelů a role v hudbě.';
  }

  @override
  String zoneEditorSegmentTitle(Object index, Object edge, Object ledStart,
      Object ledEnd, Object monitor) {
    return 'Segment $index · $edge · LED $ledStart–$ledEnd · mon $monitor';
  }

  @override
  String get refDimsFromCapture => 'Ref. dimensions from last capture';

  @override
  String get dropdownAllDefault => '— all / default —';

  @override
  String get guideMusicTitle => 'Hudba a Spotify';

  @override
  String get guideBrowserFailed => 'Otevření prohlížeče se nezdařilo.';

  @override
  String get guideNeedClientIdFirst =>
      'Nejdřív v Nastavení → Spotify zadej Client ID (viz tlačítko výše).';

  @override
  String get guideClose => 'Zavřít';

  @override
  String get guideOpenSpotifyDev => 'Open Spotify Developer';

  @override
  String get guideSpotifyBrowserLogin => 'Sign in to Spotify in browser';

  @override
  String get guideSectionSound => '1 · Režim a zvuk';

  @override
  String get guideSectionAlbum => '2 · Barva z obalu';

  @override
  String get guideSectionSpotify => '3 · Spotify';

  @override
  String get guideSectionApple => '4 · Apple Music';

  @override
  String get guideSectionTrouble => 'Když něco nejde';

  @override
  String get backupTitle => 'Záloha konfigurace';

  @override
  String get backupExport => 'Exportovat JSON…';

  @override
  String get backupImport => 'Importovat JSON…';

  @override
  String get backupExported => 'Konfigurace exportována.';

  @override
  String get backupImported => 'Konfigurace importována.';

  @override
  String get backupInvalid => 'Neplatný soubor konfigurace.';

  @override
  String get factoryResetTitle => 'Obnovit výchozí';

  @override
  String get factoryResetButton => 'Obnovit výrobní nastavení…';

  @override
  String get factoryResetDialogTitle => 'Obnovit výrobní nastavení?';

  @override
  String get factoryResetDialogBody =>
      'Všechna nastavení se vrátí na vestavěné výchozí hodnoty, zařízení a zóny se vymažou a uložené tokeny Home Assistant a Spotify se odstraní. Akci nelze vrátit — pokud potřebuješ kopii, nejdřív exportuj JSON zálohu.';

  @override
  String get factoryResetConfirm => 'Obnovit výchozí';

  @override
  String get factoryResetDone => 'Nastavení bylo obnoveno na výchozí hodnoty.';

  @override
  String factoryResetFailed(String error) {
    return 'Obnovení selhalo: $error';
  }

  @override
  String get spotifyTabTitle => 'Spotify';

  @override
  String get spotifyTabIntro =>
      'OAuth tokeny a barvy z obalů. Nápověda vysvětluje obraz zvuku a obaly.';

  @override
  String get spotifyHelpAlbum => 'Nápověda: hudba a obaly';

  @override
  String get spotifyIntegrationEnabled => 'Spotify integrace zapnutá';

  @override
  String get spotifyAlbumColors => 'Barvy z alba (Spotify API)';

  @override
  String get spotifyDeleteSecretDraft => 'Smazat client secret z draftu';

  @override
  String get spotifyAccessToken => 'Access token';

  @override
  String get spotifyRefreshToken => 'Refresh token';

  @override
  String get spotifyTokenSetHidden => 'Nastaven (skryto)';

  @override
  String get spotifyTokenMissing => 'Chybí';

  @override
  String get spotifyAppleOsTitle => 'Apple Music / YouTube Music (OS)';

  @override
  String get spotifyAppleOsBody =>
      'Použije se v music módu, pokud Spotify neposkytne barvu nebo je vypnuté.';

  @override
  String get spotifyGsmtcOn => 'Barva z obalu přes OS média (GSMTC)';

  @override
  String get spotifyGsmtcOff => 'Barva z obalu přes OS média (nedostupné)';

  @override
  String get spotifyGsmtcSubtitle =>
      'Použije se v music módu, pokud Spotify neposkytne barvu nebo je vypnuté.';

  @override
  String get spotifyDominantThumb => 'Použít dominantní barvu z miniatury OS';

  @override
  String get firmwareEspTitle => 'ESP firmware';

  @override
  String get firmwareEspIntro =>
      'URL manifestu, stažení binárek a flash/OTA. Vyžaduje kompatibilní kontrolér.';

  @override
  String get firmwareManifestUrlLabel => 'URL manifestu (GitHub Pages)';

  @override
  String get firmwareManifestUrlHint =>
      'https://alfredkrutina.github.io/ambilight/firmware/latest/';

  @override
  String get firmwareManifestHelper =>
      'Výchozí z globálního nastavení; bez souboru doplníme /manifest.json';

  @override
  String get firmwareLoadManifest => 'Načíst manifest';

  @override
  String get firmwareDownloadBins => 'Stáhnout binárky';

  @override
  String firmwareVersionChip(Object version, Object chip) {
    return 'Verze: $version · čip: $chip';
  }

  @override
  String firmwarePartLine(Object file, Object offset) {
    return '• $file @ $offset';
  }

  @override
  String firmwareOtaUrlLine(Object url) {
    return 'OTA URL: $url';
  }

  @override
  String get firmwareUsbFlashTitle => 'Flash přes USB (COM)';

  @override
  String get firmwareRefreshPorts => 'Obnovit seznam portů';

  @override
  String get firmwareSelectPortFirst => 'Vyber sériový port.';

  @override
  String get firmwarePickFirmwareFolder =>
      'Vyber složku firmware s manifest.json.';

  @override
  String get firmwareFlashEsptool => 'Flashovat přes esptool';

  @override
  String get firmwareOtaUdpTitle => 'OTA přes Wi‑Fi (UDP)';

  @override
  String get firmwareDeviceIp => 'IP zařízení';

  @override
  String get firmwareUdpPort => 'UDP port';

  @override
  String get firmwareVerifyReachability => 'Ověřit dosah (UDP PONG)';

  @override
  String get firmwareSendOtaHttp => 'Odeslat OTA_HTTP';

  @override
  String get smartHaUrlLabel => 'URL (https://…:8123)';

  @override
  String get smartHaTokenLabel => 'Long-lived access token';

  @override
  String get smartHaConfigureFirst =>
      'Nejdřív nastav URL a token Home Assistant.';

  @override
  String smartHaError(Object error) {
    return 'HA: $error';
  }

  @override
  String get smartHaNoLights => 'V HA nejsou žádné entity light.*';

  @override
  String get smartAddLightTitle => 'Přidat světlo z Home Assistant';

  @override
  String get smartIntegrationTitle => 'Smart Home';

  @override
  String get smartIntegrationSubtitle => 'Home Assistant a vlna přes místnost.';

  @override
  String get virtualRoomWaveTitle => 'Vlna přes místnost';

  @override
  String get virtualRoomWaveSubtitle =>
      'Modulace jasu podle vzdálenosti od TV a času snímku';

  @override
  String virtualRoomWaveStrength(Object pct) {
    return 'Síla vlny: $pct %';
  }

  @override
  String get virtualRoomWaveSpeed => 'Rychlost vlny';

  @override
  String get virtualRoomDistanceSens => 'Citlivost na vzdálenost';

  @override
  String virtualRoomFacing(Object deg) {
    return 'Úchyl pohledu od osy k TV: $deg°';
  }

  @override
  String get scanOverlaySettingsTitle => 'Náhled skenu (D-detail)';

  @override
  String get scanOverlaySettingsIntro =>
      'Náhled zón na monitoru při ladění režimu Obrazovka.';

  @override
  String get scanOverlayPreviewTitle => 'Náhled zón na monitor při ladění';

  @override
  String get scanOverlayPreviewSubtitle =>
      'Krátký přes celou obrazovku; nesahá na samotný capture.';

  @override
  String get scanOverlayMonitorLabel => 'Monitor (MSS index, shodně s capture)';

  @override
  String get scanOverlayShowNow => 'Ukázat náhled zón teď (~1 s)';

  @override
  String get scanDepthPercentTitle => 'Hloubka snímání % (per-edge)';

  @override
  String get scanPaddingPercentTitle => 'Odsazení % (per-edge)';

  @override
  String get scanRegionSchemeTitle =>
      'Schéma oblasti (poměr zvoleného monitoru)';

  @override
  String get scanLastFrameTitle => 'Poslední snímek (screen režim)';

  @override
  String get pcHealthSectionTitle => 'PC Health';

  @override
  String get pcHealthSectionSubtitle =>
      'Senzory do barev. Přidej metriky a mapuj je na zóny.';

  @override
  String get pcHealthEnabledTitle => 'PC Health enabled';

  @override
  String get pcHealthEnabledSubtitle =>
      'Vypnuto = černý výstup v tomto režimu.';

  @override
  String get pcHealthMetricNew => 'Nová metrika';

  @override
  String get pcHealthMetricEdit => 'Upravit metriku';

  @override
  String get pcHealthMetricEnabled => 'Zapnuto';

  @override
  String get pcHealthMetricName => 'Název';

  @override
  String get pcHealthMetricKey => 'Metrika';

  @override
  String get pcHealthMetricMin => 'Min';

  @override
  String get pcHealthMetricMax => 'Max';

  @override
  String get pcHealthColorScale => 'Barevná škála';

  @override
  String get pcHealthBrightnessMode => 'Jas';

  @override
  String get pcHealthBrightnessStatic => 'Statický';

  @override
  String get pcHealthBrightnessDynamic => 'Dynamický (podle hodnoty)';

  @override
  String get pcHealthZonesTitle => 'Zóny';

  @override
  String get pcHealthLivePreview => 'Živý náhled hodnot';

  @override
  String get pcHealthMeasureNow => 'Změřit teď';

  @override
  String pcHealthMetricsHeader(Object count) {
    return 'Metriky ($count)';
  }

  @override
  String get pcHealthNoMetrics => 'Žádné metriky.';

  @override
  String get pcHealthDefaultMetrics => 'Výchozí';

  @override
  String get pcHealthColorStripPreview => 'Barevný pruh (náhled)';

  @override
  String get pcHealthStagingHint =>
      '[staging] PC Health: náhled + editor metrik';

  @override
  String get lightSectionTitle => 'Světlo';

  @override
  String get lightSectionSubtitle => 'Statická barva, efekty, zóny a jas.';

  @override
  String get screenSectionTitle => 'Obrazovka';

  @override
  String get screenSectionSubtitle =>
      'Režim screen: barvy z okrajů monitoru. Kalibraci a segmenty upravíš i v Zařízeních. Náhled zón při ladění je jen vrstva v okně aplikace (zvýrazněné pruhy skenu, bez přesunu okna).';

  @override
  String get musicSectionTitle => 'Hudba';

  @override
  String get musicSectionSubtitle => 'Mikrofon, efekty a integrace Spotify.';

  @override
  String get devicesTabTitle => 'Zařízení';

  @override
  String get devicesTabSubtitle =>
      'USB a Wi‑Fi kontroléry, počty LED a výchozí monitor.';

  @override
  String get usbSerialLabel => 'USB / sériový';

  @override
  String get udpWifiLabel => 'UDP / Wi‑Fi';

  @override
  String get onboardingModesDemoLabel => 'Režimy';

  @override
  String get onboardingOutputDemoOn => 'Výstup zapnutý';

  @override
  String get onboardingOutputDemoOff => 'Výstup vypnutý';

  @override
  String get calibrationTitle => 'Calibration';

  @override
  String get ledStripWizardTitle => 'Průvodce páskem LED';

  @override
  String get configProfileWizardTitle => 'Uložit screen preset (D14)';

  @override
  String get colorPickerTitle => 'Pick color';

  @override
  String get colorPickerHex => 'Hex';

  @override
  String get devicesTabPlaceholder => '';

  @override
  String get onboardingReplayTitle => 'Úvodní průvodce';

  @override
  String get onboardingReplayBody =>
      'Stejný návod jako při prvním spuštění — vysvětlí výstup, režimy, zařízení a nastavení.';

  @override
  String get replayOnboardingButton => 'Znovu spustit úvodní průvodce';

  @override
  String get uiControlLevelLabel => 'Úroveň ovládání';

  @override
  String get uiControlLevelHelper =>
      'Jednoduchý režim skryje pokročilé doladění obrazovky (gamma, značky kalibrace, diagnostiku snímání). Kdykoli změníš v nastavení.';

  @override
  String get uiControlLevelSimple => 'Jednoduchý';

  @override
  String get uiControlLevelAdvanced => 'Pokročilý';

  @override
  String get onboardWizardStepThemeTitle => 'Vzhled';

  @override
  String get onboardWizardStepThemeSubtitle =>
      'Kdykoli změníš v Nastavení → Globální.';

  @override
  String get onboardWizardThemeLightTitle => 'Světlý';

  @override
  String get onboardWizardThemeLightSubtitle =>
      'Světlé plochy a přehledné ovládací prvky.';

  @override
  String get onboardWizardThemeDarkTitle => 'Tmavý';

  @override
  String get onboardWizardThemeDarkSubtitle =>
      'Příjemnější ve ztlumeném prostředí.';

  @override
  String get onboardWizardStepComplexityTitle =>
      'Jak podrobné má být nastavení?';

  @override
  String get onboardWizardStepComplexitySubtitle =>
      'Jednoduchý nechá jen běžné posuvníky. Pokročilý ukáže gamma, odsazení a diagnostiku.';

  @override
  String get onboardWizardComplexitySimpleTitle => 'Jednoduchý';

  @override
  String get onboardWizardComplexitySimpleSubtitle =>
      'Doporučeno — méně přepínačů, rychlejší start.';

  @override
  String get onboardWizardComplexityAdvancedTitle => 'Pokročilý';

  @override
  String get onboardWizardComplexityAdvancedSubtitle =>
      'Plná kontrola nad snímáním, barvami a nástroji kalibrace.';

  @override
  String get onboardWizardStepDeviceTitle => 'Připojení kontroléru';

  @override
  String get onboardWizardStepDeviceSubtitle =>
      'Jak má PC komunikovat s LED. Další zařízení přidáš později na stránce Zařízení.';

  @override
  String get onboardWizardScanWifi => 'Hledat zařízení ve Wi‑Fi';

  @override
  String get onboardWizardSetupUsb => 'Nastavit USB / sériový port';

  @override
  String get onboardWizardStepMappingTitle => 'Mapovat LED na obrazovku';

  @override
  String get onboardWizardStepMappingSubtitle =>
      'Projdi pásek jednou, aby rohy seděly s monitorem. Přeskoč, když to uděláš později.';

  @override
  String get onboardWizardOpenMapping => 'Otevřít průvodce mapováním';

  @override
  String get onboardWizardMappingSkip => 'PŘESKOČIT';

  @override
  String get onboardWizardStepIntegrationsTitle => 'Integrace';

  @override
  String get onboardWizardStepIntegrationsSubtitle =>
      'Volitelné doplňky — zapneš je, až je budeš potřebovat.';

  @override
  String get onboardWizardHaCardTitle => 'Home Assistant';

  @override
  String get onboardWizardHaCardBody =>
      'Zrcadlení barev na lampy a automatizace přes URL HA a dlouho platný token.';

  @override
  String get onboardWizardSpotifyCardTitle => 'Spotify';

  @override
  String get onboardWizardSpotifyCardBody =>
      'Bohatší vizualizace hudby po propojení aplikace ve Spotify Developer (Client ID v nastavení).';

  @override
  String get onboardWizardPcHealthCardTitle => 'PC Health';

  @override
  String get onboardWizardPcHealthCardBody =>
      'Teploty a zátěž řídí ambientní barvy — vhodné pro přehledy na pozadí.';

  @override
  String get onboardWizardPreviewHint =>
      'Duhový náhled používá stejnou syntetickou cestu jako Nastavení → Obrazovka.';

  @override
  String get onboardWizardFinish => 'Začít používat';

  @override
  String get setupWizardLanguageHeader => 'Choose your language / Zvolte jazyk';

  @override
  String get setupWizardLanguageSubtitle =>
      'Použije se hned — změníš kdykoli v Nastavení → Globální.';

  @override
  String get setupWizardLanguageEnglishTitle => 'English';

  @override
  String get setupWizardLanguageEnglishSubtitle => 'Výchozí jazyk rozhraní.';

  @override
  String get setupWizardLanguageCzechTitle => 'Čeština';

  @override
  String get setupWizardLanguageCzechSubtitle => 'České řetězce v aplikaci.';

  @override
  String get setupWizardAppearanceHeader => 'Jak má vypadat?';

  @override
  String get setupWizardAppearanceSubtitle =>
      'Vyber paletu vzhledu — uloží se hned do profilu.';

  @override
  String get setupWizardThemeOptionLightSubtitle =>
      'Světlé plochy s tyrkysovými akcenty.';

  @override
  String get setupWizardThemeOptionDarkBlueSubtitle =>
      'Zvýraznění cyan a fialová na tmavě modré — klasický vzhled AmbiLight.';

  @override
  String get setupWizardThemeOptionSnowrunnerSubtitle =>
      'Neutrální tmavě šedé rozhraní s teplým oranžovým akcentem.';

  @override
  String get setupWizardThemeOptionCoffeeSubtitle =>
      'Teplé krémové a hnědé tóny.';

  @override
  String get setupWizardExpertiseSimpleExplain =>
      'Pokročilé položky (gamma, vyhlazování a jemné IP/offsety) zůstanou skryté pro přehlednější práci. Na Pokročilý přepneš kdykoli v Globálním nastavení.';

  @override
  String get setupWizardUsbListTitle => 'USB — sériové porty';

  @override
  String get setupWizardUsbEmpty =>
      'Žádný COM port. Připoj kontrolér a klepni na obnovit.';

  @override
  String get setupWizardUsbConnect => 'Připojit';

  @override
  String get setupWizardUsbWebHint =>
      'USB/sériové nastavení je ve desktopové verzi pro Windows.';

  @override
  String get setupWizardComDtrRtsHint =>
      'Test používá stejné nastavení linek DTR/RTS jako běžné připojení (ESP32‑C3 USB‑JTAG nebo klasický USB‑UART bridge).';

  @override
  String get setupWizardDeviceWifiSection => 'Wi‑Fi / síť';

  @override
  String get setupWizardDeviceSerialSection => 'USB / sériový port';

  @override
  String get setupWizardDeviceWifiIntro =>
      'Na lokální síti pošleme UDP broadcast (port 4210). Nalezené kontroléry se zobrazí níže — klepnutím na Přidat ho uložíš do profilu.';

  @override
  String get setupWizardDeviceSerialIntro =>
      'Vyber COM port, na kterém máš ESP32 nebo USB‑UART adaptér (např. COM3). Test ověří, že jde o AmbiLight kontrolér, než ho přidáš.';

  @override
  String get setupWizardDeviceWifiDesktopOnly =>
      'Vyhledávání přes Wi‑Fi je v desktopové verzi pro Windows.';

  @override
  String get setupWizardDeviceTestConnection => 'Test';

  @override
  String get setupWizardDeviceAdd => 'Přidat';

  @override
  String get setupWizardDeviceScanningLabel => 'Skenuji síť…';

  @override
  String get setupWizardDeviceIdentifiedShort => 'Nalezen AmbiLight kontrolér.';

  @override
  String get setupWizardDeviceTestFailedShort =>
      'Na tomto portu není AmbiLight kontrolér.';

  @override
  String setupWizardDeviceControllerId(Object macSuffix) {
    return 'ID: $macSuffix';
  }

  @override
  String setupWizardDeviceWifiScanFailed(Object message) {
    return 'Skenování selhalo: $message';
  }

  @override
  String get setupWizardMappingEdgesTitle =>
      'LED pod hranou obrazovky (aktuální mapování)';

  @override
  String get setupWizardMappingRainbowHint =>
      'Duhová kontrola jde syntetickou cestou výstupu z obrazovky, aby šlo vidět reakci pásku.';

  @override
  String get setupWizardWhatsNextTitle => 'Co dál?';

  @override
  String get setupWizardWhatsNextSubtitle =>
      'Volitelné funkce, až budeš chtít víc než barvy z obrazovky.';

  @override
  String get setupWizardCardSpotifyTitle => 'Integrace Spotify';

  @override
  String get setupWizardCardSpotifyBody => 'Synchronizace barev s hudbou.';

  @override
  String get setupWizardCardHaTitle => 'Home Assistant';

  @override
  String get setupWizardCardHaBody =>
      'Ovládání přes tvůj chytrý domov (URL + dlouho platný token).';

  @override
  String get setupWizardCardPcHealthTitle => 'PC Health';

  @override
  String get setupWizardCardPcHealthBody => 'Teploty CPU/GPU přes barvy.';

  @override
  String get setupWizardFinalHeadline => 'Hotovo.';

  @override
  String get setupWizardFinalSubtitle =>
      'Výstup zapni v horní liště, až bude hardware připravený.';

  @override
  String get setupWizardLetsGlow => 'LET\'S GLOW';

  @override
  String setupWizardStepCounter(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get devicesPageSubtitle =>
      'Vyhledání v síti, úprava segmentů a kalibrace. Klepnutím na řádek zařízení otevřeš mapování LED.';

  @override
  String get fieldDeviceName => 'Název';

  @override
  String get fieldIpAddress => 'IP adresa';

  @override
  String get fieldUdpPort => 'UDP port';

  @override
  String get fieldLedCount => 'Počet LED';

  @override
  String removeDeviceFailed(Object detail) {
    return 'Odebrání zařízení selhalo: $detail';
  }

  @override
  String exportSavedTo(Object path) {
    return 'Uloženo: $path';
  }

  @override
  String exportFailed(Object error) {
    return 'Export selhal: $error';
  }

  @override
  String get importReadError => 'Soubor nelze přečíst (chybí cesta).';

  @override
  String get importLoaded => 'Konfigurace načtena a uložena.';

  @override
  String importFailed(Object error) {
    return 'Import selhal: $error';
  }

  @override
  String get backupIntroBody =>
      'JSON stejný jako u Python verze (`config/default.json`). Import přepíše běžící nastavení a uloží ho.';

  @override
  String get exportDialogTitle => 'Export konfigurace AmbiLight';

  @override
  String get devicesConfiguredTitle => 'Nakonfigurovaná zařízení';

  @override
  String get devicesEmptyStateBody =>
      'Zatím žádné — můžeš nejdřív nastavit režimy a presety. Pro ovládání pásku přidej USB nebo Wi‑Fi výše.';

  @override
  String get diagnosticsComPorts => 'Diagnostika (COM porty)';

  @override
  String get noSerialPortsDetected => 'Žádné porty nejsou detekované.';

  @override
  String resetWifiContent(Object name) {
    return 'Zařízení „$name“ smaže uložené Wi‑Fi přihlašovací údaje na kontroléru a restartuje se. Budete ho muset znovu připojit k síti.';
  }

  @override
  String get screenSettingsLayoutTitle => 'Režim nastavení';

  @override
  String get screenModeSimpleLabel => 'Jednoduchý';

  @override
  String get screenModeAdvancedLabel => 'Rozšířený';

  @override
  String get screenModeHintAdvanced =>
      'Zobrazí se všechna pole včetně barevných křivek, technického indexu monitoru a per‑hrana v sekci náhledu.';

  @override
  String get screenModeHintSimple =>
      'Stačí monitor, jas, plynulost a jednotná hloubka / odsazení skenu. Detailní zóny v náhledu dole.';

  @override
  String get fieldMonitorIndexLabel => 'Monitor (index)';

  @override
  String get fieldMonitorSameAsCaptureLabel => 'Monitor (shodně se snímáním)';

  @override
  String screenScanDepthUniformPct(Object pct) {
    return 'Hloubka snímání (jednotně): $pct %';
  }

  @override
  String screenPaddingUniformPct(Object pct) {
    return 'Odsazení (jednotně): $pct %';
  }

  @override
  String get screenColorSamplingLabel => 'Barva LED ze skenované oblasti';

  @override
  String get screenColorSamplingMedian => 'Medián (výchozí jako PyQt)';

  @override
  String get screenColorSamplingAverage => 'Průměr (mean)';

  @override
  String get screenColorSamplingHint =>
      'Každá LED má podél hrany vlastní obdélník (stejná geometrie při libovolném rozlišení snímku). Medián potlačí světlé výjimky; průměr odpovídá jemnějšímu smíchání podobně jako cv2.resize INTER_AREA v PyQt.';

  @override
  String get screenCaptureCardTitle => 'Snímání obrazovky';

  @override
  String get refreshDiagnostics => 'Obnovit diagnostiku';

  @override
  String get screenCapturePermissionOk =>
      'Oprávnění obrazovky: OK / zkontroluj Soukromí.';

  @override
  String get screenCapturePermissionDenied =>
      'Oprávnění zamítnuto nebo nedostupné.';

  @override
  String get macosRequestScreenCapture => 'macOS: žádost o snímání obrazovky';

  @override
  String get screenImageOutputTitle => 'Obraz a výstup';

  @override
  String get screenWindowsCaptureBackendLabel => 'Snímání ve Windows';

  @override
  String get screenWindowsCaptureBackendHint =>
      'CPU (GDI) často méně problikává kurzor; GPU (DXGI) používá Desktop Duplication pro konkrétní monitor (ne virtuální plochu 0).';

  @override
  String get screenWindowsCaptureBackendCpu => 'CPU (GDI)';

  @override
  String get screenWindowsCaptureBackendGpu => 'GPU (DXGI)';

  @override
  String screenBrightnessValue(Object v) {
    return 'Jas (screen): $v';
  }

  @override
  String screenInterpolationMs(Object v) {
    return 'Interpolace (ms): $v';
  }

  @override
  String get screenUniformRegionTitle => 'Oblast snímání (jednotné)';

  @override
  String get screenTechMonitorTitle => 'Technický monitor a jednotná oblast';

  @override
  String get fieldMonitorIndexMssLabel => 'monitor_index (MSS, 0–32)';

  @override
  String get screenColorsDetailTitle => 'Barvy a sken (podrobně)';

  @override
  String screenGammaValue(Object v) {
    return 'Gamma: $v';
  }

  @override
  String screenSaturationBoostValue(Object v) {
    return 'Saturation boost: $v';
  }

  @override
  String get screenUltraSaturation => 'Ultra saturace';

  @override
  String screenUltraAmountValue(Object v) {
    return 'Ultra amount: $v';
  }

  @override
  String screenMinBrightnessLed(Object v) {
    return 'Min. jas (LED): $v';
  }

  @override
  String get fieldScreenColorPreset => 'Barevný preset obrazovky';

  @override
  String get helperScreenColorPreset =>
      'Rychlé presety, výchozí názvy a uložené user_screen_presets';

  @override
  String get fieldActiveCalibrationProfile => 'Aktivní kalibrační profil';

  @override
  String get helperCalibrationProfileKeys =>
      'Klíče z calibration_profiles v konfiguraci';

  @override
  String get stripMarkersTitle => 'Značky na pásku';

  @override
  String get stripMarkersBody =>
      'Zelené LED v rozích (jako PyQt kalibrace). Při indikaci se použije max. délka pro transport (USB až 2000 LED s wide rámcem 0xFC, Wi‑Fi dle UDP), ne zadaný počet LED v zařízení — aby šly rozsvítit i vysoké indexy. „Vypnout“ před uložením nebo při přepnutí záložky.';

  @override
  String get markerTopLeft => 'Levý horní';

  @override
  String get markerTopRight => 'Pravý horní';

  @override
  String get markerBottomRight => 'Pravý spodní';

  @override
  String get markerBottomLeft => 'Levý spodní';

  @override
  String get markerOff => 'Vypnout značky';

  @override
  String get screenRainbowSynthSectionTitle => 'Diagnostika pipeline';

  @override
  String get screenRainbowSynthSwitchTitle =>
      'Syntetická duha (ignorovat pixely obrazovky)';

  @override
  String get screenRainbowSynthSwitchSubtitle =>
      'Worker obrazovky přeskočí ROI a po stejné cestě pack/UDP pošle pohyblivý test. Ve výchozím vypnuto — k oddělení zpoždění snímání od zbytku řetězce.';

  @override
  String get segmentsTileTitle => 'Segmenty';

  @override
  String segmentsZoneEditorSubtitle(Object count) {
    return 'Počet: $count (editor zón A7)';
  }

  @override
  String screenSegmentMonitorMismatchBanner(Object capture) {
    return 'Některé segmenty LED vzorkují jiný monitor než vybraný zdroj snímku (index $capture). Upravte monitor u segmentů nebo monitor pro snímání.';
  }

  @override
  String get lightZoneColorTitle => 'Barva zóny';

  @override
  String get lightPrimaryColorTitle => 'Základní barva';

  @override
  String get lightSettingsHeader => 'Světlo';

  @override
  String get lightSettingsSubtitle =>
      'Statické barvy a efekty na pásku bez snímání obrazovky. Výběr barvy může krátce rozsvítit náhled na pásku.';

  @override
  String get lightPrimaryColorTile => 'Základní barva';

  @override
  String lightPrimaryColorRgbHint(Object rgb) {
    return 'RGB($rgb) · klepnutím výběr jako Home / Hue';
  }

  @override
  String get fieldEffect => 'Efekt';

  @override
  String lightSpeedValue(Object v) {
    return 'Rychlost: $v';
  }

  @override
  String lightExtraValue(Object v) {
    return 'Extra: $v';
  }

  @override
  String lightBrightnessValue(Object v) {
    return 'Jas: $v';
  }

  @override
  String lightSmoothingMs(Object v) {
    return 'Plynulost barev (ms): $v';
  }

  @override
  String get lightSmoothingHint =>
      'Vyhlazuje barvy light režimu mezi snímky (0 = okamžitě). Stejný princip jako interpolace obrazovky.';

  @override
  String get lightHomekitTile => 'HomeKit (FW / MQTT — neposílat barvy z PC)';

  @override
  String get lightHomekitSubtitle => 'homekit_enabled';

  @override
  String get lightCustomZonesTitle => 'Vlastní zóny';

  @override
  String get lightAddZone => 'Přidat zónu';

  @override
  String lightZoneDefaultName(Object n) {
    return 'Zóna $n';
  }

  @override
  String get fieldZoneName => 'Název';

  @override
  String get fieldStartPercent => 'Start %';

  @override
  String get fieldEndPercent => 'Konec %';

  @override
  String get fieldZoneEffect => 'Efekt zóny';

  @override
  String lightZoneSpeedValue(Object v) {
    return 'Rychlost zóny: $v';
  }

  @override
  String get lightRemoveZone => 'Odebrat zónu';

  @override
  String get lightEffectStatic => 'Statická';

  @override
  String get lightEffectBreathing => 'Dýchání';

  @override
  String get lightEffectRainbow => 'Duha';

  @override
  String get lightEffectChase => 'Honění';

  @override
  String get lightEffectCustomZones => 'Vlastní zóny';

  @override
  String get lightZoneEffectPulse => 'Puls';

  @override
  String get lightZoneEffectBlink => 'Blikání';

  @override
  String musicDeviceError(Object error) {
    return 'Zařízení: $error';
  }

  @override
  String get musicInputDeviceLabel => 'Vstupní zvukové zařízení';

  @override
  String get musicDefaultInputDevice =>
      'Automaticky: mix ze systému (loopback)';

  @override
  String get musicSystemLoopbackHint =>
      'Bez vybraného zařízení a s vypnutým „Preferovat mikrofon“ jde vizualizovat zvuk ze systému. Na Windows 10+ aplikace použije WASAPI loopback na výchozím přehrávacím zařízení (prohlížeč, hry, Spotify — ne nutně fyzický mikrofon). Ze seznamu lze dál zvolit Stereo Mix, VB-Audio Cable apod. macOS: BlackHole (existential.audio/blackhole), Multi-Output Device v Audio MIDI Setup, pak vstup „BlackHole“ nebo Aggregate.';

  @override
  String get musicRefreshDeviceListTooltip => 'Obnovit seznam';

  @override
  String get musicSettingsHeader => 'Hudba';

  @override
  String get musicSettingsSubtitle =>
      'Zdroj zvuku, efekty a náhled barev. Režim Hudba na přehledu musí být aktivní, aby se výstup promítl na pásky.';

  @override
  String get musicGuideMusicArtwork => 'Nápověda: hudba a obaly';

  @override
  String get musicLockPaletteTitle => 'Zamknout výstup barev na pásek (hudba)';

  @override
  String get musicLockPaletteFrozen =>
      'Posílá se zmrazená paleta (stejné jako položka v tray).';

  @override
  String get musicLockPalettePending =>
      'Čeká na další snímek, pak se paleta zmrazí.';

  @override
  String get musicLockPaletteIdle =>
      'Jen v music módu má smysl; přepnutím režimu se zámek zruší.';

  @override
  String get musicPreferMicTitle => 'Preferovat mikrofon';

  @override
  String get musicPreferMicSubtitle =>
      'Pokud není vybráno zařízení, hledá se vhodný vstup mimo smyčku reproduktorů.';

  @override
  String get musicColorSourceLabel => 'Zdroj barev';

  @override
  String get musicColorSourceFixed => 'Pevná barva';

  @override
  String get musicColorSourceSpectrum => 'Spektrum zvuku';

  @override
  String get musicColorSourceMonitor => 'Barvy z monitoru (Ambilight)';

  @override
  String get musicFixedColorHeader => 'Barva při pevné barvě';

  @override
  String get musicFixedColorHint =>
      'Barvu vybírej jako v Home / Hue — náhled na pásku při úpravě.';

  @override
  String get musicVisualEffectLabel => 'Vizuální efekt';

  @override
  String get musicSmartMusicHint =>
      'Smart Music: spektrum, beat a melodie se mapují na pásek v reálném čase (lokálně, bez cloudu).';

  @override
  String musicBrightnessValue(Object v) {
    return 'Jas (music): $v';
  }

  @override
  String get musicBeatDetection => 'Detekce beatu';

  @override
  String musicBeatThreshold(Object v) {
    return 'Prah detekce beatu: $v';
  }

  @override
  String musicOverallSensitivity(Object v) {
    return 'Celková citlivost: $v';
  }

  @override
  String get musicBandSensitivityCaption =>
      'Citlivost pásem (bas / středy / výšky / celkově)';

  @override
  String musicBassValue(Object v) {
    return 'Bass: $v';
  }

  @override
  String musicMidValue(Object v) {
    return 'Mid: $v';
  }

  @override
  String musicHighValue(Object v) {
    return 'High: $v';
  }

  @override
  String musicGlobalValue(Object v) {
    return 'Global: $v';
  }

  @override
  String get musicAutoGainTitle => 'Automatické zesílení';

  @override
  String get musicAutoGainSubtitle =>
      'Vyrovná hlasitost vstupu podle dynamiky skladby.';

  @override
  String get musicAutoMidTitle => 'Auto středy';

  @override
  String get musicAutoHighTitle => 'Auto výšky';

  @override
  String musicSmoothingMs(Object v) {
    return 'Vyhlazení v čase: $v ms';
  }

  @override
  String musicMinBrightnessValue(Object v) {
    return 'min_brightness (music): $v';
  }

  @override
  String musicRotationSpeedValue(Object v) {
    return 'rotation_speed: $v';
  }

  @override
  String get musicActivePresetField => 'active_preset';

  @override
  String get musicFixedColorPickerTitle => 'Pevná barva (hudba)';

  @override
  String get musicEditColorButton => 'Upravit barvu';

  @override
  String musicRgbTriple(Object r, Object g, Object b) {
    return 'RGB $r · $g · $b';
  }

  @override
  String get musicEffectSmartMusic => 'Chytrá hudba';

  @override
  String get musicEffectEnergy => 'Energie';

  @override
  String get musicEffectSpectrum => 'Spektrum';

  @override
  String get musicEffectSpectrumRotate => 'Rotující spektrum';

  @override
  String get musicEffectSpectrumPunchy => 'Spektrum (výrazné)';

  @override
  String get musicEffectStrobe => 'Stroboskop';

  @override
  String get musicEffectVuMeter => 'VU měřič';

  @override
  String get musicEffectVuSpectrum => 'VU + spektrum';

  @override
  String get musicEffectPulse => 'Pulz';

  @override
  String get musicEffectReactiveBass => 'Reaktivní basy';

  @override
  String get devicesTabHeader => 'Zařízení';

  @override
  String get devicesTabIntro =>
      'Název a počet LED jsou důležité pro ovládání. IP a port jsou v sekci Připojení.';

  @override
  String get devicesTabEmptyHint =>
      'Seznam může zůstat prázdný — vhodné jen pro přípravu profilů. Pro výstup na pásek přidej aspoš jedno zařízení.';

  @override
  String get devicesAddDevice => 'Přidat zařízení';

  @override
  String get devicesNewDeviceName => 'Nové zařízení';

  @override
  String devicesUnnamedDevice(Object index) {
    return 'Zařízení $index';
  }

  @override
  String get devicesRemoveTooltip => 'Odebrat zařízení';

  @override
  String get fieldDisplayName => 'Zobrazovaný název';

  @override
  String get fieldConnectionType => 'Typ připojení';

  @override
  String get devicesTypeUsb => 'USB (sériový port)';

  @override
  String get devicesTypeWifi => 'Wi‑Fi (UDP)';

  @override
  String get devicesControlViaHa => 'Ovládat přes Home Assistant';

  @override
  String get devicesControlViaHaSubtitle =>
      'PC nebude na toto zařízení posílat barvy.';

  @override
  String get devicesConnectionSection => 'Připojení a interní údaje';

  @override
  String get devicesWifiIpMissing => 'Doplň IP adresu kontroléru';

  @override
  String get devicesWifiSaved => 'Síťové údaje uloženy (uprav v rozbalení)';

  @override
  String get devicesSerialPortMissing =>
      'Zadej COM port nebo vyber z detekovaných';

  @override
  String devicesPortSummary(Object port) {
    return 'Port $port';
  }

  @override
  String get fieldComPort => 'COM port';

  @override
  String devicesComHintExample(Object example) {
    return 'např. $example';
  }

  @override
  String devicesComDetectedHelper(Object ports) {
    return 'Detekované: $ports — klepnutím níže rychle vyplníš';
  }

  @override
  String get fieldControllerIp => 'IP adresa kontroléru';

  @override
  String get fieldInternalId => 'Interní ID (odkazy v konfiguraci)';

  @override
  String get helperInternalId =>
      'Měň jen pokud víš, že segmenty v JSON na to odkazují.';

  @override
  String get scanOverlayTitle => 'Náhled skenu (D-detail)';

  @override
  String scanOverlayIntro(Object seconds) {
    return 'Zvýrazněné jsou jen pruhy skutečné oblasti snímání (střed okna zůstává čistý). Poměr odpovídá zvolenému monitoru; okno aplikace se nemění na fullscreen. Po puštění slideru náhled zmizí za $seconds s. Tlačítkem níže náhled na chvíli zobrazíš i bez posunu slideru. Chip vpravo nahoře nebo Escape zavře.';
  }

  @override
  String get scanPreviewMonitorTitle => 'Náhled zón na monitor při ladění';

  @override
  String get scanPreviewOff => 'Vypnuto';

  @override
  String scanPreviewVisible(Object seconds) {
    return 'Vidět náhled; po puštění skrytí za $seconds s';
  }

  @override
  String get scanPreviewOnDragging =>
      'Zapnuto — náhled při tažení sliderů (oblast snímání)';

  @override
  String get fieldMonitorMssSameAsCapture =>
      'Monitor (MSS index, shodně s capture)';

  @override
  String scanMonitorNoEnum(Object index) {
    return 'Monitor $index (bez enumerace OS)';
  }

  @override
  String get scanPreviewNowButton => 'Ukázat náhled zón teď (~1 s)';

  @override
  String get scanDepthPerEdge => 'Hloubka snímání % (per-edge)';

  @override
  String get scanPaddingPerEdge => 'Odsazení % (per-edge)';

  @override
  String get scanEdgeTop => 'Horní';

  @override
  String get scanEdgeBottom => 'Spodní';

  @override
  String get scanEdgeLeft => 'Levá';

  @override
  String get scanEdgeRight => 'Pravá';

  @override
  String get scanPadLeft => 'Levé';

  @override
  String get scanPadRight => 'Pravé';

  @override
  String scanPctLabel(Object label, Object pct) {
    return '$label: $pct %';
  }

  @override
  String get scanSimpleModeHint =>
      'Jednotná hloubka a odsazení nastavíš výše v sekci „Oblast snímání“. Pro samostatné hrany zapni rozšířený režim obrazovky.';

  @override
  String get scanDiagramTitle => 'Schéma oblasti (poměr zvoleného monitoru)';

  @override
  String get scanThumbNeedScreenMode =>
      'Zapni režim Obrazovka pro živý náhled.';

  @override
  String get scanThumbWaiting => 'Čekám na snímek…';

  @override
  String get removeDeviceDialogTitle => 'Odebrat zařízení?';

  @override
  String get removeDeviceDialogLastBody =>
      'Seznam zařízení může zůstat prázdný — není to chyba. Bez zařízení jen nejde posílat barvy na pásek; můžeš dál nastavovat režimy a presety. Až hardware připojíš, přidej ho znovu tady nebo přes Discovery.';

  @override
  String removeDeviceDialogNamedBody(Object name) {
    return 'Zařízení „$name“ se odebere z konfiguraci.';
  }

  @override
  String get deviceDetailsTitle => 'Technické údaje';

  @override
  String detailLineInternalId(Object id) {
    return 'Interní ID: $id';
  }

  @override
  String detailLineType(Object type) {
    return 'Typ: $type';
  }

  @override
  String detailLineLedCount(Object count) {
    return 'Počet LED: $count';
  }

  @override
  String detailLineIp(Object ip) {
    return 'IP: $ip';
  }

  @override
  String detailLineUdpPort(Object port) {
    return 'UDP port: $port';
  }

  @override
  String detailLineSerialPort(Object port) {
    return 'Port: $port';
  }

  @override
  String detailLineFirmware(Object version) {
    return 'Firmware: $version';
  }

  @override
  String get deviceConnectionOkLabel => 'Spojení OK';

  @override
  String get deviceConnectionOfflineLabel => 'Nepřipojeno';

  @override
  String get deviceHaControlledNote =>
      'Ovládání přes Home Assistant — barvy z PC se na toto zařízení neposílají.';

  @override
  String get menuMoreActions => 'Další akce';

  @override
  String get menuEditLedMapping => 'Upravit mapování LED';

  @override
  String get menuTechnicalDetailsEllipsis => 'Technické údaje…';

  @override
  String get menuIdentifyBlink => 'Krátce identifikovat (bliknutí)';

  @override
  String get menuRefreshFirmwareInfo => 'Obnovit údaj o firmwaru';

  @override
  String get menuResetSavedWifi => 'Reset uložené Wi‑Fi na kontroléru';

  @override
  String get menuRemoveDeviceEllipsis => 'Odebrat zařízení…';

  @override
  String deviceSubtitleUsbLed(Object count) {
    return 'USB · $count LED';
  }

  @override
  String deviceSubtitleWifiLed(Object count) {
    return 'Wi‑Fi · $count LED';
  }

  @override
  String get onboardingUsbSerialLabel => 'USB / sériový';

  @override
  String get onboardingUdpWifiLabel => 'UDP / Wi‑Fi';

  @override
  String get colorPickerHue => 'Odstín';

  @override
  String get colorPickerSaturationValue => 'Sytost a jas';

  @override
  String get colorPickerPresets => 'Předvolby';

  @override
  String get colorPickerDefaultTitle => 'Barva';

  @override
  String get guideMusicColorsTitle => 'Hudba a barvy z obalu';

  @override
  String get guideCloseTooltip => 'Zavřít';

  @override
  String get guideBrowserOpenFailed => 'Otevření prohlížeče se nezdařilo.';

  @override
  String get guideNeedSpotifyClientId =>
      'Nejdřív v Nastavení → Spotify zadej Client ID (viz tlačítko výše).';

  @override
  String get guideOpenSpotifyDeveloper => 'Otevřít Spotify Developer';

  @override
  String get guideSignInSpotifyBrowser => 'Přihlásit Spotify v prohlížeči';

  @override
  String get guideIntroBlurb =>
      'Stručně: v režimu Hudba jde o zvuk z PC (efekty) a volitelně jedna barva z obalu skladby.';

  @override
  String get guideCard1Title => '1 · Režim a zvuk';

  @override
  String get guideCard1Body =>
      'Na přehledu zapni dlaždici „Hudba“. V Nastavení → Hudba vyber vstup (Stereo Mix, mikrofon, …) a v systému povol nahrávání zvuku pro AmbiLight.';

  @override
  String get guideCard2Title => '2 · Barva z obalu';

  @override
  String get guideCard2Body =>
      'Buď Spotify (níže), nebo na Windows sekce „OS médium“ v Nastavení → Spotify (Apple Music apod. přes systém). Když je obal zapnutý, má přednost před „tančícími“ efekty z FFT.';

  @override
  String get guideCard3Title => '3 · Spotify';

  @override
  String get guideCard3Body =>
      'Potřebuješ Client ID z vývojářské konzole a v konzoli redirect http://127.0.0.1:8767/callback. Tlačítkem níže otevřeš web — přihlášení k účtu Spotify pak spustí prohlížeč stejně jako „Přihlásit“ na přehledu.';

  @override
  String get guideCard4Title => '4 · Apple Music';

  @override
  String get guideCard4Body =>
      'Žádné tlačítko „přihlásit Apple Music ve webu“ zde nepřidáme: Apple nemá pro tuto desktopovou aplikaci stejné otevřené OAuth jako Spotify. Na Windows zapni „OS médium“, pusť Apple Music (aplikace) a hraj — barva se bere z miniatury, kterou systém sdílí (když ji hráč pošle).';

  @override
  String get guideCard5Title => 'Když něco nejde';

  @override
  String get guideCard5Body =>
      'Spotify chyba po přihlášení → zkus znovu Přihlásit. Žádný zvuk v efektech → špatný vstup nebo oprávnění. Pořád jen FFT → vypnutá integrace obalu nebo nic nehraje / chybí miniatura.';

  @override
  String get spotifySectionTitle => 'Spotify';

  @override
  String get spotifyOAuthNote =>
      'OAuth tokény se do disku ukládají přes ConfigRepository sanitizovaně; plný tok a tlačítka „Přihlásit“ přidá agent A5.';

  @override
  String get spotifyIntegrationEnabledTile => 'Spotify integrace zapnutá';

  @override
  String get spotifyAlbumColorsApi => 'Barvy z alba (Spotify API)';

  @override
  String get spotifyClientSecretHintStored =>
      'Ponechte prázdné = beze změny; smažte v A5 nebo zadejte nový';

  @override
  String get spotifyClientSecretHintOptional => 'Volitelné';

  @override
  String get spotifyClearSecretButton => 'Smazat client secret z draftu';

  @override
  String get spotifyAccessTokenTile => 'Access token';

  @override
  String get spotifyRefreshTokenTile => 'Refresh token';

  @override
  String get spotifyTokenSet => 'Nastaven (skryto)';

  @override
  String get spotifyOsMediaSection => 'Apple Music / YouTube Music (OS)';

  @override
  String get spotifyOsMediaBodyWin =>
      'Na Windows čteme náhled obalu z aktuálního systémového přehrávače (GSMTC). Funguje typicky pro aplikaci Apple Music a často pro YouTube Music v Edge nebo Chrome — záleží, zda prohlížeč nebo hráč miniaturu do systému pošle. Oficiální API YouTube Music zde není.';

  @override
  String get spotifyOsMediaBodyOther =>
      'Na tomto OS zatím jen Spotify (OAuth). GSMTC / systémový náhled je implementovaný pro Windows.';

  @override
  String get spotifyOsAlbumColorGsmtc => 'Barva z obalu přes OS média (GSMTC)';

  @override
  String get spotifyOsAlbumColorUnavailable =>
      'Barva z obalu přes OS média (nedostupné)';

  @override
  String get spotifyOsAlbumColorSubtitle =>
      'Použije se v music módu, pokud Spotify neposkytne barvu nebo je vypnuté.';

  @override
  String get spotifyOsDominantThumbnail =>
      'Použít dominantní barvu z miniatury OS';

  @override
  String get discWizardTitle => 'Discovery (D9)';

  @override
  String get discDone => 'Hotovo';

  @override
  String get discScanning => 'Skenuji…';

  @override
  String get discScanAgain => 'Znovu skenovat';

  @override
  String get discIntro =>
      'Broadcast DISCOVER_ESP32 na port 4210. Identify pošle krátké zvýraznění na strip.';

  @override
  String get discNoDevicesSnack => 'Žádné zařízení neodpovědělo (UDP 4210).';

  @override
  String get discEmptyAfterScan => 'Žádná zařízení. Zkontroluj síť a FW.';

  @override
  String discAddedSnack(Object name) {
    return 'Přidáno: $name';
  }

  @override
  String get discResetWifiTitle => 'Reset Wi‑Fi?';

  @override
  String discResetWifiBody(Object name, Object ip) {
    return 'Zařízení „$name“ ($ip) smaže uložené Wi‑Fi přihlašovací údaje a restartuje se. Budete ho muset znovu nakonfigurovat.';
  }

  @override
  String get discSendResetWifi => 'Odeslat RESET_WIFI';

  @override
  String get discResetWifiSnackOk => 'RESET_WIFI odeslán.';

  @override
  String get discResetWifiSnackFail => 'Odeslání se nezdařilo.';

  @override
  String get discAddButton => 'Přidat';

  @override
  String get discResetWifiTooltip =>
      'Reset Wi‑Fi (smaže uložené přihlašovací údaje)';

  @override
  String get discIdentifyTooltip => 'Identifikovat';

  @override
  String discListItemSubtitle(Object ip, int ledCount, Object version) {
    return '$ip · $ledCount LED · FW $version';
  }

  @override
  String zoneEditorSavedSegments(Object count) {
    return 'Uloženo $count segmentů.';
  }

  @override
  String get zoneEditorEmpty =>
      'Žádné segmenty — použij průvodce LED nebo „Přidat segment“.';

  @override
  String zoneEditorSegmentLine(
      Object index, Object edge, Object start, Object end, Object mon) {
    return 'Segment $index · $edge · LED $start–$end · mon $mon';
  }

  @override
  String get zoneEditorDeleteTooltip => 'Smazat';

  @override
  String zoneFieldLedStart(int value) {
    return 'Začátek LED: $value';
  }

  @override
  String zoneFieldLedEnd(int value) {
    return 'Konec LED: $value';
  }

  @override
  String zoneFieldMonitorIndex(int value) {
    return 'Index monitoru: $value';
  }

  @override
  String get zoneFieldEdge => 'Hrana';

  @override
  String zoneFieldDepthScan(int value) {
    return 'Hloubka skenu: $value';
  }

  @override
  String get zoneFieldReverse => 'Obrátit směr';

  @override
  String get zoneFieldDeviceId => 'Zařízení';

  @override
  String zoneFieldPixelStart(int value) {
    return 'Začátek pixelu: $value';
  }

  @override
  String zoneFieldPixelEnd(int value) {
    return 'Konec pixelu: $value';
  }

  @override
  String zoneFieldRefWidth(int value) {
    return 'Referenční šířka: $value';
  }

  @override
  String zoneFieldRefHeight(int value) {
    return 'Referenční výška: $value';
  }

  @override
  String get zoneFieldMusicEffect => 'Efekt hudby';

  @override
  String get zoneFieldRole => 'Frekvenční pásmo';

  @override
  String get zoneEdgeTop => 'Nahoře';

  @override
  String get zoneEdgeBottom => 'Dole';

  @override
  String get zoneEdgeLeft => 'Vlevo';

  @override
  String get zoneEdgeRight => 'Vpravo';

  @override
  String get zoneMusicEffectDefault => 'Výchozí';

  @override
  String get zoneMusicEffectSmartMusic => 'Chytrá hudba';

  @override
  String get zoneMusicEffectEnergy => 'Energie';

  @override
  String get zoneMusicEffectSpectrum => 'Spektrum';

  @override
  String get zoneMusicEffectSpectrumRotate => 'Rotující spektrum';

  @override
  String get zoneMusicEffectSpectrumPunchy => 'Spektrum (výrazné)';

  @override
  String get zoneMusicEffectStrobe => 'Stroboskop';

  @override
  String get zoneMusicEffectVumeter => 'VU měřič';

  @override
  String get zoneMusicEffectVumeterSpectrum => 'VU + spektrum';

  @override
  String get zoneMusicEffectPulse => 'Puls';

  @override
  String get zoneMusicEffectReactiveBass => 'Reaktivní basy';

  @override
  String get zoneRoleAuto => 'Auto';

  @override
  String get zoneRoleBass => 'Bas';

  @override
  String get zoneRoleMids => 'Středy';

  @override
  String get zoneRoleHighs => 'Výšky';

  @override
  String get zoneRoleAmbience => 'Prostor';

  @override
  String get zoneDeviceAllDefault => '— všechna / výchozí —';

  @override
  String get zoneRefFromCapture => 'Ref. rozměry z posledního snímku';

  @override
  String get calibWizardTitle => 'Kalibrace obrazovky (D12)';

  @override
  String get calibWizardIntro =>
      'Profily jsou v `screen_mode.calibration_profiles` (JSON). Plný wizard křivek a náhled — D-detail / A3.';

  @override
  String get calibNoProfiles => 'Žádné profily v configu.';

  @override
  String get calibActiveProfileLabel => 'Aktivní kalibrační profil';

  @override
  String get calibSaveChoice => 'Uložit výběr';

  @override
  String calibActiveProfileSnack(Object name) {
    return 'Aktivní profil: $name';
  }

  @override
  String get configProfileIntro =>
      'Soubor profilu (`default.json` / jiný) řeší ConfigRepository; zde jen snapshot aktuálního screen módu do JSON pole user_screen_presets.';

  @override
  String get configProfileNameLabel => 'Název presetu';

  @override
  String get configProfileExistingTitle => 'Existující presety:';

  @override
  String configProfileSavedSnack(Object name) {
    return 'Preset „$name“ uložen do user_screen_presets.';
  }

  @override
  String get defaultPresetNameDraft => 'Můj preset';

  @override
  String get ledWizTitle => 'Průvodce LED';

  @override
  String ledWizTitleWithDevice(Object name) {
    return 'Průvodce LED — $name';
  }

  @override
  String ledWizMonitorLocked(Object idx) {
    return 'Monitor: $idx (zámek)';
  }

  @override
  String get ledWizAppendBadge => 'Režim: přidat segmenty';

  @override
  String ledWizStepProgress(Object current, Object total) {
    return 'Krok $current / $total';
  }

  @override
  String get ledWizAddDeviceFirst =>
      'Nejdřív přidejte zařízení (Discovery nebo ručně).';

  @override
  String get ledWizDeviceLabel => 'Zařízení';

  @override
  String get ledWizStripSides => 'Strany pásku';

  @override
  String get ledWizRefMonitorLabel => 'Referenční monitor (nativní seznam)';

  @override
  String ledWizMonitorLine(Object idx, Object w, Object h, Object suffix) {
    return 'Monitor $idx — $w×$h$suffix';
  }

  @override
  String get ledWizPrimarySuffix => ' · primární';

  @override
  String get ledWizMonitorManualLabel =>
      'Index monitoru (MSS, ručně — seznam nedostupný)';

  @override
  String get ledWizAppendSegmentsTitle =>
      'Přidat k existujícím segmentům (multi-monitor)';

  @override
  String get ledWizAppendSegmentsSubtitle =>
      'Jinak se smažou segmenty jen tohoto zařízení.';

  @override
  String ledWizLedIndexSlider(Object n) {
    return 'LED index $n';
  }

  @override
  String ledWizLedIndexRow(Object n) {
    return 'Index LED: $n';
  }

  @override
  String get ledWizFinishBody => 'Segmenty se dopočítají z uložených indexů.';

  @override
  String get ledWizStartCalibration => 'Spustit kalibraci';

  @override
  String get ledWizPickOneSideSnack => 'Vyberte alespoň jednu stranu.';

  @override
  String get ledWizSummary => 'Shrnutí';

  @override
  String get ledWizNext => 'Další';

  @override
  String get ledWizSaveClose => 'Uložit a zavřít';

  @override
  String ledWizSavedSnack(Object segments, Object led, Object mon) {
    return 'Uloženo $segments segmentů, LED $led, monitor $mon.';
  }

  @override
  String get ledWizConfigTitle => 'Konfigurace';

  @override
  String get ledWizConfigBody =>
      'V Nastavení → Zařízení nastav „Počet LED“ alespoň na horní odhad délky pásku (max. 2000). Před kalibrací aplikace pošle na ESP USB příkaz s tímto počtem. Pak vyber strany a monitor — u každého bodu posuneš zelenou LED na fyzické místo.';

  @override
  String get ledWizFinishTitle => 'Hotovo';

  @override
  String get ledWizLeftStartTitle => 'Levá strana — začátek';

  @override
  String get ledWizLeftStartBody =>
      'Posuňte posuvník tak, aby zelená LED byla na začátku levé strany (obvykle dole).';

  @override
  String get ledWizLeftEndTitle => 'Levá strana — konec';

  @override
  String get ledWizLeftEndBody =>
      'Posuňte posuvník tak, aby zelená LED byla na konci levé strany (obvykle nahoře).';

  @override
  String get ledWizTopStartTitle => 'Horní strana — začátek';

  @override
  String get ledWizTopStartBody =>
      'Posuňte posuvník tak, aby zelená LED byla na začátku horní hrany (vlevo).';

  @override
  String get ledWizTopEndTitle => 'Horní strana — konec';

  @override
  String get ledWizTopEndBody =>
      'Posuňte posuvník tak, aby zelená LED byla na konci horní hrany (vpravo).';

  @override
  String get ledWizRightStartTitle => 'Pravá strana — začátek';

  @override
  String get ledWizRightStartBody =>
      'Posuňte posuvník tak, aby zelená LED byla na začátku pravé strany (nahoře).';

  @override
  String get ledWizRightEndTitle => 'Pravá strana — konec';

  @override
  String get ledWizRightEndBody =>
      'Posuňte posuvník tak, aby zelená LED byla na konci pravé strany (dole).';

  @override
  String get ledWizBottomStartTitle => 'Spodní strana — začátek';

  @override
  String get ledWizBottomStartBody =>
      'Posuňte posuvník tak, aby zelená LED byla na začátku spodní hrany (vpravo).';

  @override
  String get ledWizBottomEndTitle => 'Spodní strana — konec';

  @override
  String get ledWizBottomEndBody =>
      'Posuňte posuvník tak, aby zelená LED byla na konci spodní hrany (vlevo).';

  @override
  String get fwTitle => 'Firmware ESP';

  @override
  String get fwIntro =>
      'CI build z repa může publikovat manifest na GitHub Pages. Zde načteš manifest, stáhneš .bin a flashneš přes USB (vyžaduje esptool v PATH) nebo spustíš OTA přes Wi‑Fi (UDP příkaz z firmware). Přechod na tabulku s dvěma OTA oddíly vyžaduje jednou úplný flash přes USB.';

  @override
  String get fwManifestUrlLabel => 'URL manifestu (GitHub Pages)';

  @override
  String get fwManifestUrlHint =>
      'https://alfredkrutina.github.io/ambilight/firmware/latest/';

  @override
  String get fwManifestHelper =>
      'Výchozí z globálního nastavení; bez souboru doplníme /manifest.json';

  @override
  String get fwLoadManifest => 'Načíst manifest';

  @override
  String get fwDownloadBins => 'Stáhnout binárky';

  @override
  String fwVersionChipLine(Object version, Object chip) {
    return 'Verze: $version · čip: $chip';
  }

  @override
  String fwPartBullet(Object file, Object offset) {
    return '• $file @ $offset';
  }

  @override
  String fwOtaUrlLine(Object url) {
    return 'OTA URL: $url';
  }

  @override
  String get fwFlashUsbTitle => 'Flash přes USB (COM)';

  @override
  String get fwRefreshPortsTooltip => 'Obnovit seznam portů';

  @override
  String fwSerialPortsError(Object error) {
    return 'Sériové porty nelze načíst: $error';
  }

  @override
  String get fwSerialPortLabel => 'Sériový port';

  @override
  String get fwNoComHintDriver => 'Zkuste „Obnovit“ nebo oprávnění / ovladač.';

  @override
  String get fwNoComEmpty => 'Žádný COM — připoj ESP USB';

  @override
  String get fwFlashEsptool => 'Flashovat přes esptool';

  @override
  String get fwOtaUdpTitle => 'OTA přes Wi‑Fi (UDP)';

  @override
  String get fwDeviceIpLabel => 'IP zařízení';

  @override
  String get fwOtaHintNeedManifest =>
      'Nejdřív výše načti manifest — bez něj není známá HTTPS URL pro OTA_HTTP.';

  @override
  String get fwOtaHintMissingUrl =>
      'V manifestu chybí OTA URL — dopiš root pole ota_http_url nebo parts s URL na aplikační .bin.';

  @override
  String fwOtaHintWillUse(Object url) {
    return 'Pro OTA se použije: $url';
  }

  @override
  String get fwVerifyUdpPong => 'Ověřit dosah (UDP PONG)';

  @override
  String get fwSendOtaHttp => 'Odeslat OTA_HTTP';

  @override
  String get fwStatusCacheFail => 'Nelze založit cache (path_provider).';

  @override
  String get fwStatusEnterManifestUrl =>
      'Zadej URL manifestu (např. …/firmware/latest/).';

  @override
  String get fwStatusLoadingManifest => 'Načítám manifest…';

  @override
  String fwStatusManifestOk(Object version, Object chip, Object count) {
    return 'Manifest OK — verze $version, čip $chip, $count souborů.';
  }

  @override
  String fwStatusManifestError(Object error) {
    return 'Chyba manifestu: $error';
  }

  @override
  String get fwStatusDownloading => 'Stahuji…';

  @override
  String fwStatusDownloadedTo(Object path) {
    return 'Staženo do: $path';
  }

  @override
  String fwStatusDownloadFailed(Object error) {
    return 'Stažení selhalo: $error';
  }

  @override
  String get fwStatusPickCom => 'Vyber COM / sériový port.';

  @override
  String get fwStatusDownloadBinsFirst =>
      'Nejdřív stáhni binárky (tlačítko výše).';

  @override
  String get fwStatusFlashing =>
      'Flashuji přes esptool… (vypni v aplikaci stream na stejný COM)';

  @override
  String fwStatusFlashOk(Object log) {
    return 'Flash OK.\\n$log';
  }

  @override
  String fwStatusFlashFail(Object log) {
    return 'Flash selhal.\\n$log';
  }

  @override
  String fwStatusException(Object error) {
    return 'Výjimka: $error';
  }

  @override
  String get fwStatusEnterIpProbe =>
      'Zadej IP zařízení pro ověření (UDP PONG).';

  @override
  String get fwStatusProbing => 'Ověřuji zařízení (UDP, max 2 s)…';

  @override
  String get fwStatusProbeTimeout =>
      'Zařízení neodpovědělo v čase — offline, špatná IP/port/firewall, nebo firmware bez DISCOVER odpovědi.';

  @override
  String fwStatusProbeOnline(Object name, Object led, Object version) {
    return 'Online: $name · LED $led · verze $version (ESP32_PONG).';
  }

  @override
  String get fwStatusNoOtaUrl =>
      'Manifest nemá použitelnou OTA URL (ota_http_url ani odvozený parts[].url).';

  @override
  String get fwStatusEnterIpEsp => 'Zadej IP ESP (Wi‑Fi).';

  @override
  String fwStatusSendingOta(Object ip, Object port) {
    return 'Odesílám OTA_HTTP na $ip:$port…';
  }

  @override
  String get fwStatusOtaSent =>
      'Příkaz odeslán. ESP stáhne firmware a restartuje se (kontroluj log / LED).';

  @override
  String get fwStatusUdpFailed => 'UDP se nepodařilo odeslat.';

  @override
  String get fwStatusOtaInvalidTarget => 'Neplatná IP zařízení.';

  @override
  String get fwStatusOtaUrlTooShort =>
      'OTA URL je příliš krátká (ve firmware musí mít alespoň 12 znaků).';

  @override
  String get fwStatusOtaUrlTooLong =>
      'OTA URL je příliš dlouhá pro zařízení (max. 1300 znaků).';

  @override
  String get fwStatusOtaInvalidChars =>
      'OTA URL obsahuje znaky, které zařízení odmítne (řídicí kódy atd.).';

  @override
  String get fwStatusOtaBadScheme =>
      'OTA URL musí začínat na https:// nebo http:// (stejné pravidlo jako ve firmware).';

  @override
  String get fwStatusOtaPayloadInvalid =>
      'Příkaz OTA neprojde kontrolou na straně zařízení.';

  @override
  String get fwFillFromDevices => 'Doplnit ze Zařízení';

  @override
  String get fwFillFromDevicesTooltip =>
      'Zkopíruje IP a UDP port z prvního Wi‑Fi zařízení v seznamu (záložka Zařízení).';

  @override
  String get fwDebugToolsTitle => 'Ladicí nástroje (lampa)';

  @override
  String get fwDebugReject88Body =>
      'Odmítnout DHCP adresy v 192.168.88.0/24 (3. oktet .88). Uloženo v lampě (NVS dbg_rej88). Stejný přepínač je na konfigurační stránce SoftAP a přes UDP DEBUG_REJ88 0|1|?.';

  @override
  String get fwDebugReject88Query => 'Dotázat lampu';

  @override
  String get fwDebugReject88Enable => 'Zapnout odmítání';

  @override
  String get fwDebugReject88Disable => 'Vypnout odmítání';

  @override
  String get fwDebugReject88Unknown =>
      'neznámé (bez odpovědi nebo starý firmware)';

  @override
  String get fwDebugReject88On => 'zapnuto';

  @override
  String get fwDebugReject88Off => 'vypnuto';

  @override
  String fwDebugReject88Current(String state) {
    return 'Na lampě: $state';
  }

  @override
  String get fwDebugReject88SetOk => 'Nastavení zapsáno (NVS v lampě).';

  @override
  String get fwDebugReject88SetFail =>
      'UDP příkaz selhal (offline, špatná IP/port nebo firmware bez DEBUG_REJ88).';

  @override
  String get fwStatusProbeRejectOn => ' · odmítnout 192.168.88.x: zapnuto';

  @override
  String get fwStatusProbeRejectOff => ' · odmítnout 192.168.88.x: vypnuto';

  @override
  String get fwStatusNoWifiDevice =>
      'V seznamu není Wi‑Fi zařízení s vyplněnou IP — přidej ho v záložce Zařízení.';

  @override
  String fwStatusFilledFromDevice(Object name, Object ip, Object port) {
    return 'Doplněno z „$name“: $ip:$port.';
  }

  @override
  String get pcHealthHeaderTitle => 'PC Health';

  @override
  String get pcHealthHeaderSubtitle =>
      'Barvy okrajů pásku podle systémových metrik. Na přehledu zvol režim PC Health, aby se výstup posílal na zařízení.';

  @override
  String get pcHealthHintWeb => 'Na webu se systémové metriky nečtou.';

  @override
  String get pcHealthHintMac =>
      'macOS: CPU zátěž je odhad z load average / počet jader; disk z df; síť ze součtu Ibytes v netstat. Teplotu CPU bez rozšíření typu powermetrics nelze v běžném účtu spolehlivě číst — může zůstat 0. NVIDIA GPU jen pokud je v PATH nástroj nvidia-smi.';

  @override
  String get pcHealthHintLinux =>
      'Linux: využití disku v metrice disk_usage zatím není v collectoru naplněné (0). Ostatní z /proc a tepelné zóny.';

  @override
  String get pcHealthHintWindows =>
      'Windows: disk první pevný disk; teplota CPU z ACPI WMI, pokud systém poskytuje data.';

  @override
  String get pcHealthEnabledTile => 'PC Health zapnuto';

  @override
  String pcHealthUpdateInterval(Object ms) {
    return 'Interval aktualizace: $ms ms';
  }

  @override
  String pcHealthGlobalBrightness(Object v) {
    return 'Globální jas: $v';
  }

  @override
  String get pcHealthLivePreviewTitle => 'Živý náhled hodnot';

  @override
  String get pcHealthNotTrackingHint =>
      'Aktivní režim není PC Health — zobrazuje se poslední snímek nebo ruční měření.';

  @override
  String get pcHealthMeasuring => 'Měřím…';

  @override
  String pcHealthMetricsTitle(Object count) {
    return 'Metriky ($count)';
  }

  @override
  String get pcHealthRestoreDefaults => 'Výchozí';

  @override
  String get pcHealthStagingDebug =>
      '[staging] PC Health: náhled + editor metrik';

  @override
  String get pcHealthDialogNew => 'Nová metrika';

  @override
  String get pcHealthDialogEdit => 'Upravit metriku';

  @override
  String get pcHealthTileEnabled => 'Zapnuto';

  @override
  String get pcHealthFieldName => 'Název';

  @override
  String get pcHealthFieldMetric => 'Metrika';

  @override
  String get pcHealthFieldMin => 'Min';

  @override
  String get pcHealthFieldMax => 'Max';

  @override
  String get pcHealthFieldColorScale => 'Barevná škála';

  @override
  String get pcHealthFieldBrightness => 'Jas';

  @override
  String pcHealthBrightnessValue(Object v) {
    return 'Jas: $v';
  }

  @override
  String pcHealthBrightnessMin(Object v) {
    return 'Jas min: $v';
  }

  @override
  String pcHealthBrightnessMax(Object v) {
    return 'Jas max: $v';
  }

  @override
  String get pcHealthMetricFallbackName => 'Metrika';

  @override
  String get pcHealthEditTooltip => 'Upravit';

  @override
  String get pcHealthDeleteTooltip => 'Smazat';

  @override
  String get pcMetricCpuUsage => 'CPU zátěž';

  @override
  String get pcMetricRamUsage => 'RAM';

  @override
  String get pcMetricNetUsage => 'Síť (odhad)';

  @override
  String get pcMetricCpuTemp => 'Teplota CPU';

  @override
  String get pcMetricGpuUsage => 'GPU zátěž';

  @override
  String get pcMetricGpuTemp => 'Teplota GPU';

  @override
  String get pcMetricDiskUsage => 'Disk';

  @override
  String get smartHomeTitle => 'Chytrá domácnost';

  @override
  String get smartHomeIntro =>
      'Home Assistant: přímé ovládání entit light.* přes REST. Apple Home (HomeKit): nativně na macOS. Google Home: žádné veřejné lokální API — použij propojení přes Home Assistant (viz níže).';

  @override
  String get smartPushColorsTile => 'Posílat barvy na chytrá světla';

  @override
  String get smartPushColorsSubtitle =>
      'Zapni až po nastavení HA / HomeKit fixture níže.';

  @override
  String get smartHaSection => 'Home Assistant';

  @override
  String get smartHaTokenHelper =>
      'Ukládá se mimo default.json (application support / ha_long_lived_token.txt).';

  @override
  String get smartHaTrustCertTile => 'Důvěřovat vlastnímu HTTPS certifikátu';

  @override
  String get smartHaTrustCertSubtitle => 'Jen lokální HA s self-signed certem.';

  @override
  String get smartTestConnection => 'Test spojení';

  @override
  String get smartAddHaLight => 'Přidat světlo z HA';

  @override
  String get smartHaFillUrlToken =>
      'Nejdřív nastav URL a token Home Assistant.';

  @override
  String get smartHaPickLightTitle => 'Přidat světlo z Home Assistant';

  @override
  String get smartMaxHzLabel => 'Max. Hz na světlo';

  @override
  String get smartBrightnessCapLabel => 'Strop jasu %';

  @override
  String get smartHomeKitSection => 'Apple Home (HomeKit)';

  @override
  String get smartHomeKitNonMac =>
      'Nativní HomeKit je jen na macOS. Na Windows/Linux přidej světla do Home Assistant (HomeKit Device / Matter bridge) a ovládej je přes HA výše.';

  @override
  String get smartHomeKitLoading => 'Načítám HomeKit…';

  @override
  String get smartHomeKitEmpty =>
      'Žádná HomeKit světla (nebo chybí oprávnění).';

  @override
  String smartHomeKitCount(Object count) {
    return '$count světel.';
  }

  @override
  String get smartRefreshHomeKit => 'Obnovit seznam HomeKit světel';

  @override
  String get smartGoogleSection => 'Google Home';

  @override
  String get smartGoogleBody =>
      'Google nepovoluje desktopové aplikaci přímo řídit „Google Home“ světla. Spolehlivá cesta: nainstaluj Home Assistant, přidej tam Hue / Nest / … a propoj HA s Google Assistant.';

  @override
  String get smartGoogleDocButton => 'Dokumentace: Google Assistant + HA';

  @override
  String get smartMyHaButton => 'My Home Assistant';

  @override
  String get smartVirtualRoomSection => 'Virtuální místnost';

  @override
  String get smartVirtualRoomIntro =>
      'Umísti TV, sebe a světla v plánku. Kužel ukazuje směr pohledu (relativně k ose k TV). Vlna mění jas podle vzdálenosti od TV a času — signály na HA/HomeKit jdou každý snímek přes stávající mapování barev.';

  @override
  String smartFixturesTitle(Object count) {
    return 'Nakonfigurovaná světla ($count)';
  }

  @override
  String get smartFixturesEmpty => 'Zatím žádná — přidej z HA nebo HomeKit.';

  @override
  String get smartFixtureRemoveTooltip => 'Odebrat';

  @override
  String smartFixtureHaLine(Object id) {
    return 'HA: $id';
  }

  @override
  String smartFixtureHkLine(Object id) {
    return 'HomeKit: $id';
  }

  @override
  String get smartBindingLabel => 'Mapování barvy';

  @override
  String get smartBindingGlobalMean => 'Průměr všech LED';

  @override
  String get smartBindingLedRange => 'Rozsah LED na zařízení';

  @override
  String get smartBindingScreenEdge => 'Hrana obrazovky';

  @override
  String get smartDeviceIdOptional => 'device_id (prázdné = první zařízení)';

  @override
  String get smartEdgeLabel => 'Hrana';

  @override
  String get smartMonitorIndexBinding => 'monitor_index (0=desktop, 1…)';

  @override
  String get smartHaStatusTesting => 'Testuji…';

  @override
  String smartHaStatusOk(Object msg) {
    return 'OK: $msg';
  }

  @override
  String smartHaStatusErr(Object msg) {
    return 'Chyba: $msg';
  }

  @override
  String get vrWaveTitle => 'Vlna přes místnost';

  @override
  String get vrWaveSubtitle =>
      'Modulace jasu podle vzdálenosti od TV a času snímku';

  @override
  String vrWaveStrength(Object pct) {
    return 'Síla vlny: $pct %';
  }

  @override
  String get vrWaveSpeed => 'Rychlost vlny';

  @override
  String get vrDistanceSensitivity => 'Citlivost na vzdálenost';

  @override
  String vrViewingAngle(Object deg) {
    return 'Úchyl pohledu od osy k TV: $deg°';
  }

  @override
  String get vrTooltipTv => 'TV (táhni)';

  @override
  String get vrTooltipYou => 'Ty (táhni)';

  @override
  String get deviceFwTemporalSectionTitle => 'Časové vyhlazování na lampě (FW)';

  @override
  String get deviceFwTemporalOff => 'Vypnuto';

  @override
  String get deviceFwTemporalSmooth => 'Plynulé';

  @override
  String get deviceFwTemporalSnap => 'Bez přidané latence';

  @override
  String get deviceFwTemporalApply => 'Odeslat na zařízení';

  @override
  String get deviceFwTemporalSnackOk => 'Režim vyhlazování na lampě uložen.';

  @override
  String get deviceFwTemporalSnackFail =>
      'Příkaz se nepodařilo potvrdit (timeout nebo starý FW).';

  @override
  String get deviceFwTemporalHint =>
      'Oddělené od interpolace obrazovky níže — ne kombinovat obě na maximum.';

  @override
  String get settingsPcSmoothingFootnote =>
      'Interpolace zde běží jen na PC před UDP/sérií. Velikost UDP chunků při buildu: dart-define AMBI_UDP_OPCODE06_CHUNK_PIXELS (viz UdpAmbilightProtocol).';

  @override
  String get settingsGlobalPcUdpChunkHint =>
      'Volitelné ladění při buildu: --dart-define=AMBI_UDP_OPCODE06_CHUNK_PIXELS=… (32–498) mění velikost datagramů 0x06 u dlouhého pásku.';
}
