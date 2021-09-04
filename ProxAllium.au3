#NoTrayIcon

#Region AutoIt3Wrapper Directives
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Outfile=Builds\ProxAllium.exe
#AutoIt3Wrapper_Res_Description=ProxAllium - Tor Proxy Bundle
#AutoIt3Wrapper_Res_Fileversion=0.4.2.0
#AutoIt3Wrapper_Res_ProductVersion=0.4.2.0
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
#include <WinAPIShellEx.au3>
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

Global $g_sTorPath = IniReadWrite($CONFIG_INI, "tor", "path", 'Tor\tor.exe')
Global $g_sObfs4Path = IniReadWrite($CONFIG_INI, "tor", "obfs4_path", 'Tor\PluggableTransports\obfs4\obfs4proxy.exe')
Global $g_sSnowflakePath = IniReadWrite($CONFIG_INI, "tor", "snowflake_path", 'Tor\PluggableTransports\snowflake-client.exe')
Global $g_sSnowflakeArgs = IniReadWrite($CONFIG_INI, "tor", "snowflake_args", '-url=https://snowflake-broker.torproject.net.global.prod.fastly.net/ -front=cdn.sstatic.net -ice=stun:stun.voip.blackberry.com:3478,stun:stun.altar.com.pl:3478,stun:stun.antisip.com:3478,stun:stun.bluesip.net:3478,stun:stun.dus.net:3478,stun:stun.epygi.com:3478,stun:stun.sonetel.com:3478,stun:stun.sonetel.net:3478,stun:stun.stunprotocol.org:3478,stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478,stun:stun.voys.nl:3478')
Global $g_sTorConfigFile = IniReadWrite($CONFIG_INI, "tor", "config_file", 'config.torrc')
Global $g_sTorDataDirPath = IniReadWrite($CONFIG_INI, "tor", "data_dir", 'Tor Data')
Global $g_sTorGeoIPv4File = IniReadWrite($CONFIG_INI, "tor", "geoip4_file", 'Tor\geoip')
Global $g_sTorGeoIPv6File = IniReadWrite($CONFIG_INI, "tor", "geoip6_file", 'Tor\geoip6')
Global $g_iOutputPollInterval = Int(IniReadWrite($CONFIG_INI, "proxallium", "output_poll_interval", "100"))

Global $g_sTorConfig_Port = IniReadWrite($CONFIG_INI, "tor_config", "port", "9050")
Global $g_sTorConfig_TunnelPort = IniRead($CONFIG_INI, "tor_config", "tunnel_port", "")
Global $g_sTorConfig_ControlPort = IniReadWrite($CONFIG_INI, "tor_config", "control_port", "9051")
Global $g_sTorConfig_ControlPass = IniReadWrite($CONFIG_INI, "tor_config", "control_pass", String(Random(100000, 999999, 1)))
Global $g_bTorConfig_OnlyLocalhost = (IniReadWrite($CONFIG_INI, "tor_config", "localhost_only", "true") = "true")
Global $g_sTorConfig_ExitNodeCC = IniRead($CONFIG_INI, "tor_config", "exit_node_country_code", "")

Global $g_sTorConfig_ProxyType = IniRead($CONFIG_INI, "proxy", "type", "")
Global $g_sTorConfig_ProxyHost = IniRead($CONFIG_INI, "proxy", "host", "")
Global $g_sTorConfig_ProxyPort = IniRead($CONFIG_INI, "proxy", "port", "")
Global $g_sTorConfig_ProxyUser = IniRead($CONFIG_INI, "proxy", "user", "")
Global $g_sTorConfig_ProxyPass = IniRead($CONFIG_INI, "proxy", "pass", "")

Global $g_bTorConfig_BridgesEnabled = (IniRead($CONFIG_INI, "bridges", "enabled", "false") = "true")
Global $g_sTorConfig_BridgesPath = IniRead($CONFIG_INI, "bridges", "path", $g_sTorDataDirPath & '\bridges.txt')

Global $g_bTorConfig_AutoStart = (IniRead($CONFIG_INI, "startup", "auto_start", "false") = "true")
Global $g_sTorConfig_AutoStartShortcut = IniRead($CONFIG_INI, "startup", "auto_start_shortcut", "")
Global $g_bTorConfig_StartMinimized = (IniRead($CONFIG_INI, "startup", "start_minimized", "false") = "true")
#EndRegion Read Configuration

#EndRegion Variable Initialization

