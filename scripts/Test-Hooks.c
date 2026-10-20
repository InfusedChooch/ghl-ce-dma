#include <stdio.h>
#include <string.h>
#include "../sources/ce-dma-plugin/hFunctions.h"

static int localReads, remoteReads, localWrites, remoteWrites, refreshes;
static BOOL refreshOK = TRUE;
static VMMDLL_PROCESS_INFORMATION fakeProcesses[4];
static DWORD fakeProcessCount;
static VMMDLL_MAP_MODULE* fakeModules;
BOOL VMMDLL_Map_GetModuleU(VMM_HANDLE v, DWORD pid, PVMMDLL_MAP_MODULE* map, DWORD flags) {
    *map = fakeModules; return TRUE;
}
BOOL VMMDLL_ConfigSet(VMM_HANDLE v, ULONG64 option, ULONG64 value) {
    if (option == VMMDLL_OPT_REFRESH_FREQ_MEDIUM && value == 1) { ++refreshes; }
    return refreshOK;
}
VOID VMMDLL_MemFree(PVOID p) { }
BOOL VMMDLL_ProcessGetInformationAll(VMM_HANDLE v, PVMMDLL_PROCESS_INFORMATION* entries, PDWORD count) {
    *entries = fakeProcesses; *count = fakeProcessCount; return TRUE;
}
static BOOL WINAPI nativeRead(HANDLE h, LPCVOID a, LPVOID b, SIZE_T n, SIZE_T* done) {
    ++localReads; return ReadProcessMemory(h, a, b, n, done);
}
static BOOL WINAPI nativeWrite(HANDLE h, LPCVOID a, LPVOID b, SIZE_T n, SIZE_T* done) {
    ++localWrites; return WriteProcessMemory(h, (LPVOID)a, b, n, done);
}
GHL_READ_PROCESS_MEMORY pReadProcessMemory = nativeRead;
PVOID pWriteProcessMemory = nativeWrite;
PVOID pIsWow64Process = IsWow64Process;
PVOID pVirtualQueryEx = VirtualQueryEx;

//These test implementations route fake target operations without DMA access.
BOOL VMMDLL_ProcessGetInformation(VMM_HANDLE v, DWORD pid, PVMMDLL_PROCESS_INFORMATION info, PSIZE_T size) {
    if ((pid != 42 && pid != 43) || !info || info->magic != VMMDLL_PROCESS_INFORMATION_MAGIC ||
        info->wVersion != VMMDLL_PROCESS_INFORMATION_VERSION || *size != sizeof(*info)) { return FALSE; }
    info->win.fWow64 = TRUE;
    info->dwPID = pid;
    info->dwState = pid == 43 ? 1 : 0;
    return TRUE;
}
BOOL VMMDLL_MemReadEx(VMM_HANDLE v, DWORD pid, ULONG64 address, PBYTE buffer, DWORD size, PDWORD done, ULONG64 flags) {
    ++remoteReads;
    if (pid != 42) { return FALSE; }
    memset(buffer, 'R', size); *done = size; return TRUE;
}
BOOL VMMDLL_MemWrite(VMM_HANDLE v, DWORD pid, ULONG64 address, PBYTE buffer, DWORD size) {
    ++remoteWrites; return pid == 42;
}
#define CHECK(x) do { if (!(x)) { fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #x); return 1; } } while (0)

