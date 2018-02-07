#include-once
#include <File.au3>
#include <FileConstants.au3>
#include <StringConstants.au3>
#include "ProcessEx.au3"

#AutoIt3Wrapper_Au3Check_Parameters=-q -d -w 1 -w 2 -w 3 -w- 4 -w 5 -w 6 -w- 7

; #INDEX# =======================================================================================================================
; Title ............: Tor UDF.
; AutoIt Version ...: 3.3.14.1
; Description ......: UDF for Tor, meant to be used by ProxAllium. Not the best Tor UDF around ;)
; Author(s) ........: Damon Harris (TheDcoder).
; This UDF Uses ....: Process UDF (439a393) - https://git.io/vXmF6
; Links ............: GitHub                - https://github.com/DcodingTheWeb/ProxAllium/blob/master/Tor.au3
; ===============================================================================================================================

; #CURRENT# =====================================================================================================================
; _Tor_CheckVersion                  - Check the version of Tor.
; _Tor_Controller_Authenticate       - Authenticate with the Tor controller
; _Tor_Controller_CheckReplyForError - Check for errors in a reply/response from the controller
; _Tor_Controller_Connect            - Connect to Tor's TCP controller interface
; _Tor_Controller_SendRaw            - Send raw commands to the controller interface
; _Tor_Controller_TakeOwnership      - Take ownership of the Tor process (Tor closes if it loses the connection)
; _Tor_Controller_WaitForMsg         - Wait for a message to arrive completely and get it
; _Tor_GenHash                       - Generate a hash for use with Tor
; _Tor_Find                          - Lists the tor executables and geoip files.
; _Tor_SetPath                       - Sets Tor.exe's path, it will be used by the UDF in the rest of the functions.
; _Tor_Start                         - Starts Tor
; _Tor_Stop                          - Stops Tor
; _Tor_SwitchCircuit                 - Switch Tor to clean circuits so new application requests don't share any circuits with old ones
; _Tor_VerifyConfig                  - Check if the configuration is valid.
; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================
Global Const $TOR_ERROR_GENERIC = 1 ; Reserved for generic errors.
Global Const $TOR_ERROR_PROCESS = 2 ; Error related to Tor.exe's process.
Global Const $TOR_ERROR_VERSION = 3 ; Error related to version.
Global Const $TOR_ERROR_CONFIG = 4 ; Error related to configuration.
Global Const $TOR_ERROR_NETWORK = 5 ; Error related to networking (TCP).
Global Const $TOR_ERROR_CONTROLLER = 6 ; Error related to the Tor controller.

Global Enum $TOR_VERSION, $TOR_VERSION_NUMBER, $TOR_VERSION_GIT ; Associated with $aTorVersion returned by _Tor_CheckVersion
Global Enum $TOR_PROCESS_PID, $TOR_PROCESS_HANDLE, $TOR_PROCESS_SOCKET ; Associated with $aTorProcess returned by _Tor_Start
Global Enum $TOR_CONTROLLER_AUTH_NONE, $TOR_CONTROLLER_AUTH_HASH ; Methods of authentication with Tor controller
Global Enum $TOR_FIND_VERSION, $TOR_FIND_PATH ; Associated with $aList returned by _Tor_Find
Global Enum $TOR_FIND_TORLIST, $TOR_FIND_GEOIP, $TOR_FIND_GEOIP6 ; Associated with arrays found inside $aList returned by _Tor_Find
; ===============================================================================================================================

; #VARIABLES# ===================================================================================================================
Global $g__sTorPath = "" ; Path to Tor.exe
; ===============================================================================================================================

