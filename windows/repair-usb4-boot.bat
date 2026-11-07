@echo off
setlocal EnableExtensions
rem ===========================================================================
rem repair-usb4-boot.bat
rem
rem Restores the values needed to boot Windows from the Thunderbolt SSD:
rem   Services\Usb4HostRouter\Start   = 0      USB4 driver loaded at boot
rem   Services\Usb4DeviceRouter\Start = 0      USB4 driver loaded at boot
rem   Control\BootDriverFlags         = 0x14
rem Then, if thunderbolt-boot-on.vbs is in the same folder, it checks the
rem hidden BIOS attribute ThunderboltBoot and offers to enable it.
rem
rem The mode is chosen automatically:
rem  - RECOVERY ENVIRONMENT, WinRE: works on the OFFLINE registry of the
rem    Windows installation on the drive the script is run from, or on the
rem    drive given as argument, for example D:. A drive encrypted with
rem    BitLocker must already be unlocked.
rem  - WINDOWS RUNNING: works on the registry of the running system. Needs a
rem    Command Prompt opened as administrator, except with /check. The values
rem    take effect from the next boot.
rem
rem Options:
rem   drive:   WinRE only, the drive of the Windows installation, e.g. D:
rem   /check   read only: shows the values and the state of ThunderboltBoot,
rem            asks nothing, changes nothing, does not pause. In WinRE it
rem            still loads and unloads the offline registry. With Windows
rem            running it does not need administrator rights for the
rem            registry; reading ThunderboltBoot does.
rem   /it /en  message language. Default: Italian if the system language is
rem            Italian, English otherwise.
rem
rem Usage:  repair-usb4-boot.bat [drive:] [/check] [/it or /en]
rem
rem Exit codes:
rem   /check       0 = all correct, 2 = something to fix, 1 = error
rem   normal mode  0 = done, nothing to do, or cancelled; 1 = error
rem
rem Recommended location: C:\Repair\, together with thunderbolt-boot-on.vbs.
rem In WinRE the same folder usually has another letter, e.g. D:\Repair\.
rem
rem Notes for editing: WinRE has no PowerShell and no where.exe. Messages are
rem printed with goto and labels, never inside parenthesised blocks. Values
rem are read with reg query, not with sc qc, whose output is translated.
rem rem lines must not contain the pipe, ampersand, angle bracket, percent or
rem caret characters.
rem ===========================================================================

rem Folder of this script, saved before shift changes the batch parameters
set "HERE=%~dp0"
set "RC=0"
set "HIVEKEY=HKLM\WTB_OFF"
set "CHECK="
set "BAD="
set "TBOFF="
set "TBON="
set "CANCELLED="
set "ISADMIN="
set "TBUNK="
set "HELP="
rem Full path, so that another find.exe earlier in PATH is never used
set "FIND=%SystemRoot%\System32\find.exe"

rem --- Arguments, in any order ----------------------------------------------
set "LNG="
set "ARG="
set "BADARG="
:parse
if "%~1"=="" goto :parsed
set "A1=%~1"
shift
if /i "%A1%"=="/en" goto :arg_en
if /i "%A1%"=="/it" goto :arg_it
if /i "%A1%"=="/check" goto :arg_check
if "%A1%"=="/?" goto :arg_help
if "%A1:~0,1%"=="/" goto :arg_bad
if defined ARG goto :arg_bad
set "ARG=%A1%"
goto :parse
:arg_en
set "LNG=en"
goto :parse
:arg_it
set "LNG=it"
goto :parse
:arg_check
set "CHECK=1"
goto :parse
:arg_help
set "HELP=1"
goto :parse
:arg_bad
set "BADARG=%A1%"
goto :parse
:parsed
if not defined LNG call :detect_lang
call :lang_%LNG%
if defined HELP goto :help
if defined BADARG goto :usage
rem The drive must look like D: so that nothing else reaches the paths below
if not defined ARG goto :arg_ok
if not "%ARG:~1,1%"==":" set "BADARG=%ARG%"
if defined BADARG goto :usage
:arg_ok

set "WINRE="
if /i "%SystemDrive%"=="X:" set "WINRE=1"
reg query "HKLM\SYSTEM\CurrentControlSet\Control\MiniNT" >nul 2>&1 && set "WINRE=1"
if defined WINRE goto :offline


