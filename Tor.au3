#include-once
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
; _Tor_SetPath - Sets Tor.exe's path, it will be used by the UDF in the rest of the functions.
; ===============================================================================================================================

; #VARIABLES# ===================================================================================================================
Global $g__sTorPath = "" ; Path to Tor.exe
; ===============================================================================================================================

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