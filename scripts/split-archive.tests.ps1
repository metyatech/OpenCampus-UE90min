$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'split-archive.ps1')

Describe 'New-ReleaseArchive' {
  BeforeEach {
    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
    $inputDirectory = Join-Path $testRoot 'Windows'
    $outputDirectory = Join-Path $testRoot 'release-assets'
    New-Item -ItemType Directory -Path $inputDirectory -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $inputDirectory 'UE90min.exe') -Force | Out-Null

    Mock Invoke-7Zip {}
    Mock Get-Command { [pscustomobject]@{ Source = 'C:\Program Files\7-Zip\7z.exe' } } -ParameterFilter { $Name -eq '7z' }
    Mock Rename-Item {}
    Mock Remove-Item {}
  }

  AfterEach {
    if (Test-Path -LiteralPath $testRoot) {
      Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
  }

  It 'creates a single archive when the temporary archive fits under the threshold' {
    Mock Get-Item {
      [pscustomobject]@{
        Length = 5MB
      }
    } -ParameterFilter { $LiteralPath -like '*.tmp.7z' }

    $assets = New-ReleaseArchive -InputPath $inputDirectory -OutputDirectory $outputDirectory -BaseName 'UE90min-Win64-Development-v1.0.0'

    $assets.Count | Should Be 1
    $assets[0] | Should Be (Join-Path $outputDirectory 'UE90min-Win64-Development-v1.0.0.7z')
    Assert-MockCalled Invoke-7Zip -Exactly 1 -Scope It
    Assert-MockCalled Rename-Item -Exactly 1 -Scope It
    Assert-MockCalled Remove-Item -Exactly 0 -Scope It -ParameterFilter { $LiteralPath -like '*.tmp.7z' }
  }

  It 'creates split archives when the temporary archive exceeds the threshold' {
    Mock Get-Item {
      [pscustomobject]@{
        Length = 5MB
      }
    } -ParameterFilter { $LiteralPath -like '*.tmp.7z' }

    Mock Get-ChildItem {
      @(
        [pscustomobject]@{ Name = 'UE90min-Win64-Development-v1.0.0.7z.001'; FullName = (Join-Path $outputDirectory 'UE90min-Win64-Development-v1.0.0.7z.001') },
        [pscustomobject]@{ Name = 'UE90min-Win64-Development-v1.0.0.7z.002'; FullName = (Join-Path $outputDirectory 'UE90min-Win64-Development-v1.0.0.7z.002') },
        [pscustomobject]@{ Name = 'UE90min-Win64-Development-v1.0.0.7z.003'; FullName = (Join-Path $outputDirectory 'UE90min-Win64-Development-v1.0.0.7z.003') }
      )
    } -ParameterFilter { $Filter -eq 'UE90min-Win64-Development-v1.0.0.7z*' }

    $assets = New-ReleaseArchive -InputPath $inputDirectory -OutputDirectory $outputDirectory -BaseName 'UE90min-Win64-Development-v1.0.0' -SplitThresholdMB 2

    $assets.Count | Should Be 3
    $assets[0] | Should Be (Join-Path $outputDirectory 'UE90min-Win64-Development-v1.0.0.7z.001')
    Assert-MockCalled Invoke-7Zip -Exactly 2 -Scope It
    Assert-MockCalled Invoke-7Zip -Exactly 1 -Scope It -ParameterFilter { $Arguments -contains '-v2m' }
    Assert-MockCalled Remove-Item -Exactly 1 -Scope It -ParameterFilter { $LiteralPath -like '*.tmp.7z' }
    Assert-MockCalled Rename-Item -Exactly 0 -Scope It
  }
}
