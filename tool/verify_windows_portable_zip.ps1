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
$portableDirectory = Join-Path $env:RUNNER_TEMP 'sendreq-portable-smoke-test'

if (Test-Path $portableDirectory) {
  Remove-Item -Recurse -Force $portableDirectory
}
Expand-Archive -Path $archive -DestinationPath $portableDirectory -Force

$portableExecutable = Join-Path $portableDirectory 'sendreq.exe'
if (-not (Test-Path $portableExecutable -PathType Leaf)) {
  throw 'Portable archive does not contain sendreq.exe at its root.'
}

# The portable ZIP must preserve every bundle file byte-for-byte.
Get-ChildItem -Path $bundle -File -Recurse | ForEach-Object {
  $relativePath = $_.FullName.Substring($bundle.Length).TrimStart([char[]]'\')
  $portableFile = Join-Path $portableDirectory $relativePath
  if (-not (Test-Path $portableFile -PathType Leaf)) {
    throw "Portable archive is missing '$relativePath'."
  }
  if ((Get-FileHash $_.FullName).Hash -ne (Get-FileHash $portableFile).Hash) {
    throw "Portable archive file '$relativePath' differs from the release bundle."
  }
}

$application = Start-Process -FilePath $portableExecutable -PassThru
Start-Sleep -Seconds 5
$application.Refresh()
if ($application.HasExited) {
  throw "Portable application exited immediately with code $($application.ExitCode)."
}
Stop-Process -Id $application.Id -Force
$application.WaitForExit()