#Region Tray Creation
Opt("TrayMenuMode", 1 + 2) ; No default menu and automatic checkmarks
Opt("TrayOnEventMode", 1) ; OnEvent mode
Opt("TrayAutoPause", 0) ; No Auto-Pause

Tray_Initialize()

Func Tray_Initialize()
	TraySetClick(16) ; Will display the menu when releasing the secondary mouse button
	TraySetOnEvent($TRAY_EVENT_PRIMARYDOWN, "GUI_ToggleMainWindow")
	TrayItemSetState(TrayCreateItem("ProxAllium"), $TRAY_DISABLE)
	TrayCreateItem("")
	Global $g_idTrayMainWinToggle = TrayCreateItem('...')
	TrayItemSetOnEvent($g_idTrayMainWinToggle, "GUI_ToggleMainWindow")
	Global $g_idTrayTorOutputToggle = TrayCreateItem("Show Tor Output")
	TrayItemSetOnEvent($g_idTrayTorOutputToggle, "GUI_ToggleTorOutputWindow")
	TrayCreateItem("")
	Local $idOptions = TrayCreateMenu("Options")
	Global $g_idTrayOptionBridges = TrayCreateItem("Bridges", $idOptions)
	TrayItemSetOnEvent($g_idTrayOptionBridges, "Tray_HandleBridgeOption")
	TrayCreateItem("", $idOptions)
	Global $g_idTrayOptionRegenConfig = TrayCreateItem("Regenerate Tor configuration", $idOptions)
	TrayItemSetOnEvent($g_idTrayOptionRegenConfig, "GUI_RegenerateTorrc")
	Global $g_idTrayOptionRefreshCircuit = TrayCreateItem("New Tor Circuit for future connections", $idOptions)
	TrayItemSetOnEvent($g_idTrayOptionRefreshCircuit, "GUI_RefreshCircuit")
	TrayCreateItem("")
	Global $g_idTrayToggleTor = TrayCreateItem("Stop Tor")
	TrayItemSetOnEvent($g_idTrayToggleTor, "Tor_Toggle")
	TrayCreateItem("")
	TrayItemSetOnEvent(TrayCreateItem("Exit"), "GUI_MainWindowExit")
	TraySetState($TRAY_ICONSTATE_SHOW)
	TraySetToolTip("ProxAllium")
EndFunc

Func Tray_HandleBridgeOption()
	Call("GUI_BridgeHandler", $g_idTrayOptionBridges)
EndFunc
#EndRegion Tray Creation

#Region GUI Creation
Opt("GUIOnEventMode", 1)
GUI_CreateMainWindow()
GUI_LogOut("Starting ProxAllium... Please wait :)")
GUI_CreateTorOutputWindow()
GUI_CreateBridges()