TCPStartup()
OnAutoItExitRegister(__Tor_OnExitTCPShutdown)

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_CheckVersion
; Description ...: Check the version of Tor.
; Syntax ........: _Tor_CheckVersion([$sTorPath = $g__sTorPath])
; Parameters ....: $sTorPath            - [optional] Path of Tor's executable. Default is $g__sTorPath.
; Return values .: Success: $aTorVersion with 3 elements:
;                           $aTorVersion[$TOR_VERSION]        - Will contain the full version string, see remarks for the format.
;                           $aTorVersion[$TOR_VERSION_NUMBER] - Will contain the version number in this format: x.x.x.x
;                           $aTorVersion[$TOR_VERSION_GIT]    - Will contain Git's truncated hash of the commit.
;                  Failure: False and @error set to:
;                           $TOR_ERROR_PROCESS - If it is an invalid Tor path.
;                           $TOR_ERROR_VERSION - If unable to determine version, @extended is set to StringRegExp's @error.
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: $TOR_VERSION Format : x.x.x.x (git-a1b2c3d4e5f6g7h8)
;                               Example: 0.2.9.10 (git-1f6c8eda0073f464)
;                  The git hash may not be present at all times.
; Example .......: No
; ===============================================================================================================================
Func _Tor_CheckVersion($sTorPath = $g__sTorPath)
	Local $sOutput = _Process_RunCommand($PROCESS_RUNWAIT, $sTorPath & ' --version')
	If @error Then Return SetError($TOR_ERROR_PROCESS, @error, False)
	Local $aTorVersion[3]
	Local $aRegEx = StringRegExp($sOutput, '(\d*\.\d*\.\d*\.\d*)(?: \(git-([a-z0-9]{16})\))?', $STR_REGEXPARRAYFULLMATCH)
	If @error Then Return SetError($TOR_ERROR_VERSION, @error, False)
	$aTorVersion[$TOR_VERSION] = $aRegEx[0]
	$aTorVersion[$TOR_VERSION_NUMBER] = $aRegEx[1]
	If UBound($aRegEx) = 3 Then $aTorVersion[$TOR_VERSION_GIT] = $aRegEx[2]
	Return $aTorVersion
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_Controller_Authenticate
; Description ...: Authenticate with the Tor controller
; Syntax ........: _Tor_Controller_Authenticate(Byref $aTorProcess[, $iMethod = $TOR_CONTROLLER_AUTH_NONE[, $vPassword = ""]])
; Parameters ....: $aTorProcess         - [in/out] $aTorProcess from _Tor_Start.
;                  $iMethod             - [optional] One of the $TOR_CONTROLLER_AUTH constants. Default is $TOR_CONTROLLER_AUTH_NONE.
;                  $vPassword           - [optional] Password. Default is "" (None).
; Return values .: Success: True
;                  Failure: @error is set to:
;                           $TOR_ERROR_NETWORK - If there was a network error, @extended is set to TCPSend or TCPRecv's error.
;                           $TOR_ERROR_CONTROLLER - If Tor replied with an unexpected response, the response string is returned.
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: This should be the second step after _Tor_Controller_Connect
; Example .......: No
; ===============================================================================================================================
Func _Tor_Controller_Authenticate(ByRef $aTorProcess, $iMethod = $TOR_CONTROLLER_AUTH_NONE, $vPassword = "")
	Local $sRawCommand = "AUTHENTICATE"
	If $iMethod = $TOR_CONTROLLER_AUTH_HASH Then $sRawCommand &= ' "' & $vPassword & '"'
	_Tor_Controller_SendRaw($aTorProcess, $sRawCommand)
	If @error Then Return SetError($TOR_ERROR_NETWORK, @extended, False)
	Local $sResponse = _Tor_Controller_WaitForMsg($aTorProcess)
	If @error Then Return SetError($TOR_ERROR_NETWORK, @extended, False)
	_Tor_Controller_CheckReplyForError($sResponse)
	If Not @error Then Return True
	Return SetError($TOR_ERROR_CONTROLLER, 0, $sResponse)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_Controller_CheckReplyForError
