; Inno Setup 6 — AmbiLight Windows installer (64-bit).
; ISCC.exe /DMyAppVersion=1.0.4 /DMyAppSource="...\Release" /DMyAppOutput="...\out" ambilight_windows_setup.iss
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef MyAppSource
  #define MyAppSource "."
#endif
#ifndef MyAppOutput
  #define MyAppOutput "."
#endif

#define MyAppName "AmbiLight"
#define MyAppPublisher "AmbiLight"
#define MyAppExeName "ambilight_desktop.exe"

[Setup]
AppId={{B4E8F1A2-9C3D-5E6F-A081-92A3B4C5D6E7}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir={#MyAppOutput}
OutputBaseFilename=ambilight_desktop_windows_x64_setup
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyAppSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch AmbiLight"; Flags: nowait postinstall skipifsilent