Func GUI_CreateMainWindow()
	Global $g_hMainGUI = GUICreate("ProxAllium", 580, 370)
	GUISetOnEvent($GUI_EVENT_CLOSE, "GUI_ToggleMainWindow", $g_hMainGUI)
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
	Global $g_idMainGUI_MenuRefreshCircuit = GUICtrlCreateMenuItem("New Tor Circuit for future connections", $idMenuOptions)
	GUICtrlSetOnEvent(-1, "GUI_RefreshCircuit")
	GUICtrlCreateMenuItem("", $idMenuOptions)
	Local $idMenuStartup = GUICtrlCreateMenu("Startup", $idMenuOptions)
	Global $g_idMainGUI_MenuAutoStart = GUICtrlCreateMenuItem("Automatically start with Windows", $idMenuStartup)
	GUICtrlSetOnEvent(-1, "GUI_AutoStart")
	If $g_bTorConfig_AutoStart Then GUICtrlSetState(-1, $GUI_CHECKED)
	Global $g_idMainGUI_MenuStartMinimized = GUICtrlCreateMenuItem("Start Minimized", $idMenuStartup)
	If $g_bTorConfig_StartMinimized Then GUICtrlSetState(-1, $GUI_CHECKED)
	GUICtrlSetOnEvent(-1, "GUI_StartMinimized")
	GUICtrlCreateMenuItem("", $idMenuOptions)
	Global $g_idMainGUI_MenuRunSetup = GUICtrlCreateMenuItem("Run Tor setup again", $idMenuOptions)
	GUICtrlSetOnEvent(-1, "Core_SetupTor")
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
	Global $g_idMainGUI_TorPID = GUICtrlCreateInput("Not running", 73, 139, 497, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, $COLOR_WHITE)
	GUICtrlCreateLabel("Tor Version:", 10, 169, 60, 15)
	Global $g_idMainGUI_TorVersion = GUICtrlCreateInput('(Yet to be determined)', 73, 164, 497, 20, $ES_READONLY, $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, $COLOR_WHITE)
	GUICtrlCreateGroup("Control Panel", 5, 192, 570, 42)
	GUICtrlCreateLabel("Status:", 10, 213, 33, 15)
	Global $g_idMainGUI_Status = GUICtrlCreateInput('Initializing', 48, 208, 438, 20, BitOr($ES_CENTER, $ES_READONLY), $WS_EX_CLIENTEDGE)
	GUICtrlSetBkColor(-1, $COLOR_WHITE)
	Global $g_idMainGUI_ToggleButton = GUICtrlCreateButton('...', 489, 207, 82, 22)
	GUICtrlSetState(-1, $GUI_DISABLE)
	GUICtrlSetOnEvent(-1, "Tor_Toggle")
	Global $g_idMainGUI_Log = GUICtrlCreateEdit("", 5, 238, 570, 107, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL))
	Global $g_hMainGUI_Log = GUICtrlGetHandle($g_idMainGUI_Log)
	GUICtrlSetFont($g_idMainGUI_Log, 9, Default, Default, "Consolas")
	GUICtrlSetBkColor($g_idMainGUI_Log, $COLOR_WHITE)
	GUI_Reset()
	GUI_ToggleMainWindow()
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
	Local Static $bHidden = ($g_bTorConfig_StartMinimized ? False : True)
	If $bHidden Then
		$bHidden = Not (GUISetState(@SW_SHOWNORMAL, $g_hMainGUI) = 1)
		If Not $bHidden Then TrayItemSetText($g_idTrayMainWinToggle, "Hide Main Window")
	Else
		$bHidden = (GUISetState(@SW_HIDE, $g_hMainGUI) = 1)
		If $bHidden Then TrayItemSetText($g_idTrayMainWinToggle, "Show Main Window")
	EndIf
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
		Case $g_idMainGUI_MenuBridges, $g_idTrayOptionBridges
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

Func GUI_RefreshCircuit()
	GUI_LogOut("Switching to clean circuits... ", False)
	_Tor_SwitchCircuit($g_aTorProcess)
	If @error Then
		GUI_LogOut('Failed to create clean circuits! ' & StringFormat('(Error Code: %i and Extended Code: %i)', @error, @extended))
	Else
		GUI_LogOut("Done!")
	EndIf
EndFunc

Func GUI_AutoStart()
	Local $iReturn
	If $g_bTorConfig_AutoStart Then
		$iReturn = FileDelete($g_sTorConfig_AutoStartShortcut)
		If $iReturn = 0 Then
			MsgBox($MB_ICONERROR, "Failed to remove startup", "Failed to remove shortcut in the Startup folder!")
		Else
			$g_bTorConfig_AutoStart = False
			IniDelete($CONFIG_INI, "startup", "auto_start")
			IniDelete($CONFIG_INI, "startup", "auto_start_shortcut")
			GUICtrlSetState($g_idMainGUI_MenuAutoStart, $GUI_UNCHECKED)
			MsgBox($MB_ICONINFORMATION, "Successfully removed from startup", "ProxAllium will no longer start with Windows")
		EndIf
	Else
		Local $sStartupFolder = _WinAPI_ShellGetKnownFolderPath($FOLDERID_Startup)
		$sShortcutPath = $sStartupFolder & '\ProxAllium.lnk'
		If FileExists($sShortcutPath) Then $sShortcutPath = _TempFile($sStartupFolder, "ProxAllium_", '.lnk')
		$iReturn = FileCreateShortcut(@ScriptFullPath, $sShortcutPath, @WorkingDir)
		If $iReturn = 0 Then
			MsgBox($MB_ICONERROR, "Cannot add to startup", "Failed to create a shortcut in the Startup folder!")
		Else
			$g_bTorConfig_AutoStart = True
			IniWrite($CONFIG_INI, "startup", "auto_start", "true")
			$g_sTorConfig_AutoStartShortcut = $sShortcutPath
			IniWrite($CONFIG_INI, "startup", "auto_start_shortcut", $sShortcutPath)
			GUICtrlSetState($g_idMainGUI_MenuAutoStart, $GUI_CHECKED)
			MsgBox($MB_ICONINFORMATION, "Successfully added to startup", "ProxAllium will start with Windows from now!")
		EndIf
	EndIf
EndFunc