int main(void) {
    char embeddedLua[] = "return 'embedded module loaded'";
    char buffer[sizeof(embeddedLua)] = {0};
    SIZE_T done = ~(SIZE_T)0;
    BOOL wow = FALSE, nativeWow = FALSE;
    MEMORY_BASIC_INFORMATION region;
    hVMM = (VMM_HANDLE)(ULONG_PTR)1;
    CHECK(hOpenProcess(0, FALSE, 123) == NULL);
    CHECK(hOpenProcess(0, FALSE, 43) == NULL);
    CHECK(hOpenProcess(0, FALSE, 42) == (HANDLE)(ULONG_PTR)42);
    CHECK(refreshes == 3);
    fakeProcessCount = 4;
    fakeProcesses[0].dwPID = 43; fakeProcesses[0].dwState = 1;
    strcpy_s(fakeProcesses[0].szNameLong, 64, "DD2.exe");
    fakeProcesses[1].dwPID = 42;
    strcpy_s(fakeProcesses[1].szNameLong, 64, "DD2.exe");
    fakeProcesses[2].dwPID = 44;
    strcpy_s(fakeProcesses[2].szNameLong, 64, "system");
    fakeProcesses[3].dwPID = 45; fakeProcesses[3].dwState = 1;
    strcpy_s(fakeProcesses[3].szNameLong, 64, "DD2.exe");
    HANDLE snapshot = hCreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    PROCESSENTRY32 entry = {0}; entry.dwSize = sizeof(entry);
    CHECK(snapshot && hProcess32First(snapshot, &entry));
    CHECK(entry.th32ProcessID == 42 && !strcmp(entry.szExeFile, "DD2.exe"));
    CHECK(entry.dwSize == sizeof(entry));
    CHECK(!hProcess32Next(snapshot, &entry));
    CHECK(!hProcess32Next((HANDLE)(ULONG_PTR)123, &entry));
    fakeProcessCount = 0;
    snapshot = hCreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    CHECK(snapshot && !hProcess32First(snapshot, &entry));
    refreshOK = FALSE;
    CHECK(!hCreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0));
    CHECK(!hOpenProcess(0, FALSE, 42));
    refreshOK = TRUE;
    pProcInfoAll = NULL;
    fakeProcessCount = 1;
    fakeProcesses[0].dwState = 0;
    strcpy_s(fakeProcesses[0].szNameLong, 64, "system");
    snapshot = hCreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    CHECK(!hProcess32First(snapshot, &entry));
    memset(fakeProcesses[0].szNameLong, 'X', 64);
    CHECK(hProcess32First(snapshot, &entry) && strlen(entry.szExeFile) == 64);
    pProcInfoAll = NULL;
    fakeModules = calloc(1, sizeof(*fakeModules) + sizeof(VMMDLL_MAP_MODULEENTRY));
    CHECK(fakeModules);
    snapshot = hCreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, 42);
    MODULEENTRY32 module = {0};
    CHECK(!hModule32First(snapshot, &module));
    fakeModules->cMap = 1;
    char longPath[400]; memset(longPath, 'P', sizeof(longPath) - 1); longPath[399] = 0;
    fakeModules->pMap[0].uszFullName = longPath;
    fakeModules->pMap[0].uszText = NULL;
    CHECK(hModule32First(snapshot, &module));
    CHECK(strlen(module.szExePath) == 259 && module.szModule[0] == 0);
    CHECK(module.dwSize == sizeof(module));
    CHECK(!hModule32Next(snapshot, &module));
    CHECK(!hModule32First((HANDLE)(ULONG_PTR)123, &module));
    pmModule = NULL; free(fakeModules); fakeModules = NULL;
    CHECK(hReadProcessMemory(GetCurrentProcess(), embeddedLua, buffer, sizeof(buffer), &done));
    CHECK(done == sizeof(buffer) && !strcmp(buffer, embeddedLua));
    CHECK(localReads == 1 && remoteReads == 0);
    CHECK(hWriteProcessMemory(GetCurrentProcess(), embeddedLua, "R", 1, &done));
    CHECK(embeddedLua[0] == 'R' && done == 1 && localWrites == 1 && remoteWrites == 0);
    CHECK(hVirtualQueryEx(GetCurrentProcess(), embeddedLua, &region, sizeof(region)) == sizeof(region));
    CHECK(IsWow64Process(GetCurrentProcess(), &nativeWow));
    CHECK(hIsWow64Process(GetCurrentProcess(), &wow) && wow == nativeWow);
    CHECK(!hIsWow64Process((HANDLE)(ULONG_PTR)42, NULL));
    //No process-list cache is populated: the hook must look up the PID directly.
    CHECK(pProcInfoAll == NULL);
    CHECK(hIsWow64Process((HANDLE)(ULONG_PTR)42, &wow) && wow);
    CHECK(!hIsWow64Process((HANDLE)(ULONG_PTR)123, &wow) && !wow);
    CHECK(hReadProcessMemory((HANDLE)(ULONG_PTR)42, (LPCVOID)0x1000, buffer, 1, &done));
    CHECK(done == 1 && buffer[0] == 'R' && remoteReads == 1);
    CHECK(hWriteProcessMemory((HANDLE)(ULONG_PTR)42, (LPCVOID)0x1000, buffer, 1, &done));
    CHECK(done == 1 && remoteWrites == 1);
    CHECK(!hReadProcessMemory((HANDLE)(ULONG_PTR)42, (LPCVOID)0x1000, buffer, (SIZE_T)MAXDWORD + 1, &done));
    CHECK(done == 0 && remoteReads == 1);
    hVMM = NULL;
    CHECK(!hReadProcessMemory((HANDLE)(ULONG_PTR)42, (LPCVOID)0x1000, buffer, 1, &done) && done == 0);
    CHECK(!hIsWow64Process((HANDLE)(ULONG_PTR)42, &wow));
    puts("PASS: process refresh, exited/invalid PID rejection, terminated filtering, empty/all-filtered lists, bounded process names, empty module maps, long/null module paths, invalid snapshots, and r2 memory/architecture checks. No DMA initialization.");
    return 0;
}