rem ---------------------------------------------------------------------------
rem Mode WINDOWS RUNNING
rem ---------------------------------------------------------------------------
:online
if defined ARG goto :online_arg
reg query "HKU\S-1-5-19" >nul 2>&1 && set "ISADMIN=1"
if not defined CHECK if not defined ISADMIN goto :not_admin

set "BASE=HKLM\SYSTEM\CurrentControlSet"
echo.
if defined CHECK echo %M_CHECK_ONLY%
echo %M_MODE_ONLINE% (%SystemDrive%)
call :check_services
if errorlevel 1 goto :fail
echo.
echo %M_CURRENT%
call :check_all
if defined CHECK goto :online_tb
if not defined BAD goto :online_ok
call :apply
if errorlevel 1 goto :fail
echo.
echo %M_AFTER%
call :show
call :verify
if errorlevel 1 goto :fail
echo.
echo %M_DONE_ONLINE%
goto :online_tb
:online_ok
echo %M_ALREADY%
:online_tb
call :tb_step
if errorlevel 1 set "RC=1"
if defined CHECK goto :check_end
if not "%RC%"=="0" goto :fail
goto :end

:online_arg
echo %M_ERR_ONLINE_ARG1%
echo %M_ERR_ONLINE_ARG2%
goto :fail

:not_admin
echo %M_ERR_ADMIN%
goto :fail


rem ---------------------------------------------------------------------------
rem Mode RECOVERY ENVIRONMENT, offline registry
rem ---------------------------------------------------------------------------
:offline
set "T=%ARG%"
if "%T%"=="" set "T=%HERE:~0,2%"
set "T=%T:~0,2%"
if /i "%T%"=="X:" goto :target_x

set "HIVE=%T%\Windows\System32\config\SYSTEM"
if not exist "%HIVE%" goto :no_hive

echo.
if defined CHECK echo %M_CHECK_ONLY%
echo %M_MODE_OFFLINE%
echo %M_TARGET% %T%\Windows
vol %T%
echo.

reg unload %HIVEKEY% >nul 2>&1
reg load %HIVEKEY% "%HIVE%"
if errorlevel 1 goto :load_fail

rem Active control set: ControlSet001, 002 and so on
set "CUR="
for /f "tokens=3" %%A in ('reg query %HIVEKEY%\Select /v Current 2^>nul ^| %FIND% "REG_DWORD"') do set "CUR=%%A"
if not defined CUR goto :select_fail
set /a N=%CUR%
if %N% LSS 1 goto :select_fail
if %N% GTR 9 goto :select_fail
set "BASE=%HIVEKEY%\ControlSet00%N%"
echo %M_CONTROLSET% ControlSet00%N%

call :check_services
if errorlevel 1 goto :fail_loaded
echo.
echo %M_CURRENT%
call :check_all
if defined CHECK goto :unload
if not defined BAD goto :offline_ok

echo.
set "ANS="
set /p "ANS=%M_CONFIRM%"
if /i "%ANS%"=="SI" goto :confirmed
if /i "%ANS%"=="YES" goto :confirmed
set "CANCELLED=1"
goto :unload
:confirmed
call :apply
if errorlevel 1 goto :fail_loaded
echo.
echo %M_AFTER%
call :show
call :verify
if errorlevel 1 goto :fail_loaded
goto :unload

:offline_ok
echo %M_ALREADY%
goto :unload

:select_fail
echo %M_ERR_SELECT%
:fail_loaded
set "RC=1"
:unload
reg unload %HIVEKEY%
if not errorlevel 1 goto :unloaded
ping -n 3 127.0.0.1 >nul 2>&1
reg unload %HIVEKEY%
if not errorlevel 1 goto :unloaded
echo %M_WARN_UNLOAD%
echo   reg unload %HIVEKEY%
set "RC=1"
goto :end
:unloaded
if not "%RC%"=="0" goto :fail
if defined CANCELLED goto :cancelled
call :tb_step
if errorlevel 1 set "RC=1"
if defined CHECK goto :check_end
echo.
if "%RC%"=="0" echo %M_DONE_OFFLINE%
if not "%RC%"=="0" echo %M_DONE_PARTIAL%
echo   %M_NEXT1%
echo   %M_NEXT2%
if defined TBON echo   %M_NEXT2_TB%
echo   %M_NEXT2_F12%
echo   %M_NEXT3%
echo   %M_NEXT4%
echo        bcdedit /set {fwbootmgr} displayorder {bootmgr} /addlast
echo        manage-bde -status C:
echo   %M_NEXT4_BL%
echo        manage-bde -protectors -enable C:
goto :end

