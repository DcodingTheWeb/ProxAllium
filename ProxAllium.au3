#NoTrayIcon

#Region AutoIt3Wrapper Directives
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Outfile=Builds\ProxAllium.exe
#AutoIt3Wrapper_Res_Description=ProxAllium - Tor Proxy Bundle
#AutoIt3Wrapper_Res_Fileversion=0.3.0.0
#AutoIt3Wrapper_Res_ProductVersion=0.3.0.0
#AutoIt3Wrapper_Res_LegalCopyright=Dcoding The Web
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/sf /sv /mo /rm
#EndRegion AutoIt3Wrapper Directives

#Region Includes
#include <Array.au3>
#include <Color.au3>
#include <ColorConstants.au3>
#include <Date.au3>
#include <EditConstants.au3>
#include <FileConstants.au3>
#include <FontConstants.au3>
#include <GuiEdit.au3>
#include <Misc.au3>
#include <MsgBoxConstants.au3>
#include <StringConstants.au3>
#include <TrayConstants.au3>
#include <WinAPIFiles.au3>
#include "Tor.au3"
#include "IniReadWrite.au3"
#EndRegion Includes

#Region Multi-Instance Handler
Handle_MultipleInstance()
#EndRegion Multi-Instance Handler

#Region Variable Initialization
Global $g_aTorProcess[2]
Global $g_aTorVersion[0]

#Region Read Configuration
Global Const $CONFIG_INI = @ScriptDir & '\config.ini'

Global $g_sTorPath = _WinAPI_GetFullPathName(IniReadWrite($CONFIG_INI, "tor", "path", 'Tor\tor.exe'))
Global $g_sTorConfigFile = _WinAPI_GetFullPathName(IniReadWrite($CONFIG_INI, "tor", "config_file", 'config.torrc'))
Global $g_sTorDataDirPath = _WinAPI_GetFullPathName(IniReadWrite($CONFIG_INI, "tor", "data_dir", 'Tor Data'))
Global $g_sTorGeoIPv4File = _WinAPI_GetFullPathName(IniReadWrite($CONFIG_INI, "tor", "geoip4_file", 'Tor\geoip'))
Global $g_sTorGeoIPv6File = _WinAPI_GetFullPathName(IniReadWrite($CONFIG_INI, "tor", "geoip6_file", 'Tor\geoip6'))
Global $g_iOutputPollInterval = Int(IniReadWrite($CONFIG_INI, "proxallium", "output_poll_interval", "100"))

Global $g_sTorConfig_Port = IniReadWrite($CONFIG_INI, "tor_config", "port", "9050")
Global $g_bTorConfig_OnlyLocalhost = (IniReadWrite($CONFIG_INI, "tor_config", "localhost_only", "true") = "true")
Global $g_sTorConfig_ExitNodeCC = IniRead($CONFIG_INI, "tor_config", "exit_node_country_code", "")

Global $g_sTorConfig_ProxyType = IniRead($CONFIG_INI, "proxy", "type", "")
Global $g_sTorConfig_ProxyHost = IniRead($CONFIG_INI, "proxy", "host", "")
Global $g_sTorConfig_ProxyPort = IniRead($CONFIG_INI, "proxy", "port", "")
Global $g_sTorConfig_ProxyUser = IniRead($CONFIG_INI, "proxy", "user", "")
Global $g_sTorConfig_ProxyPass = IniRead($CONFIG_INI, "proxy", "pass", "")

Global $g_bTorConfig_BridgesEnabled = (IniRead($CONFIG_INI, "bridges", "enabled", "false") = "true")
Global $g_sTorConfig_BridgesPath = _WinAPI_GetFullPathName(IniRead($CONFIG_INI, "bridges", "path", $g_sTorDataDirPath & '\bridges.txt'))
#EndRegion Read Configuration

#EndRegion Variable Initialization

#Region Tray Creation
Opt("TrayMenuMode", 1 + 2) ; No default menu and automatic checkmarks
Opt("TrayOnEventMode", 1) ; OnEvent mode
Opt("TrayAutoPause", 0) ; No Auto-Pause

