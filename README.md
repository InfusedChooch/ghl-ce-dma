# GHL CE + DMA plugin

Private source preservation for the GHL edition of Cheat Engine and its DMA
plugin. This is based on public CE 7.5.1 source, not official CE 7.7 source.

## Contents

- `upstream/`: original source archives preserved from the local GHL package.
- `patches/`: GHL host and plugin r3 modifications.
- `scripts/`: original build scripts and hardware-free regression tests, plus
  a source preparation script.
- `SOURCE-INFO.txt`: upstream revisions, dependency versions, and change summary.
- `docs/BUILD-HISTORY.md`: dated build and test evidence from the original workspace.
- `Licenses/`: original plugin and dependency license notices.

The CE changes add the GHL label, append the SDK 7 IsWow64Process export, and
handle missing Java/Mono module lists. Plugin changes validate initialization,
preserve local-process API behavior, correct architecture and read-count
handling, and improve process refresh, PID validation, and module iteration.

## Prepare and build

Run from the repository root in PowerShell 7:

```powershell
.\scripts\Prepare-Sources.ps1
.\scripts\Build-CE.ps1 -Rebuild
.\scripts\Build-Plugin.ps1
```

Preparation extracts the archived sources into ignored directories and applies
the matching patches. The plugin patch needs `git apply --recount` because its
saved hunk counts are inconsistent; preparation checks applicability first.

Building requires the original toolchain setup: Lazarus 2.2.2 / FPC 3.2.2 under
`tools/lazarus-2.2.2/app`, workspace FPC configuration, and Visual Studio C++
v145. These tools and generated runtime files are not included. Consult the
dated build history for details; these commands are not a complete toolchain
installer.

`Test-Hooks.c`, `Test-Hooks.vcxproj`, and `Test-Autorun.lua` preserve the
hardware-free regression tests. `Test-Plugin.ps1` expects a separately staged
runtime. `Package-GHL.ps1` is the original workspace packaging script and
requires additional runtime, dependency checkout, and build metadata files
that are not provided by source preparation.

## Provenance and distribution

CE upstream: https://github.com/cheat-engine/cheat-engine

Pinned revision: `ec45d5f47f92a239ba0bf51ec5d04a7509c3fd37`

Plugin upstream: https://github.com/kaijia2022/Cheat-Engine-DMA-Plugin

Pinned revision: `297ac2f48e326baefefeea77dc48b25cf80a7e36`

Upstream attribution and source notices remain in the archives. The plugin's
MIT license is retained. This repository does not relicense upstream code.
The original archives may include upstream build assets and import libraries.

The packaged GHL executable and runtime DLLs are available in the private
GitHub prerelease, rather than the source tree. The original
VMM and LeechCore DLLs have recorded versions but unknown exact source commits.
Review corresponding-source and redistribution requirements before publishing
a public binary release, including FTDI and Microsoft runtime terms.

## Validation status

For this publication, source patch applicability and PowerShell syntax were
checked. Historical test results are recorded in the build history; they are
not a new build or hardware validation. Live r3 DD2 auto-attachment remains
unverified in the preserved evidence.

The shareable release replaces local machine names in documentation and
reduces the plugin's embedded CodeView PDB path to `CE-DMAPlugin.pdb`.
The DLL change is confined to debug-path bytes, with its size and executable
code preserved. The sanitized DLL has not been executed or hardware-tested.
Upstream attribution and upstream example paths remain intact.