:target_x
echo %M_ERR_X1%
echo %M_ERR_X2% repair-usb4-boot.bat D:
goto :fail

:no_hive
echo %M_ERR_HIVE% %HIVE%
echo %M_HINT_BL%
echo     manage-bde -status
echo     manage-bde -unlock %T% -RecoveryPassword %M_KEY_PLACEHOLDER%
echo %M_HINT_LETTER% dir D:\Windows
goto :fail

:load_fail
echo %M_ERR_LOAD% %HIVE%
goto :fail

:cancelled
echo %M_CANCELLED%
goto :end


rem ---------------------------------------------------------------------------
rem Result of /check
rem ---------------------------------------------------------------------------
:check_end
echo.
if not "%RC%"=="0" goto :fail
if defined BAD set "RC=2"
if defined TBOFF set "RC=2"
if "%RC%"=="2" echo %M_CHECK_FIX%
if not "%RC%"=="0" goto :end
if defined TBUNK echo %M_CHECK_OK_NOTB%
if not defined TBUNK echo %M_CHECK_OK%
goto :end

:usage
echo %M_ERR_OPTION% %BADARG%
echo %M_USAGE%
goto :fail

:help
echo %M_USAGE%
goto :end


rem ---------------------------------------------------------------------------
rem Subroutines, they use the variable BASE
rem ---------------------------------------------------------------------------
:check_services
reg query "%BASE%\Services\Usb4HostRouter" >nul 2>&1 || goto :svc_missing
reg query "%BASE%\Services\Usb4DeviceRouter" >nul 2>&1 || goto :svc_missing
exit /b 0
:svc_missing
echo %M_ERR_SVC%
exit /b 1

rem Shows the three values with the result; sets BAD if one is wrong
:check_all
set "BAD="
call :check_val "%BASE%\Services\Usb4HostRouter" Start 0x0
call :check_val "%BASE%\Services\Usb4DeviceRouter" Start 0x0
call :check_val "%BASE%\Control" BootDriverFlags 0x14
exit /b 0

:check_val
set "V=%M_MISSING%"
for /f "tokens=3" %%A in ('reg query "%~1" /v %2 2^>nul ^| %FIND% "REG_DWORD"') do set "V=%%A"
call :columns %1 %2
if /i "%V%"=="%3" goto :check_val_ok
set "BAD=1"
echo   %LBL%= %VP%  %M_TO_FIX% %3
exit /b 0
:check_val_ok
echo   %LBL%= %VP%  OK
exit /b 0

:show
call :showval "%BASE%\Services\Usb4HostRouter" Start
call :showval "%BASE%\Services\Usb4DeviceRouter" Start
call :showval "%BASE%\Control" BootDriverFlags
exit /b 0

:showval
set "V=%M_MISSING%"
for /f "tokens=3" %%A in ('reg query "%~1" /v %2 2^>nul ^| %FIND% "REG_DWORD"') do set "V=%%A"
call :columns %1 %2
echo   %LBL%= %V%
exit /b 0

rem Pads the output into columns: LBL holds the key and the value name,
rem VP the value V. A value of 8 characters or more is left as it is.
:columns
set "L1=%~nx1                  "
set "L2=%~2                "
set "LBL=%L1:~0,18%%L2:~0,16%"
set "VP=%V%"
if not "%V:~7,1%"=="" exit /b 0
set "VP=%V%        "
set "VP=%VP:~0,8%"
exit /b 0

:apply
reg add "%BASE%\Services\Usb4HostRouter" /v Start /t REG_DWORD /d 0 /f >nul || goto :apply_fail
reg add "%BASE%\Services\Usb4DeviceRouter" /v Start /t REG_DWORD /d 0 /f >nul || goto :apply_fail
reg add "%BASE%\Control" /v BootDriverFlags /t REG_DWORD /d 0x14 /f >nul || goto :apply_fail
exit /b 0
:apply_fail
echo %M_ERR_WRITE%
exit /b 1

