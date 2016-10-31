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
; ===============================================================================================================================

; #CONSTANTS# ===================================================================================================================
Global Const $TOR_ERROR_GENERIC = 1 ; Reserved for generic errors.
Global Const $TOR_ERROR_PROCESS = 2 ; Error related to Tor.exe's process.

Global Enum $TOR_VERSION, $TOR_VERSION_NUMBER, $TOR_VERSION_GIT
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
;                  Failure: @error set to:
;                           $TOR_ERROR_PROCESS - If it is an invalid Tor path.
;                           $TOR_ERROR_GENERIC - If it is an invalid Tor executable.
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: $TOR_VERSION Format : x.x.x.x (git-a1b2c3d4e5f6g7h8)
;                               Example: 0.2.8.7 (git-263088633a63982a)
; Example .......: No
; ===============================================================================================================================
Func _Tor_CheckVersion()
	Local $sOutput = _Process_RunCommand($PROCESS_RUNWAIT, $g__sTorPath & ' --version')
	If @error Then Return SetError($TOR_ERROR_PROCESS, @error, "")
	Local $aTorVersion = StringRegExp($sOutput, '(.\..\..\..) \(git-([a-z0-9]*)\)', $STR_REGEXPARRAYFULLMATCH)
	If @error Then Return SetError($TOR_ERROR_GENERIC, 1, False)
	Return $aTorVersion
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _Tor_SetPath
; Description ...: Sets Tor.exe's path, it will be used by the UDF in the rest of the functions.
; Syntax ........: _Tor_SetPath($sTorPath)
; Parameters ....: $sTorPath            - Path of Tor.exe, can be relative or short. See Remarks.
; Return values .: Success: True
;                  Failure: False - Fails if the file does not exist.
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: The path will always be converted to a long and absolute path before getting assinged.
; Example .......: No
; ===============================================================================================================================
Func _Tor_SetPath($sTorPath)
	If Not FileExists($sTorPath) Then Return SetError(1, 0, False)
	$g__sTorPath = FileGetLongName($sTorPath)
	Return True
EndFunc