; Description ...: Check for errors in a reply/response from the controller
; Syntax ........: _Tor_Controller_CheckReplyForError($sReply)
; Parameters ....: $sReply              - The reply or response from the controller server.
; Return values .: Success: True
;                  Failure: False and @error set to $TOR_ERROR_GENERIC, @extended is set to 1 if error is fatal.
;                  Special: @extended is set to 2 and @error is not set, this happens if the status is unknown.
; Author ........: Damon Harris (TheDcoder)
; Example .......: No
; ===============================================================================================================================
Func _Tor_Controller_CheckReplyForError($sReply)
	Local $aReply = StringSplit($sReply, ' ')
	Local $sStatusCode = $aReply[1]
	Switch StringLeft($sStatusCode, 1)
		Case "2" ; All OK
			Return True
		Case "4" ; Temporary Negative (Non-fatal error)
			Return SetError($TOR_ERROR_GENERIC, 0, False)
		Case "5" ; Permanent Negetive (Fatal error)
			Return SetError($TOR_ERROR_GENERIC, 1, False)
		Case Else ; Unknown error status (error???)
			Return SetExtended(2, False)
	EndSwitch
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_Controller_Connect
; Description ...: Connect to Tor's TCP controller interface
; Syntax ........: _Tor_Controller_Connect(Byref $aTorProcess, $iPort[, $sAddress = '127.0.0.1'])
; Parameters ....: $aTorProcess         - [in/out] $aTorProcess from _Tor_Start.
;                  $iPort               - The port where the controller interface is listening.
;                  $sAddress            - [optional] IP Address of the host. Default is '127.0.0.1'.
; Return values .: Success: True
;                  Failure: False and @error is set to TCPConnect's @error
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: Autentication should be done before beginning the communication
; Example .......: No
; ===============================================================================================================================
Func _Tor_Controller_Connect(ByRef $aTorProcess, $iPort, $sAddress = '127.0.0.1')
	Local $iSocket = TCPConnect($sAddress, $iPort)
	If @error Then Return SetError(@error, 0, False)
	$aTorProcess[$TOR_PROCESS_SOCKET] = $iSocket
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_Controller_SendRaw
; Description ...: Send raw commands to the controller interface
; Syntax ........: _Tor_Controller_SendRaw($aTorProcess, $sRawCommand[, $bAutoCRLF = True])
; Parameters ....: $aTorProcess         - $aTorProcess from _Tor_Start.
;                  $sRawCommand         - The string containing the raw command, CRLF is optional by default.
;                  $bAutoCRLF           - [optional] If True, CRLF is automatically appended before sending the command. Default is True.
; Return values .: Success: True
;                  Failure: False and @error is set to $TOR_ERROR_NETWORK & @extended is set to TCPSend's @error
; Author ........: Damon Harris (TheDcoder)
; Example .......: No
; ===============================================================================================================================
Func _Tor_Controller_SendRaw(ByRef $aTorProcess, $sRawCommand, $bAutoCRLF = True)
	If $bAutoCRLF Then $sRawCommand &= @CRLF
	TCPSend($aTorProcess[$TOR_PROCESS_SOCKET], $sRawCommand)
	If @error Then Return SetError($TOR_ERROR_NETWORK, @error, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_Controller_TakeOwnership
; Description ...: Take ownership of the Tor process (Tor closes if it loses the connection)
; Syntax ........: _Tor_Controller_TakeOwnership($aTorProcess)
; Parameters ....: $aTorProcess         - [in/out] $aTorProcess from _Tor_Start.
; Return values .: Success: True
;                  Failure: False, @error set to:
;                           $TOR_ERROR_GENERIC - If controller sent a reply indicating an error and @extended is
;                                                set to _Tor_Controller_CheckReplyForError's @extended
;                           $TOR_ERROR_NETWORK - If a network error occurs, @extended is set to TCPSend/TCPRecv's @error
; Author ........: Damon Harris (TheDcoder)
; Example .......: No
; ===============================================================================================================================
Func _Tor_Controller_TakeOwnership($aTorProcess)
	_Tor_Controller_SendRaw($aTorProcess, 'TAKEOWNERSHIP')
	If @error Then Return SetError($TOR_ERROR_NETWORK, @extended, False)
	Local $sReply = _Tor_Controller_WaitForMsg($aTorProcess)
	If @error Then Return SetError($TOR_ERROR_NETWORK, @extended, False)
	_Tor_Controller_CheckReplyForError($sReply)
	If @error Then Return SetError($TOR_ERROR_GENERIC, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_Controller_WaitForMsg
; Description ...: Wait for a message to arrive completely and get it
; Syntax ........: _Tor_Controller_WaitForMsg(Byref $aTorProcess[, $iTimeout = 0[, $bTrimCRLF = True]])
; Parameters ....: $aTorProcess         - [in/out] $aTorProcess from _Tor_Start.
;                  $iTimeout            - [optional] Timeout in milliseconds. Default is 0 (no timeout).
;                  $bTrimCRLF           - [optional] Trim the trailing CRLF in the message. Default is True.
; Return values .: Success: $sMessage
;                  Failure: $sMessage (can be blank or contain partial content) and @error is set to:
;                           $TOR_ERROR_NETWORK - If TCPRecv set an error, @extended is set to TCPRecv's @error
;                           $TOR_ERROR_GENERIC - If $iTimeout is reached
; Author ........: Damon Harris (TheDcoder)
; Example .......: No
; ===============================================================================================================================
Func _Tor_Controller_WaitForMsg(ByRef $aTorProcess, $iTimeout = 0, $bTrimCRLF = True)
	Local $sMessage
	If $iTimeout > 0 Then Local $hTimer = TimerInit()
	Do
		$sMessage &= TCPRecv($aTorProcess[$TOR_PROCESS_SOCKET], 2)
		If @error Then Return SetError($TOR_ERROR_NETWORK, @error, $sMessage)
		If ($iTimeout > 0) And (TimerDiff($hTimer) >= $iTimeout) Then Return SetError($TOR_ERROR_GENERIC, 0, $sMessage)
		Sleep(10)
	Until (StringRight($sMessage, 2) = @CRLF)
	Return ($bTrimCRLF ? StringTrimRight($sMessage, 2) : $sMessage)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_Find
; Description ...: Lists the tor executables and geoip files.
; Syntax ........: _Tor_Find($vFolders)
; Parameters ....: $vFolders            - $vFolders to search. Can be an array or a string delimited by a pipe charecter (|)
; Return values .: Success: $aList, See remarks for format.
;                  Failure: False and @error set to $TOR_ERROR_GENERIC
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: 1. $aList is an array with 3 elements:
;                     $aList[$TOR_FIND_TORLIST] - This element contains the list of tor executables
;                     $aList[$TOR_FIND_GEOIP]   - This element contains the list of GeoIP files
;                     $aList[$TOR_FIND_GEOIP6]  - This element contains the list of GeoIP6 files
;                     Each of the elements are made up of 2 columns
;                     $TOR_FIND_VERSION - This column contains the version of the found file
;                     $TOR_FIND_PATH    - This column contains the path fo the found file
;                  2. This function can take some time to return.
;                  3. Arrays inside $aList are not sorted!
; Example .......: No
; ===============================================================================================================================
Func _Tor_Find($vFolders)
	If IsString($vFolders) Then $vFolders = StringSplit($vFolders, '|', $STR_NOCOUNT)
	Local $aFiles[0]
	For $sFolder In $vFolders
		_ArrayConcatenate($aFiles, _FileListToArrayRec($sFolder, "tor.exe;geoip;geoip6", $FLTAR_FILES, $FLTAR_RECUR, $FLTAR_NOSORT, $FLTAR_FULLPATH), 1)
	Next
	If UBound($aFiles) = 0 Then Return SetError($TOR_ERROR_GENERIC, 0, False)
	Local $aTorList[0][2]
	Local $aGeoIP[0][2]
	Local $aGeoIPv6[0][2]
	Local $aPath
	Local $aTorVersion[0]
	Local $aGeoFileDate[0]
	For $sFile In $aFiles
		$aPath = _PathSplit($sFile, $vFolders, $vFolders, $vFolders, $vFolders) ; $vFolders is just used as a dummy here
		Switch $aPath[3]
			Case "tor"
				$aTorVersion = _Tor_CheckVersion($sFile)
				If Not @error Then _ArrayAdd($aTorList, $aTorVersion[$TOR_VERSION_NUMBER] & '|' & $sFile)

			Case "geoip", "geoip6"
				$aGeoFileDate = StringRegExp(FileReadLine($sFile), '([A-Z][a-z]*) ([\d]{1,2}) (\d{4})', $STR_REGEXPARRAYMATCH)
				If Not @error Then
					Switch $aPath[3]
						Case "geoip"
							_ArrayAdd($aGeoIP, _ArrayToString($aGeoFileDate, ' ') & '|' & $sFile)
						Case "geoip6"
							_ArrayAdd($aGeoIPv6, _ArrayToString($aGeoFileDate, ' ') & '|' & $sFile)
					EndSwitch
				EndIf
		EndSwitch
	Next
	Local $aList[3] = [$aTorList, $aGeoIP, $aGeoIPv6]
	Return $aList
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_GenHash
; Description ...: Generate a hash for use with Tor
; Syntax ........: _Tor_GenHash($sString)
; Parameters ....: $sString             - The string for which will the hash be calculated.
; Return values .: Success: $aHash (See Remarks)
;                  Failure: False and @error is set to:
;                           $TOR_ERROR_PROCESS - If Tor didn't launch or run successfully
;                           $TOR_ERROR_GENERIC - If the hash was not found in the output
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: $aHash is an array with 3 elements:
;                  $aHash[0] - Contains the full hash (16:660537E3E1CD49996044A3BF558097A981F539FEA2F9DA662B4626C1C2)
;                  $aHash[1] - Contains the salt of the hash (660537E3E1CD4999)
;                  $aHash[2] - Contains the salted hash (44A3BF558097A981F539FEA2F9DA662B4626C1C2)
; Example .......: No
; ===============================================================================================================================
Func _Tor_GenHash($sString)
	Local $sOutput = _Process_RunCommand($PROCESS_RUNWAIT, $g__sTorPath & ' --hash-password "' & $sString & '"')
	If @error Then Return SetError($TOR_ERROR_PROCESS, @error, False)
	Local $aHash = StringRegExp($sOutput, '16:([A-Z0-9]{16})60([A-Z0-9]{40})', $STR_REGEXPARRAYFULLMATCH)
	If @error Then Return SetError($TOR_ERROR_GENERIC, @error, False)
	Return $aHash
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_SetPath
; Description ...: Sets Tor.exe's path, it will be used by the UDF in the rest of the functions.
; Syntax ........: _Tor_SetPath($sTorPath[, $bVerify = True])
; Parameters ....: $sTorPath            - Path of Tor.exe, can be relative or short. See Remarks.
;                  $bVerify             - [optional] If set to False, no checkes are performed. Default is True.
; Return values .: Success: $aTorVersion from _Tor_CheckVersion or True if $bVerify is False.
;                  Failure: False and @error set to:
;                           $TOR_ERROR_GENERIC - If $sTorPath does not exist
;                           $TOR_ERROR_VERSION - If _Tor_CheckVersion failed to check Tor's version, @extended is set to _Tor_CheckVersion's @error.
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: 1. The $sTorPath will always be converted to a long and absolute path before getting assinged.
;                  2. The existing path assigned to Tor.exe will not change if _Tor_SetPath fails.
;                  3. Set $bVerify to False to skip the version check, you will never get failure if you use this method.
; Example .......: No
; ===============================================================================================================================
Func _Tor_SetPath($sTorPath, $bVerify = True)
	If Not $bVerify Then
		$g__sTorPath = $sTorPath
		Return True
	EndIf
	If Not FileExists($sTorPath) Then Return SetError($TOR_ERROR_GENERIC, 0, False)
	Local $sOldTorPath = $g__sTorPath
	$g__sTorPath = $sTorPath
	Local $aTorVersion = _Tor_CheckVersion()
	If @error Then
		$g__sTorPath = $sOldTorPath
		Return SetError($TOR_ERROR_VERSION, @error, False)
	EndIf
	Return $aTorVersion
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_Start
; Description ...: Starts Tor
; Syntax ........: _Tor_Start($sConfig)
; Parameters ....: $sConfig             - Path to the config/torrc file.
; Return values .: Success: $aTorProcess, See Remarks.
;                  Failure: $sCommand used to execute Tor and @error set to:
;                           $TOR_ERROR_PROCESS - If there was a problem starting the process
;                           $TOR_ERROR_CONFIG  - If there was a problem during verification of the $sConfig
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: $aTorProcess's Format:
;                  $aTorProcess[$TOR_PROCESS_HANDLE] - Contains the process handle of tor.exe
;                  $aTorProcess[$TOR_PROCESS_PID]    - Contains the PID of tor.exe
;                  $aTorProcess[$TOR_PROCESS_SOCKET] - Reserved for the TCP socket, used by _Tor_Controller functions
; Example .......: No
; ===============================================================================================================================
Func _Tor_Start($sConfig)
	_Tor_VerifyConfig($sConfig)
	If @error Then Return SetError($TOR_ERROR_CONFIG, @error, False)
	Local $aTorProcess[3]
	Local $sCommand = '"' & $g__sTorPath & '" --allow-missing-torrc --defaults-torrc "" -f "' & $sConfig & '"'
	$aTorProcess[$TOR_PROCESS_HANDLE] = _Process_RunCommand($PROCESS_RUN, $sCommand, @ScriptDir)
	If @error Then Return SetError($TOR_ERROR_PROCESS, @error, $sCommand)
	$aTorProcess[$TOR_PROCESS_PID] = @extended
	Return $aTorProcess
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_Stop
; Description ...: Stops Tor
; Syntax ........: _Tor_Stop(Byref $aTorProcess)
; Parameters ....: $aTorProcess         - [in/out] $aTorProcess from _Tor_Start.
; Return values .: Success: True and $aTorProcess is modified, See Remarks.
;                  Failure: False, @error set to:
;                           $TOR_ERROR_GENERIC - If $aTorProcess is invalid (does not contain 3 elements).
;                           $TOR_ERROR_PROCESS - If ProcessClose fails, @extended is set to ProcessClose's @error
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: Tor is sent the shutdown signal first (using TCP) and if it fails, it is closed forcibly by ProcessClose
;                  $aTorProcess[$TOR_PROCESS_PID] and $aTorProcess[$TOR_PROCESS_HANDLE] are set to 0 which help avoid conflict
; Related .......: _Tor_Start
; Example .......: No
; ===============================================================================================================================
Func _Tor_Stop(ByRef $aTorProcess)
	If UBound($aTorProcess) <> 3 Then Return SetError($TOR_ERROR_GENERIC, 0, False)
	_Tor_Controller_SendRaw($aTorProcess, 'SIGNAL SHUTDOWN')
	If Not @error Then
		Local $sResponse = _Tor_Controller_WaitForMsg($aTorProcess)
		If Not @error Then
			_Tor_Controller_CheckReplyForError($sResponse)
			If Not @error Then Return
		EndIf
	Else
		ProcessClose($aTorProcess[$TOR_PROCESS_PID]) ; Force closure
		If @error Then Return SetError($TOR_ERROR_PROCESS, @error, False)
	EndIf
	$aTorProcess[$TOR_PROCESS_PID] = 0
	_Process_CloseHandle($aTorProcess[$TOR_PROCESS_HANDLE])
	$aTorProcess[$TOR_PROCESS_HANDLE] = 0
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_SwitchCircuit
; Description ...: Switch Tor to clean circuits so new application requests don't share any circuits with old ones
; Syntax ........: _Tor_SwitchCircuit(Byref $aTorProcess)
; Parameters ....: $aTorProcess         - [in/out] $aTorProcess from _Tor_Start.
; Return values .: Success: True
;                  Failure: False, @error set to:
;                           $TOR_ERROR_GENERIC - If controller sent a reply indicating an error and @extended is
;                                                set to _Tor_Controller_CheckReplyForError's @extended
;                           $TOR_ERROR_NETWORK - If a network error occurs, @extended is set to TCPSend/TCPRecv's @error
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: Tor may rate-limit this action so use it responsibly
; Example .......: No
; ===============================================================================================================================
Func _Tor_SwitchCircuit(ByRef $aTorProcess)
	_Tor_Controller_SendRaw($aTorProcess, 'SIGNAL NEWNYM')
	If @error Then Return SetError($TOR_ERROR_NETWORK, @extended, False)
	Local $sReply = _Tor_Controller_WaitForMsg($aTorProcess)
	If @error Then Return SetError($TOR_ERROR_NETWORK, @extended, False)
	_Tor_Controller_CheckReplyForError($sReply)
	If @error Then Return SetError($TOR_ERROR_GENERIC, @extended, False)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_VerifyConfig
; Description ...: Check if the configuration is valid.
; Syntax ........: _Tor_VerifyConfig($sConfig)
; Parameters ....: $sConfig             - a Path to the config/torrc file.
; Return values .: Success: True
;                  Failure: False and @error set to $TOR_ERROR_CONFIG
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: This function just perfroms a bare-minimum check
; Example .......: No
; ===============================================================================================================================
Func _Tor_VerifyConfig($sConfig)
	Local $sOutput = _Process_RunCommand($PROCESS_RUNWAIT, '"' & $g__sTorPath & '" --verify-config --allow-missing-torrc --defaults-torrc "" -f "' & $sConfig & '"', @ScriptDir)
	If @error Then Return SetError($TOR_ERROR_PROCESS, @error, False)
	Local $aOutput = StringSplit(StringStripWS($sOutput, $STR_STRIPTRAILING), @CRLF, $STR_ENTIRESPLIT)
	If $aOutput[$aOutput[0]] = "Configuration was valid" Then Return True
	Return SetError($TOR_ERROR_CONFIG, 0, False)
EndFunc

Func __Tor_OnExitTCPShutdown()
	TCPShutdown()
EndFunc
