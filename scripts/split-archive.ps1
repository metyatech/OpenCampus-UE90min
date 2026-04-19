[CmdletBinding()]
param(
  [string]$InputPath,
  [string]$OutputDirectory,
  [string]$BaseName,
  [int]$SplitThresholdMB = 1900,
  [ValidateRange(0, 9)]
  [int]$CompressionLevel = 3,
  [string]$GitHubOutputKey = 'assets'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-7Zip {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $sevenZip = Get-Command 7z -ErrorAction Stop
  & $sevenZip.Source @Arguments

  if ($LASTEXITCODE -ne 0) {
    throw "7z failed with exit code $LASTEXITCODE"
  }
}

function Write-GitHubOutputList {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$Key,

    [Parameter(Mandatory = $true)]
    [string[]]$Values
  )

  if ([string]::IsNullOrWhiteSpace($env:GITHUB_OUTPUT)) {
    return
  }

  $delimiter = 'SISYPHUS_ARCHIVE_ASSETS'
  "$Key<<$delimiter" | Add-Content -LiteralPath $env:GITHUB_OUTPUT
  foreach ($value in $Values) {
    $value | Add-Content -LiteralPath $env:GITHUB_OUTPUT
  }
  $delimiter | Add-Content -LiteralPath $env:GITHUB_OUTPUT
}

function New-ReleaseArchive {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $true)]
    [string]$BaseName,

    [int]$SplitThresholdMB = 1900,

    [ValidateRange(0, 9)]
    [int]$CompressionLevel = 3,

    [string]$GitHubOutputKey = 'assets'
  )

  $resolvedInputPath = (Resolve-Path -LiteralPath $InputPath).Path
  $resolvedOutputDirectory = New-Item -ItemType Directory -Path $OutputDirectory -Force

  $temporaryArchivePath = Join-Path $resolvedOutputDirectory.FullName ($BaseName + '.tmp.7z')
  $finalArchivePath = Join-Path $resolvedOutputDirectory.FullName ($BaseName + '.7z')
  $splitThresholdBytes = $SplitThresholdMB * 1MB
  $inputParentDirectory = Split-Path -Parent $resolvedInputPath
  $inputLeafName = Split-Path -Leaf $resolvedInputPath

  Get-ChildItem -LiteralPath $resolvedOutputDirectory.FullName -Filter ($BaseName + '.7z*') -File -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

  Push-Location $inputParentDirectory
  try {
    Invoke-7Zip -Arguments @('a', "-mx=$CompressionLevel", '-t7z', '--', $temporaryArchivePath, $inputLeafName)
  }
  finally {
    Pop-Location
  }

  $archive = Get-Item -LiteralPath $temporaryArchivePath

  if ($archive.Length -gt $splitThresholdBytes) {
    Remove-Item -LiteralPath $temporaryArchivePath -Force

    Push-Location $inputParentDirectory
    try {
      Invoke-7Zip -Arguments @('a', "-mx=$CompressionLevel", '-t7z', "-v${SplitThresholdMB}m", '--', $finalArchivePath, $inputLeafName)
    }
    finally {
      Pop-Location
    }

    $assets = Get-ChildItem -LiteralPath $resolvedOutputDirectory.FullName -Filter ($BaseName + '.7z*') -File |
      Sort-Object Name |
      Select-Object -ExpandProperty FullName
  }
  else {
    Rename-Item -LiteralPath $temporaryArchivePath -NewName ($BaseName + '.7z') -Force
    $assets = @($finalArchivePath)
  }

  Write-GitHubOutputList -Key $GitHubOutputKey -Values $assets
  return ,$assets
}

if ($MyInvocation.InvocationName -ne '.') {
  New-ReleaseArchive `
    -InputPath $InputPath `
    -OutputDirectory $OutputDirectory `
    -BaseName $BaseName `
    -SplitThresholdMB $SplitThresholdMB `
    -CompressionLevel $CompressionLevel `
    -GitHubOutputKey $GitHubOutputKey
}