Func GUI_StartMinimized()
	If $g_bTorConfig_StartMinimized Then
		$g_bTorConfig_StartMinimized = False
		IniDelete($CONFIG_INI, "startup", "start_minimized")
		GUICtrlSetState($g_idMainGUI_MenuStartMinimized, $GUI_UNCHECKED)
	Else
		$g_bTorConfig_StartMinimized = True
		IniWrite($CONFIG_INI, "startup", "start_minimized", "true")
		GUICtrlSetState($g_idMainGUI_MenuStartMinimized, $GUI_CHECKED)
	EndIf
EndFunc

Func GUI_Reset()
	GUICtrlSetData($g_idMainGUI_Port, $g_sTorConfig_Port & ' (As defined in the settings)')
	GUICtrlSetData($g_idMainGUI_TorPID, "Not running")
	TrayItemSetText($g_idTrayToggleTor, "Start Tor")
	GUICtrlSetData($g_idMainGUI_ToggleButton, "Start")
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
	Local $aCallbackFuncs = [Handle_OpenSockets, Handle_Bootstrap, Handle_WarningAndError]
	Local $sPartialTorOutput = ""
	Local $aPartialTorOutput[0]
	Local $bRemoveCallback, $sRemovalList
	While IsTorRunning() ; Loop until Tor is dead
		Sleep($g_iOutputPollInterval) ; Don't kill the CPU
		$sPartialTorOutput = StdoutRead($g_aTorProcess[$TOR_PROCESS_PID])
		If $sPartialTorOutput = "" Then ContinueLoop
		_GUICtrlEdit_AppendText($g_hTorOutput, $sPartialTorOutput)
		$aPartialTorOutput = StringSplit(StringStripWS($sPartialTorOutput, $STR_STRIPTRAILING), @CRLF, $STR_ENTIRESPLIT)
		For $iLine = 1 To $aPartialTorOutput[0]
			For $iFunc = 0 To UBound($aCallbackFuncs) - 1
				$bRemoveCallback = $aCallbackFuncs[$iFunc](StringSplit($aPartialTorOutput[$iLine], ' '))
				If $bRemoveCallback Then $sRemovalList &= $iFunc & ';'
			Next
			If Not $sRemovalList = "" Then
				_ArrayDelete($aCallbackFuncs, StringTrimRight($sRemovalList, 1))
				$sRemovalList = ""
			EndIf
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
	GUI_Reset()
EndFunc

Func Handle_WarningAndError(ByRef $aTorOutput)
	If $aTorOutput[0] < 4 Then Return
	If ($aTorOutput[4] = '[warn]') Or ($aTorOutput[3] = '[err]') Then
		If $aTorOutput[5] = "Path" Then Return
		GUI_LogOut(_ArrayToString($aTorOutput, ' ', 5))
	EndIf
EndFunc

Func Handle_OpenSockets(ByRef $aTorOutput)
	If ($aTorOutput[0] < 9) Or ($aTorOutput[5] <> "Opening") Then Return
	Local Enum $IP, $PORT
	Local $aAddress = StringSplit($aTorOutput[($aTorOutput[6] = "HTTP" ? 10 : 9)], ':', $STR_NOCOUNT)
	Local Static $bSocksInit = False
	Local Static $bControlInit = False
	Switch $aTorOutput[6]
		Case "Socks"
			GUICtrlSetData($g_idMainGUI_Port, $aAddress[$PORT])
			$bSocksInit = True
		Case "HTTP"
			_GUICtrlEdit_AppendText($g_idMainGUI_Port, ' (HTTP Tunnel Port: ' & $aAddress[$PORT] & ')')
		Case "Control"
			Core_InitConnectionToController($g_sTorConfig_ControlPort)
			$bControlInit = True
	EndSwitch
	If $bSocksInit And $bControlInit Then
		$bSocksInit = False
		$bControlInit = False
		Return True
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
		TrayTip("Tor is ready", "Tor has successfully built a circuit, you can now start using the proxy!", 10, $TIP_ICONASTERISK)
		Return True
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
	If Not $g_sTorConfig_TunnelPort = "" Then
		FileWriteLine($hTorrc, '## HTTP Tunnel Proxy')
		FileWriteLine($hTorrc, "HTTPTunnelPort " & $g_sTorConfig_TunnelPort)
		FileWriteLine($hTorrc, "")
	EndIf
	FileWriteLine($hTorrc, '## Open the Tor controller interface on the following port')
	FileWriteLine($hTorrc, 'ControlPort ' & $g_sTorConfig_ControlPort)
	FileWriteLine($hTorrc, 'HashedControlPassword ' & _Tor_GenHash($g_sTorConfig_ControlPass)[0])
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
		If FileExists($g_sObfs4Path) Then
			FileWriteLine($hTorrc, 'ClientTransportPlugin obfs2,obfs3,obfs4,scramblesuit exec ' & $g_sObfs4Path)
		EndIf
		If FileExists($g_sSnowflakePath) Then
			; https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/snowflake/-/tree/main/client
			FileWriteLine($hTorrc, 'ClientTransportPlugin snowflake exec ' & $g_sSnowflakePath & ' ' & $g_sSnowflakeArgs)
		EndIf
		Local $aBridges = StringSplit(StringStripCR(GUICtrlRead($g_idBridgesEdit)), @LF)
		For $iBridge = 1 To $aBridges[0]
			If StringIsSpace($aBridges[$iBridge]) Then ContinueLoop ; Skip blank lines
			If StringLeft($aBridges[$iBridge], 1) = '#' Then ContinueLoop ; Skip comments
			FileWriteLine($hTorrc, 'Bridge ' & $aBridges[$iBridge])
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

