; #FUNCTION# ====================================================================================================================
; Name ..........: IniReadWrite
; Description ...: Write the default value to Ini if it does not exist
; Syntax ........: IniReadWrite($sFile, $sSection, $sKey, $sDefault)
; Parameters ....: $sFile               - The path for the .ini file.
;                  $sSection            - The section name in the .ini file.
;                  $sKey                - The key name in the .ini file.
;                  $sDefault            - The default value.
; Return values .: The value of the $sKey in the Ini file or $sDefault if the $sKey does not exists
; Author ........: Damon Harris (TheDcoder)
; Remarks .......: PRO TIP: IniReadWrite is fully compatible with IniRead (i.e Same parameters)
; Related .......: IniRead and IniWrite
; Link ..........: https://gist.github.com/TheDcoder/b5035d600b7a130ea45311541a15a555
; Example .......: No
; ===============================================================================================================================
Func IniReadWrite($sFile, $sSection, $sKey, $sDefault)
	Local $sIniRead = IniRead($sFile, $sSection, $sKey, "")
	If Not $sIniRead = "" Then Return $sIniRead
	IniWrite($sFile, $sSection, $sKey, $sDefault)
	Return $sDefault
EndFunc
