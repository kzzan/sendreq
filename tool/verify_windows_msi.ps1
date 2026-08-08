[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Container })]
  [string]$BundleDirectory,

  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Leaf })]
  [string]$MsiPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$bundle = (Resolve-Path $BundleDirectory).Path
$msi = (Resolve-Path $MsiPath).Path
$temporaryDirectory = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
  [System.IO.Path]::GetTempPath()
} else {
  $env:RUNNER_TEMP
}
$installDirectory = Join-Path $temporaryDirectory 'sendreq-msi-smoke-test'
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

# Passing the public INSTALLFOLDER property keeps the smoke test isolated from
# the system application directory while exercising the real MSI actions.
Write-VerificationPhase 'Installing MSI.'
$install = Start-Process msiexec.exe -ArgumentList @(
  '/i', $msi, '/qn', '/norestart', "INSTALLFOLDER=$installDirectory"
) -Wait -PassThru
if ($install.ExitCode -ne 0) {
  throw "MSI installation exited with code $($install.ExitCode)."
}

$installedExecutable = Join-Path $installDirectory 'sendreq.exe'
if (-not (Test-Path $installedExecutable -PathType Leaf)) {
  throw 'MSI installation completed but sendreq.exe is missing.'
}

# Check the complete payload layout and sizes. Full SHA-256 comparisons for
# every Flutter asset make the smoke test disproportionately slow on hosted
# Windows runners because Defender scans each read. Hash the executable,
# native libraries, and runtime manifests instead.
Write-VerificationPhase 'Checking installed payload layout and sizes.'
$bundleFiles = @(Get-ChildItem -Path $bundle -File -Recurse)
$installedFiles = @(Get-ChildItem -Path $installDirectory -File -Recurse)
if ($installedFiles.Count -ne $bundleFiles.Count) {
  throw "MSI installed $($installedFiles.Count) files; expected $($bundleFiles.Count)."
}

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
    throw "MSI installation is missing '$relativePath'."
  }
  if ($file.Length -ne (Get-Item $installedFile).Length) {
    throw "MSI installed file '$relativePath' has a different size."
  }
}

Write-VerificationPhase "Hashing $($criticalRelativePaths.Count) critical installed files."
foreach ($relativePath in $criticalRelativePaths) {
  $sourceFile = Join-Path $bundle $relativePath
  $installedFile = Join-Path $installDirectory $relativePath
  if ((Get-FileHash $sourceFile).Hash -ne (Get-FileHash $installedFile).Hash) {
    throw "MSI installed file '$relativePath' differs from the release bundle."
  }
}

Write-VerificationPhase 'Launching installed application.'
$application = Start-Process -FilePath $installedExecutable -PassThru
Start-Sleep -Seconds 5
$application.Refresh()
if ($application.HasExited) {
  throw "MSI-installed application exited immediately with code $($application.ExitCode)."
}
Stop-Process -Id $application.Id -Force
$application.WaitForExit()

Write-VerificationPhase 'Uninstalling MSI.'
$uninstall = Start-Process msiexec.exe -ArgumentList @('/x', $msi, '/qn', '/norestart') -Wait -PassThru
if ($uninstall.ExitCode -ne 0 -or (Test-Path $installedExecutable)) {
  throw 'MSI uninstall smoke test failed.'
}

Write-VerificationPhase 'MSI smoke test completed.'