TraySetClick(16) ; Will display the menu when releasing the secondary mouse button
TraySetOnEvent($TRAY_EVENT_PRIMARYDOWN, "GUI_ToggleMainWindow")
TrayItemSetState(TrayCreateItem("ProxAllium"), $TRAY_DISABLE)
TrayCreateItem("")
Global $g_idTrayMainWinToggle = TrayCreateItem("Hide Main Window")
TrayItemSetOnEvent($g_idTrayMainWinToggle, "GUI_ToggleMainWindow")
Global $g_idTrayTorOutputToggle = TrayCreateItem("Show Tor Output")
TrayItemSetOnEvent($g_idTrayTorOutputToggle, "GUI_ToggleTorOutputWindow")
TrayCreateItem("")
Global $g_idTrayToggleTor = TrayCreateItem("Stop Tor")
TrayItemSetOnEvent($g_idTrayToggleTor, "Tor_Toggle")
TrayCreateItem("")
TrayItemSetOnEvent(TrayCreateItem("Exit"), "GUI_MainWindowExit")
TraySetState($TRAY_ICONSTATE_SHOW)
TraySetToolTip("ProxAllium")
#EndRegion Tray Creation

#Region GUI Creation
Opt("GUIOnEventMode", 1)
GUI_CreateMainWindow()
GUI_LogOut("Starting ProxAllium... Please wait :)")
GUI_CreateTorOutputWindow()
GUI_CreateBridges()

Func GUI_CreateMainWindow()
	Global $g_hMainGUI = GUICreate("ProxAllium", 580, 370)
	GUISetOnEvent($GUI_EVENT_CLOSE, "GUI_MainWindowExit", $g_hMainGUI)
	GUISetOnEvent($GUI_EVENT_MINIMIZE, "GUI_ToggleMainWindow", $g_hMainGUI)
	GUICtrlCreateMenu("ProxAllium")
	GUICtrlSetState(-1, $GUI_DISABLE)
	Local $idMenuView = GUICtrlCreateMenu("View")
	GUICtrlCreateMenuItem("Hide Main Window", $idMenuView)
	GUICtrlSetOnEvent(-1, "GUI_ToggleMainWindow")
	Global $g_idMainGUI_MenuToggleTorOutput = GUICtrlCreateMenuItem("Show Tor Output", $idMenuView)
	GUICtrlSetOnEvent(-1, "GUI_ToggleTorOutputWindow")
	Local $idMenuOptions = GUICtrlCreateMenu("Options")
	Global $g_idMainGUI_MenuBridges = GUICtrlCreateMenuItem("Bridges", $idMenuOptions)
	GUICtrlSetOnEvent(-1, "GUI_BridgeHandler")
	GUICtrlCreateMenuItem("", $idMenuOptions)
	Global $g_idMainGUI_MenuRegenConfig = GUICtrlCreateMenuItem("Regenerate Tor configuration", $idMenuOptions)
	GUICtrlSetOnEvent(-1, "GUI_RegenerateTorrc")
	GUICtrlCreateGroup("Proxy Details", 5, 5, 570, 117)
	GUICtrlCreateLabel("Hostname:", 10, 27, 60, 15)
	Global $g_idMainGUI_Hostname = GUICtrlCreateInput("localhost", 73, 22, 497, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, $COLOR_WHITE)
	GUICtrlCreateLabel("IP Address:", 10, 52, 60, 15)
	Global $g_idMainGUI_IPAddress = GUICtrlCreateInput("127.0.0.1", 73, 47, 497, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, $COLOR_WHITE)
	GUICtrlCreateLabel("Port:", 10, 77, 60, 15)
	Global $g_idMainGUI_Port = GUICtrlCreateInput('...', 73, 72, 497, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, $COLOR_WHITE)
	GUICtrlCreateLabel("Proxy Type:", 10, 102, 60, 15)
	GUICtrlCreateInput("SOCKS5", 73, 97, 497, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, $COLOR_WHITE)
	GUICtrlCreateGroup("Tor Details", 5, 125, 570, 64)
	GUICtrlCreateLabel("Tor PID:", 10, 144, 60, 15)
	Global $g_idMainGUI_TorPID = GUICtrlCreateInput('...', 73, 139, 497, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, $COLOR_WHITE)
	GUICtrlCreateLabel("Tor Version:", 10, 169, 60, 15)
	Global $g_idMainGUI_TorVersion = GUICtrlCreateInput('...', 73, 164, 497, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, $COLOR_WHITE)
	GUICtrlCreateGroup("Control Panel", 5, 192, 570, 42)
	GUICtrlCreateLabel("Status:", 10, 213, 33, 15)
	Global $g_idMainGUI_Status = GUICtrlCreateInput('...', 48, 208, 438, 20, BitOr($ES_CENTER, $ES_READONLY), $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, $COLOR_WHITE)
	Global $g_idMainGUI_ToggleButton = GUICtrlCreateButton('...', 489, 207, 82, 22)
	GUICtrlSetState(-1, $GUI_DISABLE)
	GUICtrlSetOnEvent(-1, "Tor_Toggle")
	Global $g_idMainGUI_Log = GUICtrlCreateEdit("", 5, 238, 570, 107, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL))
	Global $g_hMainGUI_Log = GUICtrlGetHandle($g_idMainGUI_Log)
	GUICtrlSetFont($g_idMainGUI_Log, 9, Default, Default, "Consolas")
	GUICtrlSetBkColor($g_idMainGUI_Log, $COLOR_WHITE)
	GUISetState(@SW_SHOW, $g_hMainGUI) ; Make the GUI visible
