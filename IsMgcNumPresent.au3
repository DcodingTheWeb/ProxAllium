; #FUNCTION# ====================================================================================================================
; Name ..........: IsMgcNumPresent
; Description ...: Checks if a number is a present in a number (Magic numbers aka Powers of 2)
; Syntax ........: IsMgcNumPresent($iNumber, $iMagicNumber)
; Parameters ....: $iNumber             - Number to check if it exists in $iMagicNumber.
;                  $iMagicNumber        - The number which might contain $iNumber.
; Return values .: Success: True
;                  Failure: False
; Author ........: Damon Harris (TheDcoder)
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........: https://git.io/vPFjk
; Example .......: Yes, see IsMgcNumPresent_Example.au3
; ===============================================================================================================================
Func IsMgcNumPresent($iNumber, $iMagicNumber)
    Return BitAND($iMagicNumber, $iNumber) = $iNumber
EndFunc