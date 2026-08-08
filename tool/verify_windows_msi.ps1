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
$installDirectory = Join-Path $env:ProgramFiles 'sendreq-msi-smoke-test'

if (Test-Path $installDirectory) {
  Remove-Item -Recurse -Force $installDirectory
}

# Passing the public INSTALLFOLDER property keeps the smoke test isolated from
# the user's regular Program Files location while exercising real MSI actions.
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

Get-ChildItem -Path $bundle -File -Recurse | ForEach-Object {
  $relativePath = $_.FullName.Substring($bundle.Length).TrimStart([char[]]'\')
  $installedFile = Join-Path $installDirectory $relativePath
  if (-not (Test-Path $installedFile -PathType Leaf)) {
    throw "MSI installation is missing '$relativePath'."
  }
  if ((Get-FileHash $_.FullName).Hash -ne (Get-FileHash $installedFile).Hash) {
    throw "MSI installed file '$relativePath' differs from the release bundle."
  }
}

$application = Start-Process -FilePath $installedExecutable -PassThru
Start-Sleep -Seconds 5
$application.Refresh()
if ($application.HasExited) {
  throw "MSI-installed application exited immediately with code $($application.ExitCode)."
}
Stop-Process -Id $application.Id -Force
$application.WaitForExit()

$uninstall = Start-Process msiexec.exe -ArgumentList @('/x', $msi, '/qn', '/norestart') -Wait -PassThru
if ($uninstall.ExitCode -ne 0 -or (Test-Path $installedExecutable)) {
  throw 'MSI uninstall smoke test failed.'
}
