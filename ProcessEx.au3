#include-once
#include <AutoItConstants.au3>
#include <Color.au3>
#include <ColorConstants.au3>
#include <GUIConstantsEx.au3>
#include <GuiEdit.au3>
#include <ProcessConstants.au3>
#include <StringConstants.au3>
#include <WindowsConstants.au3>
#include "IsMgcNumPresent.au3"

#AutoIt3Wrapper_Au3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w- 4 -w 5 -w 6 -w- 7

; #INDEX# =======================================================================================================================
; Title ............: Process UDF.
; AutoIt Version ...: 3.3.14.1
; Description ......: UDF for AutoIt which contains useful functions which can be used to interact with processes in windows!
; Author(s) ........: Damon Harris (TheDcoder).
; This UDF Uses ....: PslatyDS's Code          - https://www.autoitscript.com/forum/topic/98602-run-not-runwait-with-dos-exit-code/?do=findComment&comment=720326
;                     Is Magic Number Present? - https://git.io/vPFjk
; Links ............: GitHub       - https://github.com/TheDcoder/Process-UDF-for-AutoIt/
;                     AutoIt Forum - https://www.autoitscript.com/forum/topic/174697-process-udf-get-both-the-output-the-exit-code
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
; _Process_RunCommand
; _Process_WaitUntil
; _Process_GetPID
; _Process_GetPath
; _Process_GetHandle
; _Process_CloseHandle
; _Process_GetExitCode
; _Process_DebugRunCommand
; ===============================================================================================================================

; #INTERNAL_USE_ONLY# ===========================================================================================================
; __Process_WM_SIZE
; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================
Global Const $PROCESS_RUN = 2, $PROCESS_RUNWAIT = 4, $PROCESS_EXIST = 8, $PROCESS_NOTEXIST = 16, $PROCESS_DEBUG = 32

