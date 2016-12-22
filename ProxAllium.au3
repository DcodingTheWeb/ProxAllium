; USE THIS PROGRAM AT YOUR OWN RISK
; THIS PROGRAM IS CURRENTLY AT VERY EARLY STAGES - Not suitable for normal use!
#include <EditConstants.au3>
#include <FontConstants.au3>
#include <GuiEdit.au3>
#include "Tor.au3"

GUI_CreateLogWindow()
GUI_LogOut("Starting ProxAllium... Please wait")

Global Const $CONFIG_INI = @ScriptDir & '\config.ini'

Global $g_sTorPath = IniRead($CONFIG_INI, "tor", "path", @ScriptDir & '\Tor\tor.exe')
Global $g_sTorConfigFile = IniRead($CONFIG_INI, "tor", "config_file", @ScriptDir & '\Tor\config.torrc')

Global $g_aTorVersion = _Tor_SetPath($g_sTorPath)
GUI_LogOut("Using Tor " & $g_aTorVersion[$TOR_VERSION] & '.')

GUI_LogOut("Starting Tor...")
Global $g_aTorProcess = _Tor_Start($g_sTorConfigFile)
GUI_LogOut("Tor PID: " & $g_aTorProcess[$TOR_PROCESS_PID])

#Region GUI
Func GUI_CreateLogWindow()
	Local Const $eiGuiWidth = 580, $eiGuiHeight = 280
	Global $g_hLogGUI = GUICreate("ProxAllium", $eiGuiWidth, $eiGuiHeight)
	Global $g_idLogCtrl = GUICtrlCreateEdit("", 0, 0, $eiGuiWidth, $eiGuiHeight, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL))
	Global $g_hLogCtrl = GUICtrlGetHandle($g_idLogCtrl) ; Get the handle of the Edit control for future use in GUI_LogOut
	GUICtrlSetFont($g_idLogCtrl, Default, Default, Default, "Consolas")
	GUISetState() ; Make the GUI visible
EndFunc

Func GUI_LogOut($sText)
	_GUICtrlEdit_AppendText($g_hLogCtrl, $sText & @CRLF)
EndFunc
#EndRegion