EndFunc

Func GUI_LogOut($sText, $bEOL = True)
	If $bEOL Then $sText &= @CRLF
	_GUICtrlEdit_AppendText($g_hMainGUI_Log, $sText)
	ConsoleWrite($sText)
EndFunc

Func GUI_SetStatus($sStatus = '...')
	GUICtrlSetData($g_idMainGUI_Status, $sStatus)
EndFunc

Func GUI_CreateTorOutputWindow()
	Local Const $eiGuiWidth = 580, $eiGuiHeight = 280
	Global $g_hTorGUI = GUICreate("Tor Output", $eiGuiWidth, $eiGuiHeight, Default, Default, $WS_OVERLAPPEDWINDOW)
	GUISetOnEvent($GUI_EVENT_CLOSE, "GUI_ToggleTorOutputWindow")
	GUISetOnEvent($GUI_EVENT_MINIMIZE, "GUI_ToggleTorOutputWindow")
	Global $g_idTorOutput = GUICtrlCreateEdit("", 0, 0, $eiGuiWidth, $eiGuiHeight, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL))
	Global $g_hTorOutput = GUICtrlGetHandle($g_idTorOutput) ; Get the handle of the Edit control for future use in the Tor Output Handler
	GUICtrlSetFont($g_idTorOutput, 9, Default, Default, "Consolas")
	GUICtrlSetBkColor($g_idTorOutput, $COLOR_BLACK)
	Local $aGrayCmdColor[3] = [197, 197, 197] ; CMD Text Color's combination in RGB
	Local Const $iGrayCmdColor = _ColorSetRGB($aGrayCmdColor) ; Get the RGB code of CMD Text Color
	GUICtrlSetColor($g_idTorOutput, $iGrayCmdColor)
EndFunc

Func GUI_CreateBridges()
	Global $g_hBridgesGUI = GUICreate("Bridges", 515, 245, -1, -1, -1, -1, $g_hMainGUI)
	GUISetOnEvent($GUI_EVENT_CLOSE, GUI_BridgeHandler, $g_hBridgesGUI)
	GUICtrlCreateLabel("Bridges Status: ", 5, 13, 78, 17)
	Global $g_idBridgeStatus = GUICtrlCreateLabel("", 78, 13, 47, 17)
	Global $g_idBridgesToggle = GUICtrlCreateButton("", 128, 4, 59, 24)
	Global $g_idBridgesSave = GUICtrlCreateButton("Save", 411, 4, 100, 24)
	Global $g_idBridgesEdit = GUICtrlCreateEdit("", 5, 32, 505, 208)

	GUICtrlSetFont($g_idBridgeStatus, 8.5, $FW_BOLD)
	GUICtrlSetFont($g_idBridgesEdit, 9, Default, Default, "Consolas")

	GUICtrlSetOnEvent($g_idBridgesToggle, GUI_BridgeHandler)
	GUICtrlSetOnEvent($g_idBridgesSave, GUI_BridgeHandler)

	Local $sBridges = FileRead($g_sTorConfig_BridgesPath)
	If Not @error Then GUICtrlSetData($g_idBridgesEdit, $sBridges)
	GUICtrlSetTip($g_idBridgesEdit, "Paste your bridge lines here (one per line)", "Bridges", $TIP_INFOICON)

	GUI_BridgeHandler($g_idBridgesToggle) ; Initialize the GUI
