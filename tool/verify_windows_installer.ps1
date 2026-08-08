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
$temporaryDirectory = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
  [System.IO.Path]::GetTempPath()
} else {
  $env:RUNNER_TEMP
}
$installDirectory = Join-Path $temporaryDirectory 'sendreq-installer-smoke-test'
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

function Write-VerificationPhase([string]$message) {
  Write-Host ("[{0:mm\:ss}] {1}" -f $stopwatch.Elapsed, $message)
}

function Get-RelativeFilePath([string]$root, [string]$path) {
  return $path.Substring($root.Length).TrimStart([char[]]'\')
}

if (Test-Path $installDirectory) {
  Remove-Item -Recurse -Force $installDirectory
}

# A real silent install verifies that the generated setup file can unpack the
# Flutter bundle without relying on a pre-existing application installation.
Write-VerificationPhase 'Installing setup executable.'
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

# Verify the complete payload layout and file sizes. Hashing every Flutter
# asset is expensive on hosted Windows runners because each read can trigger
# Defender scanning, so SHA-256 is limited to the executable, native DLLs,
# ICU data, and Flutter asset manifests.
Write-VerificationPhase 'Checking installed payload layout and sizes.'
$bundleFiles = @(Get-ChildItem -Path $bundle -File -Recurse)

$criticalRelativePaths = [System.Collections.Generic.HashSet[string]]::new(
  [System.StringComparer]::OrdinalIgnoreCase
)
foreach ($file in $bundleFiles) {
  $relativePath = Get-RelativeFilePath $bundle $file.FullName
  if (
    $relativePath -eq 'sendreq.exe' -or
    $relativePath -like '*.dll' -or
    $relativePath -in @(
      'data\icudtl.dat',
      'data\flutter_assets\AssetManifest.bin',
      'data\flutter_assets\AssetManifest.json'
    )
  ) {
    [void]$criticalRelativePaths.Add($relativePath)
  }
}

foreach ($file in $bundleFiles) {
  $relativePath = Get-RelativeFilePath $bundle $file.FullName
  $installedFile = Join-Path $installDirectory $relativePath
  if (-not (Test-Path $installedFile -PathType Leaf)) {
    throw "Installed bundle is missing '$relativePath'."
  }
  if ($file.Length -ne (Get-Item $installedFile).Length) {
    throw "Installed file '$relativePath' has a different size."
  }
}

Write-VerificationPhase "Hashing $($criticalRelativePaths.Count) critical installed files."
foreach ($relativePath in $criticalRelativePaths) {
  $sourceFile = Join-Path $bundle $relativePath
  $installedFile = Join-Path $installDirectory $relativePath
  if ((Get-FileHash $sourceFile).Hash -ne (Get-FileHash $installedFile).Hash) {
    throw "Installed file '$relativePath' differs from the release bundle."
  }
}

Write-VerificationPhase 'Launching installed application.'
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
Write-VerificationPhase 'Uninstalling setup executable.'
$uninstallProcess = Start-Process -FilePath $uninstaller -ArgumentList @(
  '/VERYSILENT',
  '/SUPPRESSMSGBOXES',
  '/NORESTART',
  '/SP-'
) -Wait -PassThru
if ($uninstallProcess.ExitCode -ne 0 -or (Test-Path $installedExecutable)) {
  throw 'Uninstall smoke test failed.'
}

Write-VerificationPhase 'Installer smoke test completed.'