:verify
call :expect "%BASE%\Services\Usb4HostRouter" Start 0x0 || exit /b 1
call :expect "%BASE%\Services\Usb4DeviceRouter" Start 0x0 || exit /b 1
call :expect "%BASE%\Control" BootDriverFlags 0x14 || exit /b 1
exit /b 0

:expect
set "V="
for /f "tokens=3" %%A in ('reg query "%~1" /v %2 2^>nul ^| %FIND% "REG_DWORD"') do set "V=%%A"
if /i "%V%"=="%3" exit /b 0
echo %M_ERR_VALUE% %~nx1  %2 = "%V%" (%M_EXPECTED% %3)
exit /b 1


rem ---------------------------------------------------------------------------
rem ThunderboltBoot, through thunderbolt-boot-on.vbs in the same folder.
rem The script exits with 0 = Enabled, 2 = not Enabled, 1 = error.
rem With /check: reports only. Otherwise: asks, then enables.
rem Returns 1 only if enabling was attempted and failed.
rem ---------------------------------------------------------------------------
:tb_step
echo.
if not exist "%HERE%thunderbolt-boot-on.vbs" goto :tb_missing
echo %M_TB_TITLE%
cscript //nologo "%HERE%thunderbolt-boot-on.vbs" /status /%LNG%
set "TBRC=%errorlevel%"
if "%TBRC%"=="0" exit /b 0
if "%TBRC%"=="2" goto :tb_off
set "TBUNK=1"
if not defined WINRE if not defined ISADMIN goto :tb_noadmin
echo %M_TB_WARN%
exit /b 0
:tb_noadmin
echo %M_TB_NOADMIN%
exit /b 0
:tb_missing
set "TBUNK=1"
echo %M_TB_SKIPPED%
exit /b 0
:tb_off
if defined CHECK goto :tb_off_check
echo.
set "ANS="
set /p "ANS=%M_TB_CONFIRM%"
if /i "%ANS%"=="SI" goto :tb_enable
if /i "%ANS%"=="YES" goto :tb_enable
echo %M_TB_LEFT_OFF%
exit /b 0
:tb_enable
cscript //nologo "%HERE%thunderbolt-boot-on.vbs" /%LNG%
if errorlevel 1 goto :tb_enable_fail
set "TBON=1"
exit /b 0
:tb_enable_fail
echo %M_TB_FAILED%
exit /b 1
:tb_off_check
set "TBOFF=1"
echo %M_TB_OFF_CHECK%
exit /b 0


rem ---------------------------------------------------------------------------
rem Language
rem ---------------------------------------------------------------------------
:detect_lang
rem 0410 = Italian. In WinRE this is the language of the recovery environment.
set "LNG=en"
for /f "tokens=3" %%A in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\Nls\Language" /v Default 2^>nul ^| %FIND% "REG_SZ"') do if /i "%%A"=="0410" set "LNG=it"
exit /b 0