Func Core_InitConnectionToController($iPort)
	_Tor_Controller_Connect($g_aTorProcess, $g_sTorConfig_ControlPort)
	If @error Then
		GUI_LogOut('Failed to connect to Tor contoller! ' & StringFormat('(Error Code: %i and Extended Code: %i)', @error, @extended))
		Return SetError(1, 0, False)
	EndIf
	_Tor_Controller_Authenticate($g_aTorProcess, $TOR_CONTROLLER_AUTH_HASH, $g_sTorConfig_ControlPass)
	If @error Then
		GUI_LogOut('Failed to authenticate with Tor contoller! ' & StringFormat('(Error Code: %i and Extended Code: %i)', @error, @extended))
		Return SetError(2, 0, False)
	EndIf
	GUI_LogOut('Successfully connected to the controller!')
	_Tor_Controller_TakeOwnership($g_aTorProcess)
	If @error Then
		GUI_LogOut('Failed to take ownership of Tor instance ' & StringFormat('(Error Code: %i and Extended Code: %i)', @error, @extended))
		SetExtended(1, True)
	EndIf
	Return True
EndFunc

Func Core_SetupTor($bIntro = True)
	If Not IsDeclared("bIntro") = $DECLARED_LOCAL Then $bIntro = False

	Local $iMsgBoxFlags, $sMsgBoxTitle, $sMsgBoxMsg
	$iMsgBoxFlags = $MB_ICONINFORMATION + $MB_YESNO
	$sMsgBoxTitle = "Setup Tor"
	If $bIntro Then
		$sMsgBoxMsg = "It looks Tor is not configured properly in ProxAllium yet, most likely this is your first run. Do not worry, ProxAllium can guide you through the process!" & @CRLF & @CRLF
	EndIf
	$sMsgBoxMsg &= "Do you want to continue with the setup process?"
	If MsgBox($iMsgBoxFlags, $sMsgBoxTitle, $sMsgBoxMsg) = $IDNO Then Return False

	Local $bUseTB = False
	$iMsgBoxFlags = $MB_ICONQUESTION + $MB_YESNO
	$sMsgBoxMsg = "Do you have Tor Browser installed?"
	If MsgBox($iMsgBoxFlags, $sMsgBoxTitle, $sMsgBoxMsg) = $IDYES Then
		$bUseTB = True
	Else
		$iMsgBoxFlags = $MB_ICONQUESTION + $MB_YESNO
		$sMsgBoxMsg = "It is also possible to just use Tor, but I recommend installing the Tor Browser as it automatically updates your copy of Tor when you update the browser and it also adds support for bridges." & @CRLF
		$sMsgBoxMsg &= @CRLF & 'Do you want to install Tor Browser and use Tor from it? Choose "No" to continue with only Tor.'
		$bUseTB = MsgBox($iMsgBoxFlags, $sMsgBoxTitle, $sMsgBoxMsg) = $IDYES
		If $bUseTB Then MsgBox($MB_ICONINFORMATION, $sMsgBoxTitle, "Please download and install the latest version of Tor Browser and click OK to continue.")
	EndIf

	Local $sTorFolder, $bFoundTor = False
	If $bUseTB Then
		Do
			$sTorFolder = FileSelectFolder("Please select the folder containing Tor Browser", "", 0, @DesktopDir & '\Tor Browser')
			If @error Then Return False
			$sTorFolder = $sTorFolder & '\Browser\TorBrowser\Tor'
			If FileExists($sTorFolder & '\tor.exe') Then
				$bFoundTor = True
			EndIf
			If Not $bFoundTor Then MsgBox($MB_ICONERROR, "Tor not found", 'Cannot find tor.exe in this folder, please try again and make sure you have selected the installation directory (and not the "Browser" folder inside it).')
		Until $bFoundTor
	Else
		$iMsgBoxFlags = $MB_ICONQUESTION + $MB_YESNO
		$sMsgBoxMsg = 'Do you want to download Tor? If you already have a copy of Tor in your computer, then choose "No".'
		If MsgBox($iMsgBoxFlags, $sMsgBoxTitle, $sMsgBoxMsg) = $IDYES Then
			$iMsgBoxFlags = $MB_ICONINFORMATION
			$sMsgBoxMsg = 'The URL (https://www.torproject.org/download/tor) for the page which contains the link to download the "Tor Expert Bundle" has been copied to your clipboard.' & @CRLF
			$sMsgBoxMsg &= @CRLF & "Please download it and extract the files to a permanent location (a sub-folder in ProxAllium's folder should be perfect), Click OK when you are done."
			ClipPut('https://www.torproject.org/download/tor')
			MsgBox($iMsgBoxFlags, $sMsgBoxTitle, $sMsgBoxMsg)
		EndIf
		Do
			$sTorFolder = FileSelectFolder("Please select the folder containing Tor", "")
			If @error Then Return False
			If FileExists($sTorFolder & '\Tor\tor.exe') Then
				$sTorFolder = $sTorFolder & '\Tor'
				$bFoundTor = True
			ElseIf FileExists($sTorFolder & '\tor.exe') Then
				$bFoundTor = True
			EndIf
			If Not $bFoundTor Then MsgBox($MB_ICONERROR, "Tor not found", "Cannot find tor.exe in this folder, please make sure you have selected the right folder and try again.")
		Until $bFoundTor
	EndIf

	If $bFoundTor Then
		$g_sTorPath =  $sTorFolder & '\tor.exe'
		IniWrite($CONFIG_INI, "tor", "path", $g_sTorPath)
		If $bUseTB Then
			Local $sObfs4 = $sTorFolder & '\PluggableTransports\obfs4proxy.exe'
			If FileExists($sObfs4) Then
				$g_sObfs4Path = $sObfs4
				IniWrite($CONFIG_INI, "tor", "obfs4_path", $g_sObfs4Path)
			EndIf
			Local $sSnowflake = $sTorFolder & '\PluggableTransports\snowflake-client.exe'
			If FileExists($sSnowflake) Then
				$g_sSnowflakePath = $sSnowflake
				IniWrite($CONFIG_INI, "tor", "snowflake_path", $g_sSnowflakePath)
				IniWrite($CONFIG_INI, "tor", "snowflake_args", $g_sSnowflakeArgs)

				Local $hBridges = FileOpen($g_sTorConfig_BridgesPath, $FO_APPEND + $FO_CREATEPATH)
				If $hBridges <> -1 Then
					FileWriteLine($hBridges, '# Uncomment the line below to use snowflake bridge transport')
					FileWriteLine($hBridges, '# snowflake 192.0.2.3:1')
					FileClose($hBridges)

					GUIDelete($g_hBridgesGUI)
					GUI_CreateBridges()
				EndIf
			EndIf
		EndIf
	EndIf

	$iMsgBoxFlags = $MB_ICONINFORMATION
	$sMsgBoxMsg = 'Setup process is complete!'
	MsgBox($iMsgBoxFlags, $sMsgBoxTitle, $sMsgBoxMsg)

	Return $bFoundTor
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
		If Not FileExists($g_sTorConfigFile) Then
			GUI_LogOut("Cannot find Tor configuration file, generating one now... ", False)
			Core_GenTorrc()
			If @error Then Core_WaitForExit("Failed to create configuration file!")
			GUI_LogOut("Successfully generated Tor configuration file!")
		EndIf
		Return True
	EndIf
	GUICtrlSetData($g_idMainGUI_TorVersion, '...')
	Switch $iError
		Case $TOR_ERROR_GENERIC
			GUI_LogOut("Cannot find Tor!")
			If Core_SetupTor() Then
				Local $vReturn = Tor_Initialize()
				Return SetError(@error, 0, $vReturn)
			EndIf
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