EndFunc
#EndRegion GUI Functions

#Region Main Script
If Not FileExists($g_sTorConfigFile) Then
	GUI_LogOut("Cannot find Tor configuration file, generating one now... ", False)
	Core_GenTorrc()
	If @error Then Core_WaitForExit("Failed to create configuration file!")
	GUI_LogOut("Successfully generated Tor configuration file!")
EndIf

Tor_Initialize()
If Not @error Then Tor_Start()

Core_Idle()
#EndRegion Main Script

#Region Functions

#Region GUI Handlers Functions
Func GUI_MainWindowExit()
	Local $iMsgBoxFlags = $MB_YESNO + $MB_ICONQUESTION
	Local $sMsgBoxTitle = "Close ProxAllium"
	Local $sMsgBoxMsg = "Do you really want to close ProxAllium?"
	Local $iButtonID = MsgBox($iMsgBoxFlags, $sMsgBoxTitle, $sMsgBoxMsg)
	If $iButtonID = $IDNO Then Return
	If IsTorRunning() Then Tor_Stop()
	Exit
EndFunc

Func GUI_ToggleTorOutputWindow()
	Local Static $bHidden = True
	If $bHidden Then
		$bHidden = Not (GUISetState(@SW_SHOWNORMAL, $g_hTorGUI) = 1)
		If Not $bHidden Then
			TrayItemSetText($g_idTrayTorOutputToggle, "Hide Tor Output")
			GUICtrlSetData($g_idMainGUI_MenuToggleTorOutput, "Hide Tor Output")
		EndIf
		Return
	EndIf
	$bHidden = (GUISetState(@SW_HIDE, $g_hTorGUI) = 1)
	If $bHidden Then
		TrayItemSetText($g_idTrayTorOutputToggle, "Show Tor Output")
		GUICtrlSetData($g_idMainGUI_MenuToggleTorOutput, "Show Tor Output")
	EndIf
EndFunc

Func GUI_ToggleMainWindow()
	Local Static $bHidden = False
	If $bHidden Then
		$bHidden = Not (GUISetState(@SW_SHOWNORMAL, $g_hMainGUI) = 1)
		If Not $bHidden Then TrayItemSetText($g_idTrayMainWinToggle, "Hide Main Window")
		Return
	EndIf
	$bHidden = (GUISetState(@SW_HIDE, $g_hMainGUI) = 1)
	If $bHidden Then TrayItemSetText($g_idTrayMainWinToggle, "Show Main Window")
EndFunc