:lang_it
set "M_MODE_ONLINE=Modalita': Windows avviato - registro del sistema in uso"
set "M_MODE_OFFLINE=Modalita': ambiente di ripristino - registro offline"
set "M_CHECK_ONLY=Controllo in sola lettura, /check: nessuna modifica."
set "M_TARGET=Installazione di Windows:"
set "M_CONFIRM=Correggo i valori? Scrivi SI e premi Invio: "
set "M_CONTROLSET=Control set attivo:"
set "M_CURRENT=Valori attuali:"
set "M_AFTER=Valori dopo la correzione:"
set "M_MISSING=assente"
set "M_TO_FIX=DA CORREGGERE, atteso"
set "M_ALREADY=I valori sono gia' corretti: nessuna modifica al registro."
set "M_DONE_ONLINE=Fatto. I valori hanno effetto dal prossimo avvio."
set "M_DONE_OFFLINE=Fatto. Ora:"
set "M_DONE_PARTIAL=Registro a posto, ma ThunderboltBoot non e' stato attivato: vedi sopra. Poi:"
set "M_NEXT1=1. scrivi exit e premi Invio"
set "M_NEXT2=2. scegli Spegni il PC, non Continua: Continua avvia la voce predefinita, cioe' il sistema interno"
set "M_NEXT2_TB=   ThunderboltBoot e' appena stato attivato: prima di riaccendere collega il box alla porta Thunderbolt con il cavo Thunderbolt"
set "M_NEXT2_F12=   riaccendi, premi F12 e scegli la voce del Windows esterno"
set "M_NEXT3=3. inserisci il PIN di BitLocker, oppure la chiave di ripristino se il BIOS e' cambiato"
set "M_NEXT4=4. in Windows, Prompt dei comandi come amministratore:"
set "M_NEXT4_BL=   se la protezione risulta disattivata:"
set "M_CANCELLED=Annullato. Nessuna modifica."
set "M_CHECK_OK=Esito: tutto a posto."
set "M_CHECK_OK_NOTB=Esito: registro a posto; ThunderboltBoot non verificato, vedi sopra."
set "M_CHECK_FIX=Esito: qualcosa da correggere. Lancia lo script senza /check."
set "M_TB_TITLE=Controllo di ThunderboltBoot nel BIOS:"
set "M_TB_SKIPPED=ATTENZIONE: thunderbolt-boot-on.vbs non e' nella cartella dello script: controllo di ThunderboltBoot saltato."
set "M_TB_NOADMIN=ThunderboltBoot non letto: senza diritti di amministratore e' normale, e non e' un errore del controllo."
set "M_TB_WARN=ATTENZIONE: stato di ThunderboltBoot non leggibile, vedi il messaggio sopra. Proseguo."
set "M_TB_OFF_CHECK=ThunderboltBoot e' disattivato: lancia lo script senza /check per attivarlo."
set "M_TB_CONFIRM=Attivo ThunderboltBoot nel BIOS? Scrivi SI e premi Invio: "
set "M_TB_LEFT_OFF=ThunderboltBoot resta disattivato: l'SSD esterno non comparira' nel menu F12 via Thunderbolt."
set "M_TB_FAILED=ERRORE: ThunderboltBoot non e' stato attivato, vedi il messaggio sopra."
set "M_ERR_OPTION=ERRORE: opzione non riconosciuta:"
set "M_USAGE=Uso: repair-usb4-boot.bat [unita':] [/check] [/it oppure /en]"
set "M_ERR_ONLINE_ARG1=ERRORE: con Windows avviato lo script corregge solo il sistema in uso."
set "M_ERR_ONLINE_ARG2=Lancialo senza indicare una lettera di unita'."
set "M_ERR_ADMIN=ERRORE: lancia lo script da un Prompt dei comandi aperto come amministratore, oppure usa /check per il solo controllo."
set "M_ERR_SELECT=ERRORE: impossibile leggere Select\Current dal registro offline."
set "M_WARN_UNLOAD=ATTENZIONE: il registro non e' stato scaricato. Riprova a mano con:"
set "M_ERR_X1=ERRORE: X: e' l'unita' dell'ambiente di ripristino, non quella di Windows."
set "M_ERR_X2=Indica la lettera giusta, per esempio:"
set "M_ERR_HIVE=ERRORE: non trovo"
set "M_HINT_BL=- Se il disco e' cifrato con BitLocker, sbloccalo prima:"
set "M_KEY_PLACEHOLDER=CHIAVE-DI-48-CIFRE"
set "M_HINT_LETTER=- Controlla la lettera dell'unita' di Windows, per esempio:"
set "M_ERR_LOAD=ERRORE: impossibile caricare il registro offline"
set "M_ERR_SVC=ERRORE: i servizi Usb4HostRouter / Usb4DeviceRouter non esistono in questa installazione."
set "M_ERR_WRITE=ERRORE: scrittura nel registro non riuscita."
set "M_ERR_VALUE=ERRORE:"
set "M_EXPECTED=atteso"
set "M_FAILED=Operazione non riuscita."
exit /b 0

