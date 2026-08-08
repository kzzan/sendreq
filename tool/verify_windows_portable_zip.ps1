[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Container })]
  [string]$BundleDirectory,

  [Parameter(Mandatory = $true)]
  [ValidateScript({ Test-Path $_ -PathType Leaf })]
  [string]$ZipPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$bundle = (Resolve-Path $BundleDirectory).Path
$archive = (Resolve-Path $ZipPath).Path
$temporaryDirectory = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
  [System.IO.Path]::GetTempPath()
} else {
  $env:RUNNER_TEMP
}
$portableDirectory = Join-Path $temporaryDirectory 'sendreq-portable-smoke-test'
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

function Write-VerificationPhase([string]$message) {
  Write-Host ("[{0:mm\:ss}] {1}" -f $stopwatch.Elapsed, $message)
}

function Get-RelativeFilePath([string]$root, [string]$path) {
  return $path.Substring($root.Length).TrimStart([char[]]'\')
}

if (Test-Path $portableDirectory) {
  Remove-Item -Recurse -Force $portableDirectory
}
Write-VerificationPhase 'Extracting portable ZIP.'
Expand-Archive -Path $archive -DestinationPath $portableDirectory -Force

$portableExecutable = Join-Path $portableDirectory 'sendreq.exe'
if (-not (Test-Path $portableExecutable -PathType Leaf)) {
  throw 'Portable archive does not contain sendreq.exe at its root.'
}

# Verify the complete payload layout and file sizes. Hashing every Flutter
# asset is expensive on hosted Windows runners because each read can trigger
# Defender scanning, so SHA-256 is limited to the executable, native DLLs,
# ICU data, and Flutter asset manifests.
Write-VerificationPhase 'Checking portable payload layout and sizes.'
$bundleFiles = @(Get-ChildItem -Path $bundle -File -Recurse)
$portableFiles = @(Get-ChildItem -Path $portableDirectory -File -Recurse)
if ($portableFiles.Count -ne $bundleFiles.Count) {
  throw "Portable archive contains $($portableFiles.Count) files; expected $($bundleFiles.Count)."
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
  $portableFile = Join-Path $portableDirectory $relativePath
  if (-not (Test-Path $portableFile -PathType Leaf)) {
    throw "Portable archive is missing '$relativePath'."
  }
  if ($file.Length -ne (Get-Item $portableFile).Length) {
    throw "Portable archive file '$relativePath' has a different size."
  }
}

Write-VerificationPhase "Hashing $($criticalRelativePaths.Count) critical portable files."
foreach ($relativePath in $criticalRelativePaths) {
  $sourceFile = Join-Path $bundle $relativePath
  $portableFile = Join-Path $portableDirectory $relativePath
  if ((Get-FileHash $sourceFile).Hash -ne (Get-FileHash $portableFile).Hash) {
    throw "Portable archive file '$relativePath' differs from the release bundle."
  }
}

Write-VerificationPhase 'Launching portable application.'
$application = Start-Process -FilePath $portableExecutable -PassThru
Start-Sleep -Seconds 5
$application.Refresh()
if ($application.HasExited) {
  throw "Portable application exited immediately with code $($application.ExitCode)."
}
Stop-Process -Id $application.Id -Force
$application.WaitForExit()

Write-VerificationPhase 'Portable ZIP smoke test completed.'
