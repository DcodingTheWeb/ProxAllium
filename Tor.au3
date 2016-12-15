#include-once
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
; _Tor_CheckVersion - Check the version of Tor.
; _Tor_SetPath      - Sets Tor.exe's path, it will be used by the UDF in the rest of the functions.
; _Tor_Start        - Starts Tor
; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================
Global Const $TOR_ERROR_GENERIC = 1 ; Reserved for generic errors.
Global Const $TOR_ERROR_PROCESS = 2 ; Error related to Tor.exe's process.
Global Const $TOR_ERROR_VERSION = 3

Global Enum $TOR_VERSION, $TOR_VERSION_NUMBER, $TOR_VERSION_GIT

Global Enum $TOR_PROCESS_PID, $TOR_PROCESS_HANDLE ; Associated with $aTorProcess returned by _Tor_Start
; ===============================================================================================================================

; #VARIABLES# ===================================================================================================================
Global $g__sTorPath = "" ; Path to Tor.exe
; ===============================================================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_CheckVersion
; Description ...: Check the version of Tor.
; Syntax ........: _Tor_CheckVersion()
; Parameters ....: None
; Return values .: Success: $aTorVersion with 3 elements:
;                           $aTorVersion[$TOR_VERSION]        - Will contain the full version string, see remarks for the format.
;                           $aTorVersion[$TOR_VERSION_NUMBER] - Will contain the version number in this format: x.x.x.x
;                           $aTorVersion[$TOR_VERSION_GIT]    - Will contain Git's truncated hash of the commit.
;                  Failure: False and @error set to:
;                           $TOR_ERROR_PROCESS - If it is an invalid Tor path.
;                           $TOR_ERROR_VERSION - If unable to determine version, @extended is set to StringRegExp's @error.
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: $TOR_VERSION Format : x.x.x.x (git-a1b2c3d4e5f6g7h8)
;                               Example: 0.2.8.11 (git-31e7b47fbebe8caf)
; Example .......: No
; ===============================================================================================================================
Func _Tor_CheckVersion()
	Local $sOutput = _Process_RunCommand($PROCESS_RUNWAIT + $PROCESS_DEBUG, $g__sTorPath & ' --version')
	If @error Then Return SetError($TOR_ERROR_PROCESS, @error, False)
	Local $aTorVersion = StringRegExp($sOutput, '([0-9]*\.[0-9]*\.[0-9]*\.[0-9]*) \(git-([a-z0-9]{16})\)', $STR_REGEXPARRAYFULLMATCH)
	If @error Then Return SetError($TOR_ERROR_VERSION, @error, False)
	Return $aTorVersion
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
;                  2. The existing path assigned to Tor.exe will not change if _Tor_SetPath fails
;                  3. Use $bVerify = False to force the s
; Example .......: No
; ===============================================================================================================================
Func _Tor_SetPath($sTorPath, $bVerify = True)
	If Not $bVerify Then
		$g__sTorPath = FileGetLongName($sTorPath)
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
;                  Failure: False and @error set to $TOR_ERROR_PROCESS
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: $aTorProcess's Format:
;                  $aTorProcess[$TOR_PROCESS_HANDLE] - Contains the process handle of tor.exe
;                  $aTorProcess[$TOR_PROCESS_PID]    - Contains the PID of tor.exe
; Example .......: No
; ===============================================================================================================================
Func _Tor_Start($sConfig)
	Local $aTorProcess[2]
	$aTorProcess[$TOR_PROCESS_HANDLE] = _Process_RunCommand($PROCESS_RUN, '"' & $g__sTorPath & '" --allow-missing-torrc --defaults-torrc "" -f "' & $sConfig & '"', @ScriptDir)
	If @error Then Return SetError($TOR_ERROR_PROCESS, @error, False)
	$aTorProcess[$TOR_PROCESS_PID] = @extended
	Return $aTorProcess
EndFunc