# Build setup status

## Hardware check — 2026-09-18

- Reader: reader PC; target: target PC.
- Windows reports the connected FT601 USB 3.0 bridge and its composite device as `OK`.
- USB identity: `VID_0403&PID_601F`; data interface: `MI_00`.
- This differs from the older `PID_6011` programming-interface observation in the NAS notes.
- This check confirms USB enumeration only. FPGA communication and target-memory access have not been tested.

## Sources and tools

- CE source archive unpacked under `sources/cheat-engine-master`.
- Main project: `sources/cheat-engine-master/Cheat Engine/cheatengine.lpi`.
- Project metadata says 7.5; establish the actual source revision and its relationship to 7.7 before labeling a build 7.7.
- Visual Studio Community 2026 is installed.
- C++ x86/x64 tools are now installed. MSVC tool directories include `14.44.35207` (v143) and `14.51.36231`; Windows SDK `10.0.26100.0` is installed.
- FT601 driver confirmed: FTDI `1.3.0.10`, installed INF `oem53.inf`.
- Lazarus `4.8` is installed at `C:\lazarus`, with Free Pascal `3.2.2` under `C:\lazarus\fpc\3.2.2`. Use explicit tool paths because they are not on PATH. Compatibility of Lazarus 4.8 with this CE source remains to be checked.
- `bin.zip` contains CE executables, the DMA plugin, and FT601/LeechCore runtime DLLs. These binaries have not been executed or validated.

## Next build checkpoints

1. Establish and pin the CE source revision for the 7.7 target.
2. Install the source revision's required Lazarus/Free Pascal toolchain and confirm the plugin's v143 C++ toolset and Windows SDK.
3. Build and launch the unchanged CE x64 baseline.
4. Obtain and pin the kaijia2022 plugin source; match its SDK layout to CE and port the required export if absent.
5. Build matching x64 dependencies and plugin, then validate loading and device communication.

Keep build output separate from source archives and existing binaries.

## Fresh repository downloads — 2026-09-18

All repositories below were downloaded directly from their authors' GitHub repositories as shallow Git checkouts. Existing archives were preserved.

| Directory under `sources/` | Repository | Commit |
| --- | --- | --- |
| `cheat-engine-upstream` | https://github.com/cheat-engine/cheat-engine | `ec45d5f47f92a239ba0bf51ec5d04a7509c3fd37` |
| `ce-dma-plugin` | https://github.com/kaijia2022/Cheat-Engine-DMA-Plugin | `297ac2f48e326baefefeea77dc48b25cf80a7e36` |
| `cheatengine-extended-sdk` | https://github.com/kaijia2022/cheatengine-extended-sdk | `5c2f8a197fc80fa242c5e662dcfc391d04a4adb7` |
| `leechcore` | https://github.com/ufrisk/LeechCore | `709dce874df14e289e1c26fc18ab0b0856ae4151` |
| `memprocfs` | https://github.com/ufrisk/MemProcFS | `b5c5182efda266da9ebce7f23d4893efd4cd2553` |

The freshly downloaded official CE source still declares `ceversion=7.51` in `MainUnit2.pas`; its remote tags stop at 7.5. These downloads do not establish a CE 7.7 source baseline.

LeechCore and MemProcFS are current source checkouts for dependency inspection, not yet verified compatible versions for this older plugin. Match their APIs and runtime versions before building or substituting DLLs. The plugin checkout already includes reference dependency libraries and DLLs; these have not been executed.

The extended SDK is a comparison reference. Its older `plugin.pas` has not been copied over upstream CE.

## GHL build — 2026-09-18

The selected baseline is the latest public upstream commit recorded above, regardless of its older version label. Our edition is named **GHL**, based on public CE **7.5.1**; it is not represented as the official 7.7 source.

- Unmodified CE x64 baseline compiled successfully with Lazarus 2.2.2 / FPC 3.2.2.
- Lazarus 2.2.2 was downloaded from the official Lazarus SourceForge project and extracted to `tools/lazarus-2.2.2/app` using innoextract. Existing Lazarus 4.8 was preserved. A workspace-local FPC configuration supplies extracted unit paths.
- Visual Studio 2026 registers v145, not v143, despite the older compiler directory being present. The plugin builds with v145 using `scripts/Build-Plugin.ps1`; its project retains v143 as the upstream default.
- Removed the 32-bit Lua import library from the plugin's x64 configurations.
- GHL SDK 7 appends the `IsWow64Process` slot after the standard exported function table. CE retains the original tables for legacy plugin versions; the GHL plugin requires SDK 7. This layout differs from the old extended SDK fork.
- Added plugin initialization checks for null/wrong-size tables and failed VMM initialization, and cleanup when menu registration fails.
- The GHL host and plugin compiled successfully. An initial incremental CE compile hit an FPC internal exception; a full rebuild succeeded.
- The plugin DLL loaded successfully in a dependency test. GHL identity, SDK 7, and rejection of invalid/null tables passed without requesting DMA initialization.

