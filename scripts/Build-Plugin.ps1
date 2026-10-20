param(
    [string]$Toolset = 'v145',
    [string]$Project = 'sources\ce-dma-plugin\CE-DMAPlugin.vcxproj',
    [string]$Output = 'build\GHL\plugin',
    [string]$Intermediate = 'build\plugin-obj'
)

$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
$vswherePath = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
$visualStudioPath = & $vswherePath -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $visualStudioPath) { throw 'Visual Studio C++ tools were not found.' }

$buildStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
$buildStartInfo.FileName = Join-Path $visualStudioPath 'MSBuild\Current\Bin\MSBuild.exe'
$buildStartInfo.WorkingDirectory = $workspacePath
$buildStartInfo.UseShellExecute = $false
# Normalize environment names to prevent duplicate Path/PATH keys in MSBuild.
$buildStartInfo.Environment.Clear()
foreach ($envEntry in [System.Environment]::GetEnvironmentVariables().GetEnumerator()) {
    $buildStartInfo.Environment[$envEntry.Key.ToUpperInvariant()] = $envEntry.Value
}
$buildArguments = @(
    (Join-Path $workspacePath $Project),
    '/p:Configuration=Release', '/p:Platform=x64', "/p:PlatformToolset=$Toolset",
    "/p:OutDir=$workspacePath\$Output\",
    "/p:IntDir=$workspacePath\$Intermediate\", '/v:minimal', '/nologo'
)
foreach ($buildArgument in $buildArguments) { $buildStartInfo.ArgumentList.Add($buildArgument) }
$buildProcess = [System.Diagnostics.Process]::Start($buildStartInfo)
$buildProcess.WaitForExit()
exit $buildProcess.ExitCode
