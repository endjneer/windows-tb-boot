' ===========================================================================
' thunderbolt-boot-on.vbs
'
' Reads and, if needed, enables the hidden Dell BIOS attribute
' "ThunderboltBoot" (Enable Thunderbolt Boot Support) through the Dell BIOS
' WMI interface, namespace root\dcim\sysman\biosattributes.
' Needed after a BIOS update or reset, when the external SSD disappears from
' the F12 boot menu.
'
' Works in Windows (Command Prompt as administrator) and in the Windows
' Recovery Environment (WinRE), where PowerShell is not available.
' Run it with cscript, not wscript.
'
' Usage:  cscript //nologo thunderbolt-boot-on.vbs [/status] [/it | /en]
'   no options : reads the value and, if needed, sets it to Enabled
'   /status    : read only, changes nothing
'   /it, /en   : message language (default: Italian if the system language
'                is Italian, English otherwise)
'
' Exit codes:
'   /status      0 = Enabled, 2 = not Enabled, 1 = error
'   no options   0 = Enabled (already, or set now), 1 = error
'
' The write calls SetAttribute on an instance of BIOSAttributeInterface with
' SecType = 0 and SecHndCount = 0, that is without a BIOS password; SecHandle
' is not set. This call was verified from WinRE on a Dell notebook after a
' BIOS update (minimal script, 30/10/2026). This file as a whole: not
' verified yet.
' If a BIOS administrator password is set, the BIOS refuses the write
' (Status = 3): this script does not handle passwords.
' ===========================================================================
Option Explicit

Const ATTR = "ThunderboltBoot"
Const WANT = "Enabled"
Const NS = "root\dcim\sysman\biosattributes"

' WMI and Windows error codes (HRESULT)
Const WBEM_E_ACCESS_DENIED = &H80041003
Const E_ACCESSDENIED = &H80070005
Const WBEM_E_INVALID_NAMESPACE = &H8004100E
Const WBEM_E_INVALID_CLASS = &H80041010

Dim lang, statusOnly, badArg, i, a
lang = ""
statusOnly = False
badArg = ""
For i = 0 To WScript.Arguments.Count - 1
  a = LCase(WScript.Arguments(i))
  Select Case a
    Case "/status" : statusOnly = True
    Case "/it" : lang = "it"
    Case "/en" : lang = "en"
    Case Else : badArg = WScript.Arguments(i)
  End Select
Next
If lang = "" Then
  ' 16 = primary language ID of Italian
  If (GetLocale() And 1023) = 16 Then lang = "it" Else lang = "en"
End If

Function T(sIt, sEn)
  If lang = "it" Then T = sIt Else T = sEn
End Function

Sub Fail(msg)
  WScript.Echo msg
  WScript.Quit 1
End Sub

' Explains a WMI error and exits with code 1
Sub FailWmi(n, d)
  If n = WBEM_E_ACCESS_DENIED Or n = E_ACCESSDENIED Then
    WScript.Echo T("ERRORE: accesso negato all'interfaccia WMI del BIOS (0x" & Hex(n) & ").", _
                   "ERROR: access denied to the BIOS WMI interface (0x" & Hex(n) & ").")
    WScript.Echo T("In Windows lancia lo script da un Prompt dei comandi aperto come amministratore.", _
                   "In Windows, run the script from a Command Prompt opened as administrator.")
  ElseIf n = WBEM_E_INVALID_NAMESPACE Or n = WBEM_E_INVALID_CLASS Then
    WScript.Echo T("ERRORE: interfaccia WMI del BIOS Dell non disponibile (" & NS & ", 0x" & Hex(n) & ").", _
                   "ERROR: Dell BIOS WMI interface not available (" & NS & ", 0x" & Hex(n) & ").")
    WScript.Echo T("Il PC potrebbe non essere un Dell compatibile.", _
                   "This PC may not be a compatible Dell.")
  Else
    WScript.Echo T("ERRORE WMI 0x", "WMI ERROR 0x") & Hex(n) & ": " & d
  End If
  WScript.Quit 1
End Sub

If LCase(Right(WScript.FullName, 11)) <> "cscript.exe" Then
  WScript.Echo T("Lancia lo script con cscript: cscript //nologo thunderbolt-boot-on.vbs /status", _
                 "Run the script with cscript: cscript //nologo thunderbolt-boot-on.vbs /status")
  WScript.Quit 1
End If

If badArg <> "" Then
  WScript.Echo T("Opzione non riconosciuta: ", "Unknown option: ") & badArg
  WScript.Echo T("Uso: cscript //nologo thunderbolt-boot-on.vbs [/status] [/it oppure /en]", _
                 "Usage: cscript //nologo thunderbolt-boot-on.vbs [/status] [/it or /en]")
  WScript.Quit 1
End If