### Output and rebuild commands

Runtime folder: `build/GHL/runtime`. Launch `GHL.exe`; select `CE-DMAPlugin.dll` in CE's plugin settings when ready for device testing.

The runtime includes CE assets and Lua from the upstream checkout, plus the selected plugin repository's matching reference VMM, LeechCore, and FT601 DLLs. Current dependency source checkouts have not been substituted for these reference DLLs.

Run these commands from the workspace in PowerShell 7:

```powershell
.\scripts\Build-CE.ps1 -Rebuild
.\scripts\Build-Plugin.ps1
.\scripts\Test-Plugin.ps1
```

The build scripts compile into their documented source/output locations. The test checks the staged runtime DLL; after rebuilding, copy updated host/plugin binaries into `build/GHL/runtime` before testing. Live CE startup, successful host/plugin initialization, FPGA communication, and game/table tests remain pending. Other optional CE secondary projects were not rebuilt.

## Follow-up testing and autorun fix

The user reports successfully enabling the plugin and changing Peglin gold on the target PC. This is a reported read/write test, not validation of every plugin capability.

The Java and Mono process-open autorun handlers assumed that `enumModules()` always returns a table. A missing module snapshot returns nil, producing the reported `#m` errors. Both source and staged runtime handlers now fall back to an empty table while retaining their existing menu/state handling. This prevents those startup exceptions; it does not restore module enumeration or add injection support.

`scripts/Test-Autorun.lua` exercises the actual patched handler functions with mocked CE APIs. Nil, empty, native, Java, Mono, and .NET module-list cases all passed. Restart GHL to reload the edited autorun scripts.

The supplied DD2 table identifies Dragon's Dogma 2 / `DD2.exe`, game version 3.2.0.0, table version 7.0.0. It contains embedded Lua and main-hook scripts. It was inspected as data only, not executed or included in the shared build. Full table compatibility with DMA is not established.

## Plugin r2: table loader and process-architecture fixes

The table's `CETrequire` reads its embedded stream using `readStringLocal`. CE implements that using its current-process pseudo-handle and the hooked memory API. The old hook treated that handle as a target PID, so local table data could not be read and Lua's `load` received nil.

Plugin r2 forwards current-process reads, writes, and virtual queries to the saved native APIs. It also corrects `hIsWow64Process` to take a BOOL output pointer and query the target PID through VMM rather than dereferencing a PID as a pointer. Target read byte counts are converted from VMM's DWORD into CE's SIZE_T explicitly, with oversized reads rejected.

The hardware-free `Test-Hooks` executable compiles the actual hook source with mocked VMM process/read/write operations. Local embedded-Lua reads, local writes/queries/architecture, synthetic target PID lookup, target routing, oversized reads, and missing-device byte counts passed without initializing DMA.

The r2 runtime has been superseded by r3 in the canonical `build/GHL/runtime` folder.

## Plugin r3: process handling

The user confirmed manual attachment to the current DD2 PID and successful table
Lua initialization after commenting out the table's name-based AutoAttach call.
This implicates the auto-attach path, but does not prove stale selection was the
only cause. VMM's ProcessGetInformationAll explicitly includes terminated
processes; the original plugin did not filter them.

R3 requests VMMDLL_OPT_REFRESH_FREQ_MEDIUM (full process refresh) before retrieving
the process list and before opening a PID. It skips nonzero process states,
validates a PID with ProcessGetInformation before updating the selected process,
and fails closed if refresh or lookup fails. Process iteration bounds every skip;
returned Win32 structure sizes are corrected. Module iteration rejects empty maps
and invalid snapshot handles, and safely truncates long paths and accepts null
names. These address additional independent crash risks; the exact Windows
fail-fast crash site was not captured in a dump.

Test-Hooks reproduced invalid-PID acceptance before the fix. Extended tests pass
for refresh, terminated/nonexistent PID rejection, terminated filtering, empty
and all-filtered lists, fixed-width process names, empty module maps, long/null
paths, invalid snapshots, and all r2 memory/architecture cases. SDK/load tests and
all six autorun cases pass. Tests use fake VMM data and do not access DMA hardware.

Launch build/GHL/runtime/GHL.exe and select that folder's CE-DMAPlugin.dll in
Settings > Plugins; its display name must include r3. Superseded ZIPs/staging
folders and runtime-processfix are removed after packaging. Source, tests,
toolchains, original archives, and user tables remain unchanged. Live r3 DD2
auto-attachment and individual table cheats still require user testing.
