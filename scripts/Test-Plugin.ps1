param([string]$Runtime = 'build\GHL\runtime')
$ErrorActionPreference = 'Stop'
$workspacePath = Split-Path $PSScriptRoot -Parent
$runtimePath = Join-Path $workspacePath $Runtime
$env:Path = "$runtimePath;$env:Path"
Add-Type @'
using System;
using System.Runtime.InteropServices;
[UnmanagedFunctionPointer(CallingConvention.StdCall)]
[return: MarshalAs(UnmanagedType.Bool)]
public delegate bool GhlGetVersion(IntPtr version, int size);
[UnmanagedFunctionPointer(CallingConvention.StdCall)]
[return: MarshalAs(UnmanagedType.Bool)]
public delegate bool GhlInitialize(IntPtr functions, int pluginId);
'@
$library = [System.Runtime.InteropServices.NativeLibrary]::Load((Join-Path $runtimePath 'CE-DMAPlugin.dll'))
$versionMemory = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(16)
$invalidTable = [System.Runtime.InteropServices.Marshal]::AllocHGlobal(4)
try {
    $versionFunction = [System.Runtime.InteropServices.NativeLibrary]::GetExport($library, 'CEPlugin_GetVersion')
    $getVersion = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($versionFunction, [GhlGetVersion])
    if (-not $getVersion.Invoke($versionMemory, 16)) { throw 'GetVersion failed.' }
    $sdkVersion = [System.Runtime.InteropServices.Marshal]::ReadInt32($versionMemory)
    $namePointer = [System.Runtime.InteropServices.Marshal]::ReadIntPtr($versionMemory, 8)
    $pluginName = [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($namePointer)
    if ($sdkVersion -ne 7 -or $pluginName -notmatch 'GHL') { throw 'Incorrect GHL build identity.' }
    $initializeFunction = [System.Runtime.InteropServices.NativeLibrary]::GetExport($library, 'CEPlugin_InitializePlugin')
    $initialize = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($initializeFunction, [GhlInitialize])
    [System.Runtime.InteropServices.Marshal]::WriteInt32($invalidTable, 0)
    if ($initialize.Invoke($invalidTable, 0)) { throw 'Invalid SDK table was accepted.' }
    if ($initialize.Invoke([IntPtr]::Zero, 0)) { throw 'Null SDK table was accepted.' }
    Write-Output "$pluginName; SDK $sdkVersion; invalid/null table rejection passed. No DMA initialization was requested."
} finally {
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($versionMemory)
    [System.Runtime.InteropServices.Marshal]::FreeHGlobal($invalidTable)
    [System.Runtime.InteropServices.NativeLibrary]::Free($library)
}
