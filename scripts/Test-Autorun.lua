-- Run from the workspace with the packaged Lua interpreter. No game access.
local function loadHandler(path, name)
  local f = assert(io.open(path, 'rb'))
  local content = f:read('*a')
  f:close()
  local chunk = assert(content:match('(function ' .. name .. '%(%)[\r\n].-\nend)'), name)
  assert(load(chunk, '@' .. path))()
end

java = { settings = { cbAlwaysShowMenu = { Checked = false } } }
miJavaTopMenuItem = { miActivate = {}, miDissectJavaClasses = {}, miJavaVariableScan = {} }
synchronize = function(f) f() end
getOpenedProcessID = function() return 1 end
getOperatingSystem = function() return 0 end
local monoDetected, dotnetDetected
mono_setMonoMenuItem = function(mono, dotnet)
  monoDetected, dotnetDetected = mono, dotnet
end

loadHandler('build/GHL/runtime/autorun/java.lua', 'java_OpenProcessAfterwards')
loadHandler('build/GHL/runtime/autorun/monoscript.lua', 'mono_OpenProcessMT')
local cases = {
  { name = 'nil modules', modules = nil },
  { name = 'empty modules', modules = {} },
  { name = 'native modules', modules = { { Name = 'DD2.exe' } } },
  { name = 'Java modules', modules = { { Name = 'jvm.dll' } } },
  { name = 'Mono modules', modules = { { Name = 'UnityPlayer.dll' } }, mono = true },
  { name = '.NET modules', modules = { { Name = 'clr.dll' } }, dotnet = true }
}
for _, case in ipairs(cases) do
  enumModules = function() return case.modules end
  java_classlist = { 'stale' }
  java_OpenProcessAfterwards()
  assert(java_classlist == nil, case.name .. ': stale Java class list')
  mono_OpenProcessMT()
  assert(monoDetected == (case.mono or false), case.name .. ': Mono detection')
  assert(dotnetDetected == (case.dotnet or false), case.name .. ': .NET detection')
  print('PASS: ' .. case.name)
end