:lang_en
set "M_MODE_ONLINE=Mode: Windows running - registry of the running system"
set "M_MODE_OFFLINE=Mode: recovery environment - offline registry"
set "M_CHECK_ONLY=Read-only check, /check: nothing is changed."
set "M_TARGET=Windows installation:"
set "M_CONFIRM=Repair the values? Type YES and press Enter: "
set "M_CONTROLSET=Active control set:"
set "M_CURRENT=Current values:"
set "M_AFTER=Values after the repair:"
set "M_MISSING=missing"
set "M_TO_FIX=TO FIX, expected"
set "M_ALREADY=The values are already correct: the registry was not changed."
set "M_DONE_ONLINE=Done. The values take effect from the next boot."
set "M_DONE_OFFLINE=Done. Now:"
set "M_DONE_PARTIAL=Registry OK, but ThunderboltBoot was not enabled: see above. Then:"
set "M_NEXT1=1. type exit and press Enter"
set "M_NEXT2=2. choose Turn off your PC, not Continue: Continue starts the default entry, that is the internal system"
set "M_NEXT2_TB=   ThunderboltBoot has just been enabled: before powering on, connect the enclosure to the Thunderbolt port with the Thunderbolt cable"
set "M_NEXT2_F12=   power on, press F12 and choose the entry of the external Windows"
set "M_NEXT3=3. enter the BitLocker PIN, or the recovery key if the BIOS has changed"
set "M_NEXT4=4. in Windows, Command Prompt as administrator:"
set "M_NEXT4_BL=   if it shows Protection Off:"
set "M_CANCELLED=Cancelled. Nothing was changed."
set "M_CHECK_OK=Result: everything is correct."
set "M_CHECK_OK_NOTB=Result: registry OK; ThunderboltBoot not verified, see above."
set "M_CHECK_FIX=Result: something needs fixing. Run the script without /check."
set "M_TB_TITLE=Checking ThunderboltBoot in the BIOS:"
set "M_TB_SKIPPED=WARNING: thunderbolt-boot-on.vbs is not in the folder of this script: ThunderboltBoot check skipped."
set "M_TB_NOADMIN=ThunderboltBoot not read: without administrator rights this is normal, and not an error of the check."
set "M_TB_WARN=WARNING: the state of ThunderboltBoot cannot be read, see the message above. Going on."
set "M_TB_OFF_CHECK=ThunderboltBoot is disabled: run the script without /check to enable it."
set "M_TB_CONFIRM=Enable ThunderboltBoot in the BIOS? Type YES and press Enter: "
set "M_TB_LEFT_OFF=ThunderboltBoot stays disabled: the external SSD will not appear in the F12 menu over Thunderbolt."
set "M_TB_FAILED=ERROR: ThunderboltBoot was not enabled, see the message above."
set "M_ERR_OPTION=ERROR: unknown option:"
set "M_USAGE=Usage: repair-usb4-boot.bat [drive:] [/check] [/it or /en]"
set "M_ERR_ONLINE_ARG1=ERROR: with Windows running, the script only repairs the running system."
set "M_ERR_ONLINE_ARG2=Run it without a drive letter."
set "M_ERR_ADMIN=ERROR: run the script from a Command Prompt opened as administrator, or use /check to check only."
set "M_ERR_SELECT=ERROR: cannot read Select\Current from the offline registry."
set "M_WARN_UNLOAD=WARNING: the registry was not unloaded. Try again manually with:"
set "M_ERR_X1=ERROR: X: is the recovery environment drive, not the Windows drive."
set "M_ERR_X2=Specify the right letter, for example:"
set "M_ERR_HIVE=ERROR: cannot find"
set "M_HINT_BL=- If the drive is encrypted with BitLocker, unlock it first:"
set "M_KEY_PLACEHOLDER=48-DIGIT-RECOVERY-KEY"
set "M_HINT_LETTER=- Check the letter of the Windows drive, for example:"
set "M_ERR_LOAD=ERROR: cannot load the offline registry"
set "M_ERR_SVC=ERROR: the Usb4HostRouter / Usb4DeviceRouter services do not exist in this installation."
set "M_ERR_WRITE=ERROR: writing to the registry failed."
set "M_ERR_VALUE=ERROR:"
set "M_EXPECTED=expected"
set "M_FAILED=Operation failed."
exit /b 0


rem ---------------------------------------------------------------------------
:fail
set "RC=1"
echo.
echo %M_FAILED%
:end
echo.
if not defined CHECK pause
endlocal & exit /b %RC%
