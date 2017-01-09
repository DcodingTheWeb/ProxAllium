; USE THIS PROGRAM AT YOUR OWN RISK
; THIS PROGRAM IS CURRENTLY AT VERY EARLY STAGES - Not suitable for normal use!

#NoTrayIcon

#Region AutoIt3Wrapper Directives
#AutoIt3Wrapper_Icon=icon.ico
#AutoIt3Wrapper_Outfile=Builds\ProxAllium.exe
#AutoIt3Wrapper_UseUpx=y
#AutoIt3Wrapper_Res_Description=Tor Proxy Bundle for Windows
#AutoIt3Wrapper_Res_Fileversion=0.1.0.0
#AutoIt3Wrapper_Res_ProductVersion=0.1.0.0
#AutoIt3Wrapper_Res_LegalCopyright=Dcoding The Web
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/sf /sv /mo /rm
#EndRegion AutoIt3Wrapper Directives

#Region Includes
#include <Array.au3>
#include <Color.au3>
#include <ColorConstants.au3>
#include <EditConstants.au3>
#include <FileConstants.au3>
#include <FontConstants.au3>
#include <GuiEdit.au3>
#include <MsgBoxConstants.au3>
#include <StringConstants.au3>
#include <TrayConstants.au3>
#include "Tor.au3"
#EndRegion Includes

#Region Tray Creation
Opt("TrayMenuMode", 1 + 2) ; No default menu and automatic checkmarks
Opt("TrayOnEventMode", 1) ; OnEvent mode
Opt("TrayAutoPause", 0) ; No Auto-Pause

TraySetClick(16) ; Will display the menu when releasing the secondary mouse button
TraySetOnEvent($TRAY_EVENT_PRIMARYDOWN, "GUI_ToggleLogWindow")

TrayItemSetState(TrayCreateItem("ProxAllium"), $TRAY_DISABLE)
TrayCreateItem("")
Global $g_idTrayLogToggle = TrayCreateItem("Hide Log Window")
TrayItemSetOnEvent($g_idTrayLogToggle, "GUI_ToggleLogWindow")
Global $g_idTrayTorOutputToggle = TrayCreateItem("Show Tor Output")
TrayItemSetOnEvent($g_idTrayTorOutputToggle, "GUI_ToggleTorOutputWindow")
TrayCreateItem("")
TrayItemSetOnEvent(TrayCreateItem("Exit"), "GUI_LogWindowExit")
TraySetState($TRAY_ICONSTATE_SHOW)
#EndRegion Tray Creation

#Region GUI Creation Functions
Opt("GUIOnEventMode", 1)
GUI_CreateLogWindow()
GUI_LogOut("Starting ProxAllium... Please wait :)")
GUI_CreateTorOutputWindow()

Func GUI_CreateLogWindow()
	Local Const $eiGuiWidth = 580, $eiGuiHeight = 280
	Global $g_hLogGUI = GUICreate("ProxAllium", $eiGuiWidth, $eiGuiHeight, Default, Default, $WS_OVERLAPPEDWINDOW)
	GUISetOnEvent($GUI_EVENT_CLOSE, "GUI_LogWindowExit")
	GUISetOnEvent($GUI_EVENT_MINIMIZE, "GUI_ToggleLogWindow")
	Global $g_idLogCtrl = GUICtrlCreateEdit("", 0, 0, $eiGuiWidth, $eiGuiHeight, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL))
	Global $g_hLogCtrl = GUICtrlGetHandle($g_idLogCtrl) ; Get the handle of the Edit control for future use in GUI_LogOut
	GUICtrlSetFont($g_idLogCtrl, 9, Default, Default, "Consolas")
	GUISetState(@SW_SHOW, $g_hLogGUI) ; Make the GUI visible
EndFunc

Func GUI_LogOut($sText, $bEOL = True)
	If $bEOL Then $sText &= @CRLF
	_GUICtrlEdit_AppendText($g_hLogCtrl, $sText)
	ConsoleWrite($sText)
EndFunc