Func GUI_BridgeHandler($iCtrlID = Default)
	Local Static $bNotInitialized = True
	If $bNotInitialized Then
		$g_bTorConfig_BridgesEnabled = ($g_bTorConfig_BridgesEnabled ? False : True)
		$bNotInitialized = False
	EndIf
	Local Static $bModified
	Switch (IsDeclared("iCtrlID") = $DECLARED_LOCAL ? $iCtrlID : @GUI_CtrlId)
		Case $GUI_EVENT_CLOSE
			If $bModified Or (_GUICtrlEdit_GetModify($g_idBridgesEdit)) Then
				If MsgBox($MB_ICONQUESTION + $MB_YESNO + $MB_DEFBUTTON2, "Unsaved changes", "You have made some changes, are you sure that you want to exit without saving them to disk?") = $IDNO Then Return
			EndIf
			GUISetState(@SW_HIDE, $g_hBridgesGUI)
		Case $g_idMainGUI_MenuBridges
			_GUICtrlEdit_SetModify($g_idBridgesEdit, False)
			$bModified = False
			GUISetState(@SW_SHOW, $g_hBridgesGUI)
		Case $g_idBridgesToggle
			$bModified = True
			If $g_bTorConfig_BridgesEnabled Then
				$g_bTorConfig_BridgesEnabled = False
				GUICtrlSetData($g_idBridgeStatus, "Disabled")
				GUICtrlSetData($g_idBridgesToggle, "Enable")
				GUICtrlSetColor($g_idBridgeStatus, $COLOR_RED)
			Else
				$g_bTorConfig_BridgesEnabled = True
				GUICtrlSetData($g_idBridgeStatus, "Enabled")
				GUICtrlSetData($g_idBridgesToggle, "Disable")
				GUICtrlSetColor($g_idBridgeStatus, $COLOR_GREEN)
			EndIf
		Case $g_idBridgesSave
			Local $hFile = FileOpen($g_sTorConfig_BridgesPath, $FO_OVERWRITE + $FO_CREATEPATH)
			If $hFile = -1 Then
				MsgBox($MB_ICONERROR, "Failed to open", "Failed to open/create the bridges files for writing!")
				Return
			EndIf
			If FileWrite($hFile, GUICtrlRead($g_idBridgesEdit)) = 0 Then
				MsgBox($MB_ICONERROR, "Failed to write", "Failed to write to the bridges files!")
				Return
			EndIf
			$bModified = False
			_GUICtrlEdit_SetModify($g_idBridgesEdit, False)
			IniWrite($CONFIG_INI, "bridges", "enabled", StringLower($g_bTorConfig_BridgesEnabled))
			MsgBox($MB_ICONINFORMATION, "Saved", "Settings for bridges have been save successfully!")
	EndSwitch
EndFunc

Func GUI_RegenerateTorrc()
	GUI_LogOut("Regenerating Tor configuration... ", False)
	Core_GenTorrc()
	If @error Then
		GUI_LogOut("Failed! (Error Code: " & @error & ')')
	Else
		GUI_LogOut("Done!")
		Local $sMessage = "ProxAllium has generated a new configuration, do you want to restart Tor make the changes take effect?"
		If IsTorRunning() And MsgBox($MB_ICONQUESTION + $MB_YESNO, "Do you want to restart Tor?", $sMessage) = $IDYES Then
			Tor_Stop()
			Tor_Start()
		EndIf
	EndIf
EndFunc
#EndRegion GUI Handlers