Global Const $PROCESS_COMMAND = @ComSpec & " /c " ; Use this in RunCommand function to run commands
; ===============================================================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _Process_RunCommand
; Description ...: Runs a command or a executable
; Syntax ........: _Process_RunCommand($iMode, $sExecutable [, $sWorkingDir = "" [, $iRunOptFlag = $STDERR_MERGED]])
; Parameters ....: $iMode               - Mode in which this function should operate, See Remarks.
;                  $sExecutable         - The command to run/execute (along with any arguments).
;                  $sWorkingDir         - [optional] The working directroy for the command. Default is "".
;                  $iRunOptFlag         - [optional] The Opt flag for the Run function. Default is $STDERR_MERGED.
; Return values .: Success: Mode $PROCESS_RUN     : Will return the process handle & @extended will contain the PID of the command
;                           Mode $PROCESS_RUNWAIT : Will return the output & @extended will contain the exit code for the function
;                  Failure: Will return False & @error will contain:
;                           1 - If the $iMode flag is invalid
;                           2 - If the command is invalid
; Author ........: TheDcoder
; Remarks .......: 1. The ONLY valid modes are: $PROCESS_RUN & $PROCESS_RUNWAIT
;                     $PROCESS_RUN     : Will act similarly to Run function, See Return values
;                     $PROCESS_RUNWAIT : Will act similarly to RunWait function, See Return values
;                     If you use $PROCESS_RUN then use _Process_GetExitCode to get the exit code & use StdoutRead to get the output of the command
;                  2. Use $PROCESS_COMMAND to run commands like this: $PROCESS_COMMAND & "ping 127.0.0.1"
;                  3. Add $PROCESS_DEBUG to $iMode to automagically debug the command, $PROCESS_RUN is equivalent to $PROCESS_RUNWAIT in this case
; Related .......: Run, RunWait
; Example .......: Yes, see example.au3
; ===============================================================================================================================; Functions
Func _Process_RunCommand($iMode, $sExecutable, $sWorkingDir = "", $iRunOptFlag = $STDERR_MERGED)
	Local $iExitCode = 0 ; Declare the exit code variable before hand
	Local $sOutput = "" ; Declare the output variable before hand
	Local $bDebug = IsMgcNumPresent($PROCESS_DEBUG, $iMode) ; Check if $PROCESS_DEBUG is present.
	Select ; Select...
		Case IsMgcNumPresent($PROCESS_RUN, $iMode) ; If the mode is $PROCESS_RUN
			$iMode = $PROCESS_RUN

		Case IsMgcNumPresent($PROCESS_RUNWAIT, $iMode) ; If the mode is $PROCESS_RUNWAIT
			$iMode = $PROCESS_RUNWAIT

		Case Else
			Return SetError(1, 0, False) ; If the mode is invalid...
	EndSelect
	Local $iPID = Run($sExecutable, $sWorkingDir, @SW_HIDE, $iRunOptFlag) ; Run!!! :P
	If @error Then Return SetError(2, 0, False) ; If the command is invalid...
	Local $hProcessHandle = _Process_GetHandle($iPID) ; Get the handle of the process
	If $iMode = $PROCESS_RUN Then
		If Not $bDebug Then Return SetExtended($iPID, $hProcessHandle) ; If the function is in Run mode then return the PID & Process Handle
		$sOutput = _Process_DebugRunCommand($hProcessHandle, $iPID) ; Debug the process
		$iExitCode = _Process_GetExitCode($hProcessHandle) ; Note the exit code
		Return SetExtended($iExitCode, $sOutput) ; Return the output & exit code
	EndIf
	If Not $bDebug Then
		While ProcessExists($iPID)
			$sOutput &= StdoutRead($iPID) ; Capture the output
			Sleep(10) ; Don't kill the CPU
		WEnd
		$sOutput &= StdoutRead($iPID) ; Capture any remaining output
		$iExitCode = _Process_GetExitCode($hProcessHandle) ; Note the exit code
		Return SetExtended($iExitCode, $sOutput) ; Return the exit code & the output :D
	EndIf
	$sOutput = _Process_DebugRunCommand($hProcessHandle, $iPID) ; Debug the process
	$iExitCode = _Process_GetExitCode($hProcessHandle) ; Note the exit code
	Return SetExtended($iExitCode, $sOutput) ; Return the output & exit code
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Process_WaitUntil
; Description ...: Waits until a process starts or quits. Also returns the exit code...
; Syntax ........: _Process_WaitUntil($iMode, $vProcess [, $iUpdateInterval = 10])
; Parameters ....: $iMode               - Mode in which this function should operate, See Remarks.
;                  $vProcess            - The PID or Name of the process, Same as ProcessExist's "process" parameter.
;                  $iUpdateInterval     - [optional] The time (in milliseconds) to wait before performing another check. Default is 10.
; Return values .: Success: True and sets @extended to the exit code if the mode is $PROCESS_NOTEXIST
;                  Failure: False
;                  Special: 0(See Remarks)
; Author ........: TheDcoder
; Remarks .......: 1. There are only 2 valid modes:
;                     $PROCESS_EXIST    : Waits until a process starts.
;                     $PROCESS_NOTEXIST : Waits until a process quits.
;                  2. 0 is returned when unable to retrive the PID of the process when in $PROCESS_NOTEXIST as the mode,
;                     There is an good chance that the process has already quit before the function starts checking.
; Example .......: No
; ===============================================================================================================================
Func _Process_WaitUntil($iMode, $vProcess, $iUpdateInterval = 10)
	If $iMode = $PROCESS_NOTEXIST And Not IsInt($vProcess) Then ; If it is in $PROCESS_NOTEXIST mode & not an PID
		$vProcess = _Process_GetPID($vProcess) ; Get the PID
		If @error Then Return 0 ; Return Immediatly
	EndIf
	Switch $iMode ; Switch to the required mode to opreate in.
		Case $PROCESS_EXIST
			While Not ProcessExists($vProcess) ; Wait for the process to start
				Sleep($iUpdateInterval) ; Some mercy on the CPU
			WEnd
			Return True ; Return True

		Case $PROCESS_NOTEXIST
			Local $hProcessHandle = _Process_GetHandle($vProcess) ; Get the process handle :)
			While ProcessExists($vProcess) ; Wait for the process to quit
				Sleep($iUpdateInterval) ; Some mercy on the CPU
			WEnd
			Return SetExtended(_Process_GetExitCode($hProcessHandle), True) ; Return True & set @extended to the exit code

		Case Else
			Return False
	EndSwitch
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Process_GetPID
; Description ...: Gets the PID of the process using the name of the process
; Syntax ........: _Process_GetPID($sProcess)
; Parameters ....: $sProcess            - The name of the process.
; Return values .: Success: The PID of the process
;                  Failure: False & sets @error to non-zero
; Author ........: TheDcoder
; Remarks .......: If multiple processes exist then the most recent process's PID is returned.
; Example .......: No
; ===============================================================================================================================
Func _Process_GetPID($sProcess)
	Local $aProcess = ProcessList($sProcess) ; List processes with that name
	If @error Or $aProcess[0][0] = 0 Then Return SetError(@error, False) ; Return False & set @error to non-zero if an error
	Return $aProcess[1][1] ; Return the PID
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Process_GetPath
; Description ...: Get the path of a process along with its arguments (if any)
; Syntax ........: _Process_GetPath($vProcess)
; Parameters ....: $vProcess            - The PID or name of the process.
; Return values .: Success: The path of process with its arguments
;                  Failure: False & sets @error to 1
; Author ........: TheDcoder
; Remarks .......: The return value is in this format: X:\Process.exe -Argument1 -ArgumentN...
; Example .......: No
; ===============================================================================================================================
Func _Process_GetPath($vProcess)
	Local Const $eiCharsToTrim = 12
	If Not IsInt($vProcess) Then $vProcess = _Process_GetPID($vProcess) ; Convert process name to PID
	Local $sCommandline = "wmic" ; Declare the commandline string
	$sCommandline &= ' process'
	$sCommandline &= ' where "' & "processid='" & $vProcess & "'" & '"'
	$sCommandline &= ' get commandline /format:list'
	Local $sOutput = _Process_RunCommand($PROCESS_RUNWAIT, $sCommandline) ; Run the command...
	; Thanks to rojo for this command at stackowerflow: http://stackoverflow.com/a/32609300/3815591
	$sOutput = StringStripWS($sOutput, $STR_STRIPLEADING + $STR_STRIPTRAILING) ; Remove whitespaces attached to the string
	If $sOutput = "No Instance(s) Available." Then Return SetError(1, 0, False) ; If process was not found...
	Local $sCommand = StringTrimLeft($sOutput, $eiCharsToTrim) ; Trim the Commandline=
	Return $sCommand ; Return
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Process_GetHandle
; Description ...: Gets the handle of a process, will be used later to retrive the exit code
; Syntax ........: _Process_GetHandle($vProcess)
; Parameters ....: $vProcess                - The PID or name of the process.
; Return values .: Success: Process handle
;                  Failure: 0 & Sets @error to non-zero
; Author ........: PsaltyDS
; Modified ......: TheDcoder: Comments, "If...Else...EndIf" to "If...Then", Return value for failure & Name of the function
; Example .......: No
; ===============================================================================================================================
Func _Process_GetHandle($vProcess)
	If Not IsInt($vProcess) Then $vProcess = _Process_GetPID($vProcess) ; Get the PID of the process if its not a PID ;)
	Local $avRET = DllCall("kernel32.dll", "ptr", "OpenProcess", "int", $PROCESS_QUERY_INFORMATION, "int", 0, "int", $vProcess) ; Get the process handle
	If @error Then Return SetError(1, 0, 0) ; If the process does not exists...
	Return $avRET[0] ; Return handle
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Process_CloseHandle
; Description ...: Closes the Process Handle of a process
; Syntax ........: _Process_CloseHandle($hProcessHandle)
; Parameters ....: $hProcessHandle      - A Process Handle.
; Return values .: Success: True
;                  Failure: False & sets @error to non-zero
; Author ........: PsaltyDS
; Modified ......: TheDcoder: Comments, "If...Else...EndIf" to "If...Then", Return values & Name of the function
; Example .......: No
; ===============================================================================================================================
Func _Process_CloseHandle($hProcessHandle)
	DllCall("kernel32.dll", "int", "CloseHandle", "ptr", $hProcessHandle) ; Close the handle
	If @error Then Return SetError(@error, 0, False) ; If invalid handle...
	Return True ; Return True if success
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Process_GetExitCode
; Description ...: Gets the exit code of a process
; Syntax ........: _Process_GetExitCode($hProcessHandle[, $bCloseHandle = True])
; Parameters ....: $hProcessHandle      - A Process Handle.
;                  $bCloseHandle        - [optional] Do you want to close the $hProcessHandle?. Default is True.
; Return values .: Success: Exit Code
;                  Failure: Returns 0 & sets @error to non-zero
; Author ........: PsaltyDS
; Modified ......: TheDcoder: Comments & Name of the function
; Example .......: No
; ===============================================================================================================================
Func _Process_GetExitCode($hProcessHandle, $bCloseHandle = True)
	Local $t_ExitCode = DllStructCreate("int") ; Its the container for the exit code
	DllCall("kernel32.dll", "int", "GetExitCodeProcess", "ptr", $hProcessHandle, "ptr", DllStructGetPtr($t_ExitCode)) ; Store the exit code in the container
	If @error Then Return SetError(1, 0, 0) ; If it is a invalid $hProcessHandle then return error
	If $bCloseHandle Then _Process_CloseHandle($hProcessHandle) ; Close the $hProcessHandle
	Return DllStructGetData($t_ExitCode, 1) ; Return exit code from the container
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Process_DebugRunCommand
; Description ...: Debugs a command in CMD style, see the example.
; Syntax ........: _Process_DebugRunCommand($hProcessHandle, $iPID[, $sGuiTitle = "Command Prompt Simulator"])
; Parameters ....: $hProcessHandle      - The Process Handle.
;                  $iPID                - The PID of the Process.
;                  $sGuiTitle           - [optional] The title of the Debug window. Default is "Command Prompt Simulator".
; Return values .: Success: Will return the output & @extended will contain the exit code for the function
;                  Failure: N/A
; Author ........: TheDcoder
; Modified ......: N/A
; Remarks .......: Make sure that the Process Handle & the PID are of the same process, otherwise you get the wrong exit code :P
; Example .......: Yes, see example.au3
; ===============================================================================================================================
Func _Process_DebugRunCommand($hProcessHandle, $iPID, $sGuiTitle = "Command Prompt Simulator")
	Local $aGrayCmdColor[3] = [197, 197, 197] ; CMD Text Color's combination in RGB
	Local Const $iGrayCmdColor = _ColorSetRGB($aGrayCmdColor) ; Get the RGB code of CMD Text Color
	Local $hGUI = GUICreate($sGuiTitle, 639, 299, -1, -1, $WS_OVERLAPPEDWINDOW) ; Create the GUI
	Local $idEdit = GUICtrlCreateEdit("", 0, 0, 639, 299, BitOR($WS_HSCROLL, $WS_VSCROLL, $ES_MULTILINE, $ES_READONLY, $ES_AUTOVSCROLL), 0) ; Create the Edit control :)
	Global $g__hEdit = GUICtrlGetHandle($idEdit) ; Get the edit control's handle
	GUICtrlSetBkColor($idEdit, $COLOR_BLACK) ; Set the background color
	GUICtrlSetColor($idEdit, $iGrayCmdColor) ; Set the text color
	GUICtrlSetFont($idEdit, 8, 0, 0, "Fixedsys")
	GUIRegisterMsg($WM_SIZE, "__Process_WM_SIZE") ; Register the resizing function
	GUISetState(@SW_SHOW, $hGUI) ; Reveal the GUI
	_GUICtrlEdit_AppendText($g__hEdit, "The Process: " & _Process_GetPath($iPID) & @CRLF) ; Append the process information
	Local $sOutput = "", $sPartialOutput = "" ; Declare the output variable
	While ProcessExists($iPID) ; Loop until the process finishes
		$sPartialOutput = StdoutRead($iPID) ; Record the output
		$sOutput &= $sPartialOutput
		_GUICtrlEdit_AppendText($g__hEdit, $sPartialOutput) ; Append the output
		Sleep(250) ; Don't kill the CPU
	WEnd
	$sPartialOutput = StdoutRead($iPID) ; Record the output
	$sOutput &= $sPartialOutput
	_GUICtrlEdit_AppendText($g__hEdit, $sPartialOutput) ; Append any remaining chunks of output
	Local $iExitCode = _Process_GetExitCode($hProcessHandle)
	_GUICtrlEdit_AppendText($g__hEdit, @CRLF & @CRLF & "Debug Complete! The Exit Code was: " & $iExitCode) ; Display the exit code
	; Same steps as in the above loop
	Local $nMsg = 0
	While 1 ; Wait for user to close the window
		$nMsg = GUIGetMsg()
		Switch $nMsg
			Case $GUI_EVENT_CLOSE
				ExitLoop
		EndSwitch
	WEnd
	GUIDelete($hGUI) ; Delete the GUI
	Return SetExtended($iExitCode, $sOutput) ; Return True
EndFunc

Func __Process_WM_SIZE($hWnd, $iMsg, $wParam, $lParam)
	Local $iWidth = _WinAPI_LoWord($lParam)
	Local $iHeight = _WinAPI_HiWord($lParam)

	_WinAPI_MoveWindow($g__hEdit, 2, 2, $iWidth - 4, $iHeight - 4)

	Return 0
	#forceref $hWnd, $iMsg, $wParam
EndFunc   ; Thanks Mat :)