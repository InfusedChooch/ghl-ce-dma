param([switch]$Rebuild)
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
$lazarusPath = Join-Path $workspacePath 'tools\lazarus-2.2.2\app'
$buildOptions = @()
if ($Rebuild) { $buildOptions += '--build-all' }
& "$lazarusPath\lazbuild.exe" @buildOptions '--no-write-project' "--primary-config-path=$workspacePath\build\lazarus-222-profile" "--lazarusdir=$lazarusPath" "--compiler=$lazarusPath\fpc\3.2.2\bin\x86_64-win64\fpc.exe" '--build-mode=Release 64-Bit' "$workspacePath\sources\cheat-engine-upstream\Cheat Engine\cheatengine.lpi"
exit $LASTEXITCODE
