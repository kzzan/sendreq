[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Container })]
  [string]$BundleDirectory,

  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Leaf })]
  [string]$InstallerPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$bundle = (Resolve-Path $BundleDirectory).Path
$installer = (Resolve-Path $InstallerPath).Path
$installDirectory = Join-Path $env:LOCALAPPDATA 'sendreq-installer-smoke-test'

if (Test-Path $installDirectory) {
  Remove-Item -Recurse -Force $installDirectory
}

# A real silent install verifies that the generated setup file can unpack the
# Flutter bundle without relying on a pre-existing application installation.
$installProcess = Start-Process -FilePath $installer -ArgumentList @(
  '/VERYSILENT',
  '/SUPPRESSMSGBOXES',
  '/NORESTART',
  '/SP-',
  "/DIR=$installDirectory"
) -Wait -PassThru
if ($installProcess.ExitCode -ne 0) {
  throw "Installer exited with code $($installProcess.ExitCode)."
}

$installedExecutable = Join-Path $installDirectory 'sendreq.exe'
if (-not (Test-Path $installedExecutable -PathType Leaf)) {
  throw 'Installation completed but sendreq.exe is missing.'
}

# Every file in Flutter's release bundle must survive packaging unchanged.
Get-ChildItem -Path $bundle -File -Recurse | ForEach-Object {
  $relativePath = $_.FullName.Substring($bundle.Length).TrimStart([char[]]'\')
  $installedFile = Join-Path $installDirectory $relativePath
  if (-not (Test-Path $installedFile -PathType Leaf)) {
    throw "Installed bundle is missing '$relativePath'."
  }
  if ((Get-FileHash $_.FullName).Hash -ne (Get-FileHash $installedFile).Hash) {
    throw "Installed file '$relativePath' differs from the release bundle."
  }
}

$application = Start-Process -FilePath $installedExecutable -PassThru
Start-Sleep -Seconds 5
$application.Refresh()
if ($application.HasExited) {
  throw "Installed application exited immediately with code $($application.ExitCode)."
}
Stop-Process -Id $application.Id -Force
$application.WaitForExit()

$uninstaller = Join-Path $installDirectory 'unins000.exe'
if (-not (Test-Path $uninstaller -PathType Leaf)) {
  throw 'Installation did not include Inno Setup uninstaller.'
}
$uninstallProcess = Start-Process -FilePath $uninstaller -ArgumentList @(
  '/VERYSILENT',
  '/SUPPRESSMSGBOXES',
  '/NORESTART',
  '/SP-'
) -Wait -PassThru
if ($uninstallProcess.ExitCode -ne 0 -or (Test-Path $installedExecutable)) {
  throw 'Uninstall smoke test failed.'
}
