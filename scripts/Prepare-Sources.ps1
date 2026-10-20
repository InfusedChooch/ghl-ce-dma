$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
$sourcePairs = @(
    @{ Name = 'cheat-engine-upstream'; Patch = 'ce-ghl.patch' },
    @{ Name = 'ce-dma-plugin'; Patch = 'plugin-ghl.patch' }
)

# Refuse partial overwrites so existing source edits remain safe.
foreach ($sourcePair in $sourcePairs) {
    $destinationPath = Join-Path $workspacePath "sources\$($sourcePair.Name)"
    if (Test-Path -LiteralPath $destinationPath) {
        throw "Source directory already exists: $destinationPath. Preserve or move it before preparing sources."
    }
}

foreach ($sourcePair in $sourcePairs) {
    $destinationPath = Join-Path $workspacePath "sources\$($sourcePair.Name)"
    $archivePath = Join-Path $workspacePath "upstream\$($sourcePair.Name).zip"
    $patchPath = Join-Path $workspacePath "patches\$($sourcePair.Patch)"
    Expand-Archive -LiteralPath $archivePath -DestinationPath $destinationPath
    & git -C $workspacePath apply --recount --check "--directory=sources/$($sourcePair.Name)" $patchPath
    if ($LASTEXITCODE -ne 0) { throw "Patch validation failed: $patchPath" }
    & git -C $workspacePath apply --recount "--directory=sources/$($sourcePair.Name)" $patchPath
    if ($LASTEXITCODE -ne 0) { throw "Patch application failed: $patchPath" }
}
Write-Output 'Prepared both patched source trees.'