Func GUI_CreateTorOutputWindow()
	Local Const $eiGuiWidth = 580, $eiGuiHeight = 280
	Global $g_hTorGUI = GUICreate("Tor Output", $eiGuiWidth, $eiGuiHeight, Default, Default, $WS_OVERLAPPEDWINDOW)
	GUISetOnEvent($GUI_EVENT_CLOSE, "GUI_TorWindowExit")
	GUISetOnEvent($GUI_EVENT_MINIMIZE, "GUI_ToggleTorOutputWindow")
	Global $g_idTorOutput = GUICtrlCreateEdit("", 0, 0, $eiGuiWidth, $eiGuiHeight, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL))
	Global $g_hTorOutput = GUICtrlGetHandle($g_idTorOutput) ; Get the handle of the Edit control for future use in the Tor Output Handler
	GUICtrlSetFont($g_idTorOutput, 9, Default, Default, "Consolas")
	GUICtrlSetBkColor($g_idTorOutput, $COLOR_BLACK)
	Local $aGrayCmdColor[3] = [197, 197, 197] ; CMD Text Color's combination in RGB
	Local Const $iGrayCmdColor = _ColorSetRGB($aGrayCmdColor) ; Get the RGB code of CMD Text Color
	GUICtrlSetColor($g_idTorOutput, $iGrayCmdColor)
	Local $idDummy = GUICtrlCreateDummy()
	GUICtrlSetOnEvent($idDummy, "GUI_ToggleTorOutputWindow")
	Local $aGuiAccelKeys[1][2] = [["^t", $idDummy]]
	GUISetAccelerators($aGuiAccelKeys, $g_hTorGUI)
	; Create a Dummy on $g_hLogGUI too
	GUISwitch($g_hLogGUI)
	$idDummy = GUICtrlCreateDummy()
	GUICtrlSetOnEvent($idDummy, "GUI_ToggleTorOutputWindow")
	$aGuiAccelKeys[0][1] = $idDummy
	GUISetAccelerators($aGuiAccelKeys, $g_hLogGUI)
EndFunc
#EndRegion GUI Functions

#Region Variable Initialization
Global $g_aTorProcess[2]
Global $g_aTorVersion[0]
#EndRegion Variable Initialization

#Region Main Script
#Region Read Configuration
Global Const $CONFIG_INI = @ScriptDir & '\config.ini'

Global $g_sTorPath = IniRead($CONFIG_INI, "tor", "path", @ScriptDir & '\Tor\tor.exe')
Global $g_sTorConfigFile = IniRead($CONFIG_INI, "tor", "config_file", @ScriptDir & '\config.torrc')
Global $g_sTorDataDirPath = IniRead($CONFIG_INI, "tor", "data_dir", @ScriptDir & '\Tor\data')
Global $g_sTorGeoIPv4File = IniRead($CONFIG_INI, "tor", "geoip4_file", @ScriptDir & '\Tor\geoip')
Global $g_sTorGeoIPv6File = IniRead($CONFIG_INI, "tor", "geoip6_file", @ScriptDir & '\Tor\geoip6')
Global $g_iOutputPollInterval = Int(IniRead($CONFIG_INI, "proxallium", "output_poll_interval", "1000"))

Global $g_sTorConfig_Port = IniRead($CONFIG_INI, "tor_config", "port", "9050")
Global $g_bTorConfig_OnlyLocalhost = (IniRead($CONFIG_INI, "tor_config", "localhost_only", "true") = "true")
#EndRegion Read Configuration

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
Func GUI_LogWindowExit()
	Local $iButtonID = MsgBox($MB_YESNO + $MB_ICONQUESTION, "Exit", "Do you really want to close ProxAllium?", $g_hLogGUI)
	If $iButtonID = $IDYES Then
		Tor_Stop()
		Exit
	EndIf
EndFunc

Func GUI_TorWindowExit()
	If ProcessExists($g_aTorProcess[$TOR_PROCESS_PID]) Then
		Local $iButtonID = MsgBox($MB_YESNO + $MB_ICONQUESTION, "Close Tor?", "Do you really want to close Tor?", $g_hTorGUI)
		If $iButtonID = $IDNO Then Return
	EndIf
	Tor_Stop()
	GUI_ToggleTorOutputWindow()
EndFunc

Func GUI_ToggleTorOutputWindow()
	Local Static $bHidden = True
	If $bHidden Then
		$bHidden = Not (GUISetState(@SW_SHOWNORMAL, $g_hTorGUI) = 1)
		If Not $bHidden Then TrayItemSetText($g_idTrayTorOutputToggle, "Hide Tor Output")
		Return
	EndIf
	$bHidden = (GUISetState(@SW_HIDE, $g_hTorGUI) = 1)
	If $bHidden Then TrayItemSetText($g_idTrayTorOutputToggle, "Show Tor Output")
EndFunc

Func GUI_ToggleLogWindow()
	Local Static $bHidden = False
	If $bHidden Then
		$bHidden = Not (GUISetState(@SW_SHOWNORMAL, $g_hLogGUI) = 1)
		If Not $bHidden Then TrayItemSetText($g_idTrayLogToggle, "Hide Log Window")
		Return
	EndIf
	$bHidden = (GUISetState(@SW_HIDE, $g_hLogGUI) = 1)
	If $bHidden Then TrayItemSetText($g_idTrayLogToggle, "Show Log Window")
