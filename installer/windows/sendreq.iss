; SourceDir and MyAppVersion are supplied by the packaging workflow.
#ifndef SourceDir
  #error SourceDir must point to the Flutter Windows release bundle.
#endif
#ifndef MyAppVersion
  #error MyAppVersion must be supplied by the packaging workflow.
#endif

[Setup]
AppId={{D8F725C4-8A38-4ED7-B2CE-0EBE70C511F2}
AppName=sendreq
AppVersion={#MyAppVersion}
AppPublisher=sendreq
DefaultDirName={autopf}\sendreq
DefaultGroupName=sendreq
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes
OutputBaseFilename=sendreq-{#MyAppVersion}-windows-x64-setup
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\sendreq.exe
CloseApplications=yes
RestartApplications=no

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\sendreq"; Filename: "{app}\sendreq.exe"
Name: "{autodesktop}\sendreq"; Filename: "{app}\sendreq.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"

[Run]
Filename: "{app}\sendreq.exe"; Description: "Launch sendreq"; Flags: nowait postinstall skipifsilent
