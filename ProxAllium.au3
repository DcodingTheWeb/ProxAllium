; USE THIS PROGRAM AT YOUR OWN RISK
; THIS PROGRAM IS CURRENTLY AT VERY EARLY STAGES - Not suitable for normal use!
#include <Debug.au3>
#include "Tor.au3"

_DebugSetup("ProxAllium")
_DebugOut("Starting ProxAllium... Please wait")

Global Const $CONFIG_INI = @ScriptDir & '\config.ini'

Global $g_sTorPath = IniRead($CONFIG_INI, "tor", "path", @ScriptDir & '\Tor\tor.exe')
Global $g_sTorConfigFile = IniRead($CONFIG_INI, "tor", "config_file", @ScriptDir & '\Tor\config.torrc')

Global $g_aTorVersion = _Tor_SetPath($g_sTorPath)
_DebugOut("Using Tor " & $g_aTorVersion[$TOR_VERSION] & '.')

_DebugOut("Starting Tor...")
Global $g_aTorProcess = _Tor_Start($g_sTorConfigFile)
_DebugOut("Tor PID: " & $g_aTorProcess[$TOR_PROCESS_PID])