EndFunc
#EndRegion GUI Handlers

#Region Event Handler Functions
Func Handle_TorOutput()
	Local $aTorOutputCallbackFuncs = [2, "Handle_Bootstrap", "Handle_WarningAndError"]
	Local $sPartialTorOutput = ""
	Local $aPartialTorOutput[0]
	Local $bTorAlive = True
	While $bTorAlive ; Loop until Tor is dead
		Sleep($g_iOutputPollInterval) ; Don't kill the CPU
		$bTorAlive = Not (ProcessExists($g_aTorProcess[$TOR_PROCESS_PID]) = 0) ; Check if Tor still exists
		$sPartialTorOutput = StdoutRead($g_aTorProcess[$TOR_PROCESS_PID])
		If $sPartialTorOutput = "" Then ContinueLoop
		_GUICtrlEdit_AppendText($g_hTorOutput, $sPartialTorOutput)
		$aPartialTorOutput = StringSplit(StringStripWS($sPartialTorOutput, $STR_STRIPTRAILING), @CRLF, $STR_ENTIRESPLIT)
		For $iLine = 1 To $aPartialTorOutput[0]
			For $iCallBackFunc = 1 To $aTorOutputCallbackFuncs[0]
				Call($aTorOutputCallbackFuncs[$iCallBackFunc], StringSplit($aPartialTorOutput[$iLine], ' '))
			Next
		Next
	WEnd
	GUI_LogOut("Tor exited with exit code: " & _Process_GetExitCode($g_aTorProcess[$TOR_PROCESS_HANDLE]))
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
	GUI_LogOut(_ArrayToString($aTorOutput, ' ', 5))
	If $iPercentage = 100 Then
		GUI_LogOut("Successfully built a circuit, Tor is now ready for use!")
		GUI_LogOut('##################################################')
		GUI_LogOut("# You can now connect to the Tor proxy hosted at:")
		GUI_LogOut("# IP Address: 127.0.0.1")
		GUI_LogOut("# Port      : " & $g_sTorConfig_Port)
		GUI_LogOut("# Proxy Type: SOCKS5")
		GUI_LogOut('##################################################')
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
		If ProcessExists($g_aTorProcess[$TOR_PROCESS_PID]) Then Handle_TorOutput()
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
	FileWriteLine($hTorrc, '## This file was generated on ' & @MDAY & '-' & @MON & '-' & @YEAR)
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
	FileWriteLine($hTorrc, '###########################################################')
	FileWriteLine($hTorrc, '###### STORE YOUR CUSTOM CONFIGURATION ENTRIES BELOW ######')
	FileWriteLine($hTorrc, '##### THEY WILL BE PRESERVED ACROSS CHANGES IN CONFIG #####')
	FileWriteLine($hTorrc, '###########################################################')
	FileWriteLine($hTorrc, '#~ I (this line) am used to identify the start of custom entries, so please do not touch me :)')
	FileWriteLine($hTorrc, $sCustomConfig)
	FileSetEnd($hTorrc)
	FileClose($hTorrc)
EndFunc
#EndRegion Core Functions

#Region Tor Functions
Func Tor_Initialize()
	$g_aTorVersion = _Tor_SetPath($g_sTorPath)
	If Not @error Then Return GUI_LogOut("Detected Tor version: " & $g_aTorVersion[$TOR_VERSION])
	SetError(@error)
	Switch @error
		Case $TOR_ERROR_GENERIC
			GUI_LogOut("Cannot find Tor!")

		Case $TOR_ERROR_VERSION
			GUI_LogOut("Unable to identify Tor's version!")
	EndSwitch
EndFunc

Func Tor_Start()
	GUI_LogOut("Starting Tor... ", False)
	$g_aTorProcess = _Tor_Start($g_sTorConfigFile)
	If @error Then
		Switch @error
			Case $TOR_ERROR_PROCESS
				GUI_LogOut("Unable to start Tor!")

			Case $TOR_ERROR_CONFIG
				GUI_LogOut("Invalid Tor configuration, please check your custom entries.")
		EndSwitch
	EndIf
	GUI_LogOut("Started Tor with PID: " & $g_aTorProcess[$TOR_PROCESS_PID])
	Handle_TorOutput()
EndFunc

Func Tor_Stop()
	GUI_LogOut("Trying to stop Tor... ", False)
	ProcessClose($g_aTorProcess[$TOR_PROCESS_PID])
	If @error Then Return GUI_LogOut("Failed to stop Tor (Error Code: " & @error & ')')
	GUI_LogOut("Successfully stopped Tor!")
EndFunc
#EndRegion Tor Functions
#EndRegion Functions