' --- Connection to the BIOS WMI interface -----------------------------------
Dim svc, errNum, errDesc
On Error Resume Next
Set svc = GetObject("winmgmts:\\.\" & NS)
errNum = Err.Number
errDesc = Err.Description
On Error GoTo 0
If errNum <> 0 Then FailWmi errNum, errDesc

' Reads the current and allowed values of the attribute.
' Returns True if the attribute exists. A WMI error ends the script (code 1),
' unless softRead is True: then it only returns False (used for the check
' after a successful write, which must not report the write as failed).
' Count forces the query to run, so that errors surface here and not
' inside For Each.
Dim softRead
softRead = False
Function ReadAttr(ByRef curVal, ByRef allowed)
  Dim q, cnt, it, v, en, ed
  curVal = ""
  allowed = ""
  cnt = 0
  On Error Resume Next
  Set q = svc.ExecQuery("SELECT * FROM EnumerationAttribute WHERE AttributeName='" & ATTR & "'")
  If Err.Number = 0 Then cnt = q.Count
  If Err.Number = 0 And cnt > 0 Then
    For Each it In q
      v = it.CurrentValue
      If IsArray(v) Then v = Join(v, ";")
      curVal = "" & v
      If IsArray(it.PossibleValue) Then allowed = Join(it.PossibleValue, ";")
      Exit For
    Next
  End If
  en = Err.Number
  ed = Err.Description
  On Error GoTo 0
  If en <> 0 Then
    If softRead Then
      ReadAttr = False
      Exit Function
    End If
    FailWmi en, ed
  End If
  ReadAttr = (cnt > 0)
End Function

' --- Reading -----------------------------------------------------------------
Dim cur, possible
If Not ReadAttr(cur, possible) Then
  Fail T("ERRORE: l'attributo " & ATTR & " non esiste in questo BIOS.", _
         "ERROR: the " & ATTR & " attribute does not exist in this BIOS.")
End If
WScript.Echo ATTR & " = " & cur & "   (" & T("valori ammessi: ", "allowed values: ") & possible & ")"

If statusOnly Then
  If LCase(cur) = LCase(WANT) Then WScript.Quit 0
  WScript.Echo T(ATTR & " non e' attivo: il firmware non vede l'SSD esterno via Thunderbolt.", _
                 ATTR & " is not enabled: the firmware cannot see the external SSD over Thunderbolt.")
  WScript.Quit 2
End If

If LCase(cur) = LCase(WANT) Then
  WScript.Echo T("Gia' attivo: nessuna modifica.", "Already enabled: nothing to change.")
  WScript.Quit 0
End If

If InStr(1, ";" & possible & ";", ";" & WANT & ";", vbTextCompare) = 0 Then
  Fail T("ERRORE: il valore " & WANT & " non e' ammesso.", "ERROR: the value " & WANT & " is not allowed.")
End If

' --- Writing: SecType = 0 and SecHndCount = 0 mean "no BIOS password" -------
' SetAttribute is called only if every previous step succeeded.
Dim items, cnt, o, p, r, st
st = -1
cnt = 0
On Error Resume Next
Set items = svc.ExecQuery("SELECT * FROM BIOSAttributeInterface")
If Err.Number = 0 Then cnt = items.Count
If Err.Number = 0 And cnt > 0 Then
  For Each o In items
    Set p = o.Methods_("SetAttribute").InParameters.SpawnInstance_()
    If Err.Number = 0 Then
      p.SecType = 0
      p.SecHndCount = 0
      p.AttributeName = ATTR
      p.AttributeValue = WANT
    End If
    If Err.Number = 0 Then Set r = o.ExecMethod_("SetAttribute", p)
    If Err.Number = 0 Then st = r.Status
    Exit For
  Next
End If
errNum = Err.Number
errDesc = Err.Description
On Error GoTo 0
If errNum <> 0 Then
  WScript.Echo T("ERRORE nella chiamata SetAttribute.", "ERROR calling SetAttribute.")
  FailWmi errNum, errDesc
End If

Select Case st
  Case 0
    WScript.Echo "Status = 0 (" & T("riuscito", "success") & ")"
  Case 1
    Fail "Status = 1 (" & T("operazione non riuscita", "failed") & ")"
  Case 3
    Fail "Status = 3 (" & T("accesso negato: e' impostata una password di amministratore del BIOS", _
                            "access denied: a BIOS administrator password is set") & ")"
  Case -1
    Fail T("ERRORE: interfaccia BIOSAttributeInterface non trovata.", "ERROR: BIOSAttributeInterface not found.")
  Case Else
    Fail "Status = " & st & " (" & T("errore", "error") & ")"
End Select

' --- Check -------------------------------------------------------------------
softRead = True
If ReadAttr(cur, possible) Then
  WScript.Echo ATTR & " = " & cur
Else
  WScript.Echo T("ATTENZIONE: impossibile rileggere il valore dopo la scrittura.", _
                 "WARNING: cannot read the value back after the write.")
End If
If LCase(cur) <> LCase(WANT) Then
  WScript.Echo T("ATTENZIONE: la rilettura non da' ancora " & WANT & ". Il valore potrebbe comparire solo dopo il riavvio.", _
                 "WARNING: reading it back does not show " & WANT & " yet. The value may appear only after a restart.")
End If

WScript.Echo ""
WScript.Echo T("Prossimi passi:", "Next steps:")
WScript.Echo T("  1. in WinRE: scrivi exit, poi scegli Spegni il PC (non Continua);", _
               "  1. in WinRE: type exit, then choose Turn off your PC (not Continue);")
WScript.Echo T("     in Windows: spegni il PC;", _
               "     in Windows: shut down the PC;")
WScript.Echo T("  2. collega il box con il cavo Thunderbolt a una porta Thunderbolt;", _
               "  2. connect the enclosure to a Thunderbolt port with the Thunderbolt cable;")
WScript.Echo T("  3. riaccendi, premi F12 e scegli la voce dell'SSD esterno.", _
               "  3. power on, press F12 and choose the external SSD entry.")
WScript.Quit 0