#Region Event Handler Functions
Func Handle_MultipleInstance()
	If _Singleton(StringReplace(@ScriptFullPath, '\', '/'), 1) = 0 Then
		Local $iMsgBoxParams = $MB_ICONWARNING + $MB_YESNO + $MB_DEFBUTTON2
		Local $sMsgBoxMsg = "ProxAllium seems to be already running, do you still want to create a new instance?"
		Local $iUserChoice = MsgBox($iMsgBoxParams, "ProxAllium is already running!", $sMsgBoxMsg)
		If $iUserChoice = $IDYES Then Return
		Exit
	EndIf
EndFunc

Func Handle_TorOutput()
	Local $aCallbackFuncs = [Handle_Bootstrap, Handle_WarningAndError]
	Local $sPartialTorOutput = ""
	Local $aPartialTorOutput[0]
	While IsTorRunning() ; Loop until Tor is dead
		Sleep($g_iOutputPollInterval) ; Don't kill the CPU
		$sPartialTorOutput = StdoutRead($g_aTorProcess[$TOR_PROCESS_PID])
		If $sPartialTorOutput = "" Then ContinueLoop
		_GUICtrlEdit_AppendText($g_hTorOutput, $sPartialTorOutput)
		$aPartialTorOutput = StringSplit(StringStripWS($sPartialTorOutput, $STR_STRIPTRAILING), @CRLF, $STR_ENTIRESPLIT)
		For $iLine = 1 To $aPartialTorOutput[0]
			For $fuCallbackFunc In $aCallbackFuncs
				$fuCallbackFunc(StringSplit($aPartialTorOutput[$iLine], ' '))
			Next
		Next
	WEnd
	Local $iExitCode = _Process_GetExitCode($g_aTorProcess[$TOR_PROCESS_HANDLE])
	GUI_SetStatus("Stopped")
	Local $bUnexpected = Not IsMgcNumPresent($GUI_DISABLE, GUICtrlGetState($g_idMainGUI_ToggleButton))
	If $bUnexpected Then
		_Tor_Stop($g_aTorProcess)
		GUI_LogOut("Tor has exited unexpectedly with exit code: " & $iExitCode)
		TrayTip("Tor exited unexpectedly!", "Tor has exited with exit code: " & $iExitCode, 10, $TIP_ICONEXCLAMATION)
	Else
		GUICtrlSetState($g_idMainGUI_ToggleButton, $GUI_ENABLE)
		GUI_LogOut("Tor exited with exit code: " & $iExitCode)
		TrayTip("Tor has exited", "Tor has exited with exit code: " & $iExitCode, 10, $TIP_ICONASTERISK + $TIP_NOSOUND)
	EndIf
	TrayItemSetText($g_idTrayToggleTor, "Start Tor")
	GUICtrlSetData($g_idMainGUI_ToggleButton, "Start")
	GUICtrlSetData($g_idMainGUI_TorPID, '...')
EndFunc

Func Handle_WarningAndError(ByRef $aTorOutput)
	If ($aTorOutput[4] = '[warn]') Or ($aTorOutput[3] = '[err]') Then
		If $aTorOutput[5] = "Path" Then Return
		GUI_LogOut(_ArrayToString($aTorOutput, ' ', 5))
	EndIf
EndFunc

Func Handle_Bootstrap(ByRef $aTorOutput)
	If Not ($aTorOutput[0] >= 7 And $aTorOutput[5] = "Bootstrapped") Then Return
	Local $iPercentage = Int($aTorOutput[6])
	If $iPercentage = 0 Then GUI_LogOut("Trying to build a circuit, please wait...")
	Local $sText = _ArrayToString($aTorOutput, ' ', 5)
	GUI_SetStatus($sText)
	GUI_LogOut($sText)
	If $iPercentage = 100 Then
		GUI_SetStatus("Running")
		GUI_LogOut("Successfully built a circuit, Tor is now ready for use!")
		GUICtrlSetData($g_idMainGUI_Port, $g_sTorConfig_Port)
		TrayTip("Tor is ready", "Tor has successfully built a circuit, you can now start using the proxy!", 10, $TIP_ICONASTERISK)
	EndIf
EndFunc
#EndRegion Misc. Functions

#Region Core Functions
Func Core_WaitForExit($sLogText = "")
	If Not $sLogText = "" Then GUI_LogOut($sLogText)
	GUI_LogOut("ProxAllium now ready to exit...")
	GUI_LogOut("Close the window by clicking X to exit ProxAllium!")
	Core_Idle()
EndFunc

Func Core_Idle()
	Do
		If IsTorRunning() Then Handle_TorOutput()
		Sleep($g_iOutputPollInterval)
	Until False
EndFunc

Func Core_GenTorrc()
	Local $hTorrc = FileOpen($g_sTorConfigFile, $FO_APPEND + $FO_CREATEPATH)
	If @error Then Return SetError(1, 0, False)
	FileSetPos($hTorrc, 0, $FILE_BEGIN)
	Local $aTorrc = FileReadToArray($hTorrc)
	Local $sCustomConfig
	If Not @error Then
		For $iLine = 0 To @extended - 1
			If StringLeft($aTorrc[$iLine], 2) = '#~' Then
				$sCustomConfig = _ArrayToString($aTorrc, @CRLF, $iLine + 1)
				ExitLoop
			EndIf
		Next
	EndIf
	FileSetPos($hTorrc, 0, $FILE_BEGIN)
	FileWriteLine($hTorrc, '## Configuration file automatically generated by ProxAllium')
	FileWriteLine($hTorrc, '## This file was generated on ' & _Now())
	FileWriteLine($hTorrc, "")
	FileWriteLine($hTorrc, '## Open SOCKS proxy on the following port')
	FileWriteLine($hTorrc, 'SOCKSPort ' & $g_sTorConfig_Port)
	FileWriteLine($hTorrc, "")
	If $g_bTorConfig_OnlyLocalhost Then
		FileWriteLine($hTorrc, '## Only accept connections from localhost')
		FileWriteLine($hTorrc, 'SOCKSPolicy accept 127.0.0.1')
		FileWriteLine($hTorrc, 'SOCKSPolicy accept6 [::1]')
		FileWriteLine($hTorrc, 'SOCKSPolicy reject *')
		FileWriteLine($hTorrc, "")
	EndIf
	FileWriteLine($hTorrc, '## GeoIP Files')
	FileWriteLine($hTorrc, 'GeoIPFile ' & $g_sTorGeoIPv4File)
	FileWriteLine($hTorrc, 'GeoIPv6File ' & $g_sTorGeoIPv6File)
	FileWriteLine($hTorrc, "")
	FileWriteLine($hTorrc, '## Data Directory')
	FileWriteLine($hTorrc, 'DataDirectory ' & $g_sTorDataDirPath)
	FileWriteLine($hTorrc, "")
	If Not $g_sTorConfig_ProxyType = "" Then
		FileWriteLine($hTorrc, "## Proxy Settings for Tor (not Tor's proxy settings)")
		Local $sProxySettings
		Switch $g_sTorConfig_ProxyType
			Case "http"
				$sProxySettings &= "HTTPProxy " & $g_sTorConfig_ProxyHost
				$sProxySettings &= ($g_sTorConfig_ProxyPort = "") ? "" : (':' & $g_sTorConfig_ProxyPort)
				$sProxySettings &= @CRLF
				If Not $g_sTorConfig_ProxyUser = "" Then $sProxySettings &= "HTTPProxyAuthenticator " & $g_sTorConfig_ProxyUser & ':' & $g_sTorConfig_ProxyPass & @CRLF

			Case "https"
				$sProxySettings &= "HTTPSProxy " & $g_sTorConfig_ProxyHost
				$sProxySettings &= ($g_sTorConfig_ProxyPort = "") ? "" : (':' & $g_sTorConfig_ProxyPort)
				$sProxySettings &= @CRLF
				If Not $g_sTorConfig_ProxyUser = "" Then $sProxySettings &= "HTTPSProxyAuthenticator " & $g_sTorConfig_ProxyUser & ':' & $g_sTorConfig_ProxyPass & @CRLF

			Case "socks4"
				$sProxySettings &= "Socks4Proxy " & $g_sTorConfig_ProxyHost
				$sProxySettings &= ($g_sTorConfig_ProxyPort = "") ? "" : (':' & $g_sTorConfig_ProxyPort)
				$sProxySettings &= @CRLF

			Case "socks5"
				$sProxySettings &= "Socks5Proxy " & $g_sTorConfig_ProxyHost
				$sProxySettings &= ($g_sTorConfig_ProxyPort = "") ? "" : (':' & $g_sTorConfig_ProxyPort)
				$sProxySettings &= @CRLF
				If Not $g_sTorConfig_ProxyUser = "" Then $sProxySettings &= "Socks5ProxyUsername " & $g_sTorConfig_ProxyUser & @CRLF
				If Not $g_sTorConfig_ProxyPass = "" Then $sProxySettings &= "Socks5ProxyPassword " & $g_sTorConfig_ProxyPass & @CRLF

			Case Else
				$sProxySettings &= '## Unknown proxy type detected!? Cannot generate config :('
		EndSwitch
		FileWriteLine($hTorrc, $sProxySettings)
		FileWriteLine($hTorrc, "")
	EndIf
	If Not $g_sTorConfig_ExitNodeCC = "" Then
		FileWriteLine($hTorrc, '## Country of the Exit Node')
		FileWriteLine($hTorrc, 'ExitNodes {' & $g_sTorConfig_ExitNodeCC & '}')
		FileWriteLine($hTorrc, "StrictNodes 1")
		FileWriteLine($hTorrc, "")
	EndIf
	If $g_bTorConfig_BridgesEnabled Then
		FileWriteLine($hTorrc, '## Bridges')
		FileWriteLine($hTorrc, 'UseBridges 1')
		Local $aBridges = StringSplit(StringStripCR(GUICtrlRead($g_idBridgesEdit)), @LF)
		For $iBridge = 1 To $aBridges[0]
			If Not StringIsSpace($aBridges[$iBridge]) Then FileWriteLine($hTorrc, 'Bridge ' & $aBridges[$iBridge]) ; Skip blank lines
		Next
		FileWriteLine($hTorrc, "")
	EndIf
	FileWriteLine($hTorrc, '###########################################################')
	FileWriteLine($hTorrc, '###### STORE YOUR CUSTOM CONFIGURATION ENTRIES BELOW ######')
	FileWriteLine($hTorrc, '##### THEY WILL BE PRESERVED ACROSS CHANGES IN CONFIG #####')
	FileWriteLine($hTorrc, '###########################################################')
	FileWriteLine($hTorrc, '#~ I (this line) am used to identify the start of custom entries, so please do not touch me :)')
	FileWriteLine($hTorrc, $sCustomConfig)
	FileSetEnd($hTorrc)
	FileClose($hTorrc)
EndFunc

Func IsTorRunning()
	Return ProcessExists($g_aTorProcess[$TOR_PROCESS_PID]) <> 0
EndFunc
#EndRegion Core Functions

#Region Tor Functions
Func Tor_Initialize()
	GUI_SetStatus("Initializing Tor...")
	GUICtrlSetData($g_idMainGUI_TorVersion, "Detecting...")
	Local $aTorVersion = _Tor_SetPath($g_sTorPath)
	Local $iError = @error
	GUI_SetStatus()
	If Not $iError Then
		$g_aTorVersion = $aTorVersion
		GUI_LogOut("Detected Tor version: " & $g_aTorVersion[$TOR_VERSION])
		GUICtrlSetData($g_idMainGUI_TorVersion, $g_aTorVersion[$TOR_VERSION])
		Return True
	EndIf
	GUICtrlSetData($g_idMainGUI_TorVersion, '...')
	Switch $iError
		Case $TOR_ERROR_GENERIC
			GUI_LogOut("Cannot find Tor!")

		Case $TOR_ERROR_VERSION
			GUI_LogOut("Unable to identify Tor's version!")
	EndSwitch
	Return SetError($iError)
EndFunc

Func Tor_Start()
	GUICtrlSetState($g_idMainGUI_ToggleButton, $GUI_DISABLE)
	GUI_SetStatus("Starting Tor...")
	GUI_LogOut("Starting Tor... ", False)
	Local $aTorProcess = _Tor_Start($g_sTorConfigFile)
	Local $iError = @error
	GUICtrlSetState($g_idMainGUI_ToggleButton, $GUI_ENABLE)
	If $iError Then
		GUI_SetStatus()
		Switch $iError
			Case $TOR_ERROR_PROCESS
				GUI_LogOut("Unable to start Tor!")

			Case $TOR_ERROR_CONFIG
				GUI_LogOut("Invalid Tor configuration, please check your custom entries.")
		EndSwitch
		Return SetError($iError, 0, False)
	EndIf
	$g_aTorProcess = $aTorProcess
	TrayItemSetText($g_idTrayToggleTor, "Stop Tor")
	GUICtrlSetData($g_idMainGUI_ToggleButton, "Stop")
	GUI_SetStatus("Waiting for Tor...")
	GUI_LogOut("Started Tor with PID: " & $g_aTorProcess[$TOR_PROCESS_PID])
	GUICtrlSetData($g_idMainGUI_TorPID, $g_aTorProcess[$TOR_PROCESS_PID])
	GUICtrlSetData($g_idTorOutput, "") ; Reset the Tor Output
	Return True
EndFunc

Func Tor_Stop()
	GUICtrlSetState($g_idMainGUI_ToggleButton, $GUI_DISABLE)
	GUI_LogOut("Trying to stop Tor... ", False)
	GUI_SetStatus("Stopping Tor...")
	If Not ProcessExists($g_aTorProcess[$TOR_PROCESS_PID]) Then
		GUI_LogOut("but Tor is already stopped!")
		Return True
	EndIf
	_Tor_Stop($g_aTorProcess)
	If @error Then
		Local $iError = @extended
		GUI_LogOut("Failed to stop Tor (Error Code: " & $iError & ')')
		Return SetError($iError, 0, False)
	EndIf
	GUI_LogOut("Successfully stopped Tor!")
	Return True
EndFunc

Func Tor_Toggle()
	If IsTorRunning() Then
		Tor_Stop()
	Else
		Tor_Start()
	EndIf
EndFunc
#EndRegion Tor Functions

#EndRegion Functions
