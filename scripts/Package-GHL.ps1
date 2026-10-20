param([string]$Runtime = 'build\GHL\runtime')
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
$packageName = 'GHL-' + (Get-Date -Format 'yyyy-MM-dd-HHmmss')
$stagePath = Join-Path $workspacePath "build\packages\$packageName"
$packagePath = Join-Path $stagePath 'GHL'
$runtimePath = Join-Path $workspacePath $Runtime
$archivePath = Join-Path $workspacePath "build\packages\$packageName.zip"
New-Item -ItemType Directory -Path "$packagePath\Sources", "$packagePath\Licenses" | Out-Null

Get-ChildItem -LiteralPath $runtimePath | Where-Object {
    $_.Extension -notin @('.dbg', '.pdb', '.bat', '.log')
} | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $packagePath -Recurse }
Copy-Item -LiteralPath "$workspacePath\build\GHL\START-HERE.txt", "$workspacePath\build\GHL\SOURCE-INFO.txt" -Destination $packagePath
Copy-Item -LiteralPath "$workspacePath\SETUP.md" -Destination "$packagePath\Sources"
Copy-Item -LiteralPath "$workspacePath\scripts" -Destination "$packagePath\Sources" -Recurse
Copy-Item -LiteralPath "$workspacePath\build\GHL\ce-ghl.patch", "$workspacePath\build\GHL\plugin-ghl.patch" -Destination "$packagePath\Sources"
Copy-Item -LiteralPath "$workspacePath\sources\ce-dma-plugin\LICENSE" -Destination "$packagePath\Licenses\Plugin-MIT.txt"
Copy-Item -LiteralPath "$workspacePath\sources\leechcore\LICENSE" -Destination "$packagePath\Licenses\LeechCore-GPL-3.txt"
Copy-Item -LiteralPath "$workspacePath\sources\memprocfs\LICENSE" -Destination "$packagePath\Licenses\MemProcFS-AGPL-3.txt"

$vswherePath = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
$visualStudioPath = & $vswherePath -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
$crtPath = Join-Path $visualStudioPath 'VC\Redist\MSVC\14.51.36231\x64\Microsoft.VC145.CRT'
if (-not (Test-Path -LiteralPath $crtPath)) { throw 'Expected VC145 release runtime folder was not found.' }
Get-ChildItem -LiteralPath $crtPath -Filter '*.dll' | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $packagePath }

foreach ($repoName in @('cheat-engine-upstream', 'ce-dma-plugin')) {
    $repoPath = Join-Path $workspacePath "sources\$repoName"
    $sourcePaths = @()
    if ($repoName -eq 'ce-dma-plugin') {
        $sourcePaths = @('CE-DMAPlugin.c','hFunctions.c','hFunctions.h','CE-DMAPlugin.def','CE-DMAPlugin.sln','CE-DMAPlugin.vcxproj','include','LICENSE','README.md','*.lib')
    }
    & git -c "safe.directory=$($repoPath.Replace('\','/'))" -C $repoPath archive --format=zip --output="$packagePath\Sources\$repoName.zip" HEAD @sourcePaths
    if ($LASTEXITCODE -ne 0) { throw "Source archive failed: $repoName" }
}

Compress-Archive -LiteralPath $packagePath -DestinationPath $archivePath -CompressionLevel Fastest
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
try {
    foreach ($requiredName in @('GHL/GHL.exe','GHL/CE-DMAPlugin.dll','GHL/vmm.dll','GHL/leechcore.dll','GHL/FTD3XX.dll','GHL/START-HERE.txt','GHL/lua53-64.dll')) {
        if (-not $archive.GetEntry($requiredName)) { throw "Missing ZIP entry: $requiredName" }
    }
} finally { $archive.Dispose() }
Get-Item -LiteralPath $archivePath | Select-Object FullName,Length
Get-FileHash -LiteralPath $archivePath -Algorithm SHA256 | Select-Object Hash
