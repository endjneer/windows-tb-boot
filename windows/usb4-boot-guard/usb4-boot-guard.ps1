<#
.SYNOPSIS
    Installa, controlla o rimuove il servizio Usb4BootGuard.

.DESCRIPTION
    Usb4BootGuard tiene a 0 il valore Start dei driver Usb4HostRouter e
    Usb4DeviceRouter, e BootDriverFlags a 0x14. Gli aggiornamenti di Windows
    riportano Start a 3, e allora Windows non parte piu' dall'SSD Thunderbolt.
    Il funzionamento e' descritto in Usb4BootGuard.cs.

    Senza parametri installa il servizio, o lo aggiorna se esiste gia':
      - compila Usb4BootGuard.cs con il compilatore C# di .NET Framework 4,
        incluso in Windows;
      - copia il programma in "C:\Program Files\Usb4BootGuard" e imposta
        permessi espliciti: solo SYSTEM e Administrators possono modificarlo;
      - registra il servizio (avvio automatico, riavvio in caso di errore)
        e la sorgente dei suoi eventi nel registro Applicazione;
      - avvia il servizio e mostra lo stato.
    Va lanciato da un PowerShell aperto come amministratore, tranne -Status.

    Lingua dei messaggi: italiano se la lingua di sistema e' l'italiano,
    altrimenti inglese. Si puo' forzare con /it oppure /en.

.EXAMPLE
    .\usb4-boot-guard.ps1
    Installa o aggiorna il servizio.
.EXAMPLE
    .\usb4-boot-guard.ps1 -Status
    Stato del servizio, permessi del programma, valori nel registro, ultimi
    eventi. Sola lettura. Codice di uscita 1 se qualcosa non va.
.EXAMPLE
    .\usb4-boot-guard.ps1 -SelfTest
    Porta Start a 3 su ciascun driver e controlla che il servizio lo rimetta
    a 0. In ogni caso lo script lo rimette a 0 prima di uscire.
.EXAMPLE
    .\usb4-boot-guard.ps1 -Uninstall
    Rimuove il servizio. I valori nel registro restano come sono.
.EXAMPLE
    .\usb4-boot-guard.ps1 /en -Status
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
    Justification = 'Script interattivo: i messaggi sono per chi lo lancia')]
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Install')]
param(
    [Parameter(Position = 0)]
    [ValidatePattern('^/?(it|en)$')]
    [string] $Lang,

    [Parameter(Mandatory, ParameterSetName = 'Status')]
    [switch] $Status,

    [Parameter(Mandatory, ParameterSetName = 'SelfTest')]
    [switch] $SelfTest,

    [Parameter(Mandatory, ParameterSetName = 'Uninstall')]
    [switch] $Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ServiceName = 'Usb4BootGuard'
$InstallDir = Join-Path $env:ProgramFiles 'Usb4BootGuard'
$ExePath = Join-Path $InstallDir 'Usb4BootGuard.exe'
$SourceFile = Join-Path $PSScriptRoot 'Usb4BootGuard.cs'
$RegBase = 'HKLM:\SYSTEM\CurrentControlSet'

# SID per i permessi, indipendenti dalla lingua di Windows
$SidSystem = 'S-1-5-18'
$SidAdmins = 'S-1-5-32-544'
$SidUsers = 'S-1-5-32-545'
$SidTrustedInstaller = 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'

# Gli stessi valori di Usb4BootGuard.cs e di repair-usb4-boot.bat
$Guarded = @(
    [pscustomobject]@{ Key = 'Services\Usb4HostRouter'; Name = 'Start'; Expected = 0 }
    [pscustomobject]@{ Key = 'Services\Usb4DeviceRouter'; Name = 'Start'; Expected = 0 }
    [pscustomobject]@{ Key = 'Control'; Name = 'BootDriverFlags'; Expected = 0x14 }
)

# --- Lingua -----------------------------------------------------------------
$Messages = @{
    it = @{
        ErrAdmin           = "ERRORE: apri PowerShell come amministratore e rilancia lo script."
        ErrServices        = "ERRORE: i servizi Usb4HostRouter / Usb4DeviceRouter non esistono in questo Windows."
        ErrSource          = "ERRORE: non trovo {0}"
        ErrCompiler        = "ERRORE: non trovo il compilatore C# di .NET Framework 4: {0}"
        ErrCompile         = "ERRORE: compilazione non riuscita:"
        ErrNeedService     = "ERRORE: il servizio deve essere installato e attivo. Installalo con .\usb4-boot-guard.ps1"
        ErrRemove          = "ERRORE: non riesco a cancellare {0}"
        Compiling          = "Compilo {0}"
        Installing         = "Installo in {0}"
        Updating           = "Il servizio esiste gia': lo aggiorno."
        Done               = "Fatto. Il servizio e' attivo e parte da solo a ogni avvio."
        NextSelfTest       = "Prova consigliata: .\usb4-boot-guard.ps1 -SelfTest"
        WarnValues         = "ATTENZIONE: alcuni valori o permessi non sono quelli attesi. Controlla l'elenco qui sopra."
        HdrPerms           = "Permessi del programma"
        PermsOk            = "  OK: possono modificarlo solo SYSTEM e Administrators"
        PermsBad           = "  ATTENZIONE: possono modificarlo anche altri. Rilancia l'installazione per correggere:"
        OwnerLabel         = "proprietario"
        Removed            = "Servizio rimosso. I valori nel registro restano come sono."
        NotInstalled       = "Il servizio non e' installato."
        HdrService         = "Servizio $ServiceName"
        HdrValues          = "Valori nel registro"
        HdrEvents          = "Ultimi eventi (registro Applicazione)"
        StateLine          = "  Stato: {0}   Avvio: {1}"
        NoEvents           = "  nessun evento"
        Missing            = "assente"
        KeyMissing         = "chiave assente"
        Different          = "DIVERSO (atteso {0})"
        SelfTestStep       = "Porto {0}\Start a 3 e attendo che il servizio lo rimetta a 0..."
        SelfTestOk         = "  OK: rimesso a 0 in {0} ms"
        SelfTestFail       = "  NO: dopo {0} ms vale ancora {1}. Lo script l'ha rimesso a 0."
        SelfTestPassed     = "Prova superata: il servizio ripristina i valori."
        SelfTestFailed     = "Prova NON superata. I valori sono stati rimessi a 0 dallo script."
        ServiceDescription = "Tiene a 0 il valore Start dei driver USB4, necessario per avviare Windows dall'SSD Thunderbolt (windows-tb-boot)."
    }
    en = @{
        ErrAdmin           = "ERROR: open PowerShell as administrator and run the script again."
        ErrServices        = "ERROR: the Usb4HostRouter / Usb4DeviceRouter services do not exist in this Windows."
        ErrSource          = "ERROR: cannot find {0}"
        ErrCompiler        = "ERROR: cannot find the .NET Framework 4 C# compiler: {0}"
        ErrCompile         = "ERROR: compilation failed:"
        ErrNeedService     = "ERROR: the service must be installed and running. Install it with .\usb4-boot-guard.ps1"
        ErrRemove          = "ERROR: cannot delete {0}"
        Compiling          = "Compiling {0}"
        Installing         = "Installing to {0}"
        Updating           = "The service already exists: updating it."
        Done               = "Done. The service is running and starts by itself at every boot."
        NextSelfTest       = "Recommended test: .\usb4-boot-guard.ps1 -SelfTest"
        WarnValues         = "WARNING: some values or permissions are not the expected ones. Check the list above."
        HdrPerms           = "Program permissions"
        PermsOk            = "  OK: only SYSTEM and Administrators can modify it"
        PermsBad           = "  WARNING: others can modify it too. Run the installation again to fix it:"
        OwnerLabel         = "owner"
        Removed            = "Service removed. The registry values stay as they are."
        NotInstalled       = "The service is not installed."
        HdrService         = "Service $ServiceName"
        HdrValues          = "Registry values"
        HdrEvents          = "Latest events (Application log)"
        StateLine          = "  State: {0}   Startup: {1}"
        NoEvents           = "  no events"
        Missing            = "missing"
        KeyMissing         = "key missing"
        Different          = "DIFFERENT (expected {0})"
        SelfTestStep       = "Setting {0}\Start to 3 and waiting for the service to set it back to 0..."
        SelfTestOk         = "  OK: back to 0 in {0} ms"
        SelfTestFail       = "  NO: after {0} ms it is still {1}. The script set it back to 0."
        SelfTestPassed     = "Test passed: the service restores the values."
        SelfTestFailed     = "Test FAILED. The values were set back to 0 by the script."
        ServiceDescription = "Keeps the Start value of the USB4 drivers at 0, needed to boot Windows from the Thunderbolt SSD (windows-tb-boot)."
    }
}

if ($Lang) {
    $lng = $Lang.TrimStart('/').ToLowerInvariant()
} elseif ([Globalization.CultureInfo]::InstalledUICulture.TwoLetterISOLanguageName -eq 'it') {
    $lng = 'it'
} else {
    $lng = 'en'
}
$M = $Messages[$lng]

# --- Funzioni ---------------------------------------------------------------
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $id
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Valori attuali, in sola lettura.
function Get-GuardedState {
    foreach ($g in $Guarded) {
        $text = $M.KeyMissing
        $ok = $false
        $key = Get-Item -LiteralPath "$RegBase\$($g.Key)" -ErrorAction SilentlyContinue
        if ($key) {
            try {
                $value = $key.GetValue($g.Name, $null)
                if ($null -eq $value) {
                    $text = $M.Missing
                } elseif ($key.GetValueKind($g.Name) -eq [Microsoft.Win32.RegistryValueKind]::DWord) {
                    $text = '0x{0:x}' -f $value
                    $ok = ($value -eq $g.Expected)
                } else {
                    $text = '{0} "{1}"' -f $key.GetValueKind($g.Name), $value
                }
            } finally {
                $key.Close()
            }
        }
        [pscustomobject]@{ Key = $g.Key; Name = $g.Name; Expected = $g.Expected; Current = $text; Ok = $ok }
    }
}

function Show-GuardedState {
    Write-Host $M.HdrValues
    $allOk = $true
    foreach ($s in Get-GuardedState) {
        if ($s.Ok) {
            $verdict = 'OK'
        } else {
            $verdict = $M.Different -f ('0x{0:x}' -f $s.Expected)
            $allOk = $false
        }
        Write-Host ('  {0}\{1} = {2}   {3}' -f $s.Key, $s.Name, $s.Current, $verdict)
    }
    return $allOk
}

# Chi, oltre a SYSTEM, Administrators e TrustedInstaller, puo' modificare il
# programma. Conta anche il proprietario, che puo' sempre cambiarne i permessi.
function Get-UnsafeWriter {
    $trusted = @($SidSystem, $SidAdmins, $SidTrustedInstaller)
    # Scrittura, aggiunta, attributi, cancellazione, permessi, proprieta', GENERIC_ALL, GENERIC_WRITE
    $writeMask = 0x2 -bor 0x4 -bor 0x10 -bor 0x40 -bor 0x100 -bor 0x10000 -bor 0x40000 -bor 0x80000 -bor 0x10000000 -bor 0x40000000
    foreach ($path in $InstallDir, $ExePath) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $acl = Get-Acl -LiteralPath $path
        if ($trusted -notcontains $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value) {
            '{0} ({1}): {2}' -f $path, $M.OwnerLabel, $acl.Owner
        }
        foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
            if ($rule.AccessControlType -ne 'Allow') { continue }
            if ($trusted -contains $rule.IdentityReference.Value) { continue }
            if (([int64] $rule.FileSystemRights -band $writeMask) -eq 0) { continue }
            try {
                $who = $rule.IdentityReference.Translate([Security.Principal.NTAccount]).Value
            } catch {
                $who = $rule.IdentityReference.Value
            }
            '{0}: {1}' -f $path, $who
        }
    }
}

function Show-Status {
    Write-Host $M.HdrService
    $svc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$ServiceName'"
    $allOk = $true
    if ($svc) {
        Write-Host ($M.StateLine -f $svc.State, $svc.StartMode)
        Write-Host "  $($svc.PathName)"
        Write-Host ''
        Write-Host $M.HdrPerms
        $unsafe = @(Get-UnsafeWriter)
        if ($unsafe.Count -eq 0) {
            Write-Host $M.PermsOk
        } else {
            Write-Host $M.PermsBad
            foreach ($u in $unsafe) { Write-Host "    $u" }
            $allOk = $false
        }
    } else {
        Write-Host "  $($M.NotInstalled)"
    }
    Write-Host ''
    if (-not (Show-GuardedState)) { $allOk = $false }
    Write-Host ''
    Write-Host $M.HdrEvents
    try {
        $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; ProviderName = $ServiceName } -MaxEvents 10 -ErrorAction Stop)
    } catch {
        $events = @()
    }
    if ($events.Count -eq 0) {
        Write-Host $M.NoEvents
    }
    foreach ($e in $events) {
        Write-Host ('  {0:yyyy-MM-dd HH:mm:ss}  [{1}] {2}' -f $e.TimeCreated, $e.Id, $e.Message)
    }
    return $allOk
}

# Il servizio gira come SYSTEM: il suo eseguibile deve poterlo modificare solo
# un amministratore con diritti elevati. Ereditando da Program Files, la
# cartella darebbe il controllo completo al proprietario (voce CREATOR OWNER),
# cioe' a chi l'ha creata, anche da un processo non elevato. Qui la cartella
# riceve permessi espliciti, il programma li eredita, e il proprietario
# diventa il gruppo Administrators.
function Set-InstallDirAcl {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess($InstallDir, 'icacls')) { return }
    $steps = @(
        , @($InstallDir, '/inheritance:r', '/grant:r',
            "*$($SidSystem):(OI)(CI)F", "*$($SidAdmins):(OI)(CI)F", "*$($SidUsers):(OI)(CI)RX", '/Q')
        , @($ExePath, '/reset', '/Q')
        , @($InstallDir, '/setowner', "*$SidAdmins", '/T', '/Q')
    )
    foreach ($icaclsArgs in $steps) {
        $out = & icacls.exe @icaclsArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw ('icacls ' + ($icaclsArgs -join ' ') + "`n" + ($out -join "`n")) }
    }
}

function Install-Guard {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not (Test-Path -LiteralPath $SourceFile)) { throw ($M.ErrSource -f $SourceFile) }
    foreach ($svcKey in 'Services\Usb4HostRouter', 'Services\Usb4DeviceRouter') {
        if (-not (Test-Path -LiteralPath "$RegBase\$svcKey")) { throw $M.ErrServices }
    }
    $csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
    if (-not (Test-Path -LiteralPath $csc)) { throw ($M.ErrCompiler -f $csc) }

    # Compilazione in una cartella temporanea, poi copia nella cartella protetta.
    # La compilazione non tocca il sistema: si fa anche con -WhatIf, come verifica.
    $existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    $work = Join-Path ([IO.Path]::GetTempPath()) ('Usb4BootGuard-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -WhatIf:$false | Out-Null
    try {
        $built = Join-Path $work 'Usb4BootGuard.exe'
        Write-Host ($M.Compiling -f $SourceFile)
        $out = & $csc /nologo /target:exe /optimize+ /warnaserror+ "/out:$built" /reference:System.ServiceProcess.dll $SourceFile 2>&1
        if ($LASTEXITCODE -ne 0) { throw ($M.ErrCompile + "`n" + ($out -join "`n")) }

        if ($existing) {
            Write-Host $M.Updating
            if ($existing.Status -ne 'Stopped' -and $PSCmdlet.ShouldProcess($ServiceName, 'Stop-Service')) {
                Stop-Service -Name $ServiceName -Force
                $existing.WaitForStatus('Stopped', '00:00:30')
            }
        }
        Write-Host ($M.Installing -f $InstallDir)
        if ($PSCmdlet.ShouldProcess($ExePath, 'Copy-Item')) {
            New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
            Copy-Item -LiteralPath $built -Destination $ExePath -Force
        }
        Set-InstallDirAcl
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue -WhatIf:$false
    }

    if (-not [Diagnostics.EventLog]::SourceExists($ServiceName) -and $PSCmdlet.ShouldProcess($ServiceName, 'New-EventLog')) {
        New-EventLog -LogName Application -Source $ServiceName
    }
    if (-not $existing) {
        if ($PSCmdlet.ShouldProcess($ServiceName, 'New-Service')) {
            New-Service -Name $ServiceName -BinaryPathName ('"{0}"' -f $ExePath) -DisplayName 'USB4 Boot Guard' `
                -Description $M.ServiceDescription -StartupType Automatic | Out-Null
        }
    } elseif ($PSCmdlet.ShouldProcess($ServiceName, 'Set-Service')) {
        Set-Service -Name $ServiceName -StartupType Automatic -Description $M.ServiceDescription
    }
    if ($PSCmdlet.ShouldProcess($ServiceName, 'sc.exe failure')) {
        # Se il servizio si interrompe, Windows lo riavvia.
        $null = & sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/5000/restart/60000
        if ($LASTEXITCODE -ne 0) { throw "sc.exe failure $ServiceName" }
    }
    if ($PSCmdlet.ShouldProcess($ServiceName, 'Start-Service')) {
        Start-Service -Name $ServiceName
        (Get-Service -Name $ServiceName).WaitForStatus('Running', '00:00:30')
    }
}

function Uninstall-Guard {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.Status -ne 'Stopped' -and $PSCmdlet.ShouldProcess($ServiceName, 'Stop-Service')) {
            Stop-Service -Name $ServiceName -Force
            $existing.WaitForStatus('Stopped', '00:00:30')
        }
        if ($PSCmdlet.ShouldProcess($ServiceName, 'sc.exe delete')) {
            $null = & sc.exe delete $ServiceName
            if ($LASTEXITCODE -ne 0) { throw "sc.exe delete $ServiceName" }
        }
    } else {
        Write-Host $M.NotInstalled
    }
    # Il programma puo' restare bloccato per qualche istante dopo l'arresto.
    # La sorgente degli eventi resta registrata, cosi' gli eventi passati restano leggibili.
    if ((Test-Path -LiteralPath $InstallDir) -and $PSCmdlet.ShouldProcess($InstallDir, 'Remove-Item')) {
        for ($i = 0; $i -lt 10 -and (Test-Path -LiteralPath $InstallDir); $i++) {
            Remove-Item -LiteralPath $InstallDir -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $InstallDir) { Start-Sleep -Milliseconds 500 }
        }
        if (Test-Path -LiteralPath $InstallDir) { throw ($M.ErrRemove -f $InstallDir) }
    }
}

# Porta Start a 3 e misura quanto ci mette il servizio a rimetterlo a 0.
# Il blocco finally garantisce Start = 0 all'uscita, anche con Ctrl+C.
function Invoke-SelfTest {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if (-not $svc -or $svc.Status -ne 'Running') { throw $M.ErrNeedService }

    $allOk = $true
    foreach ($name in 'Usb4HostRouter', 'Usb4DeviceRouter') {
        $path = "$RegBase\Services\$name"
        if (-not $PSCmdlet.ShouldProcess("$path\Start", 'Set-ItemProperty 3')) { continue }
        Write-Host ($M.SelfTestStep -f $name)
        $observed = $null
        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            Set-ItemProperty -LiteralPath $path -Name Start -Value 3 -Type DWord
            do {
                $observed = (Get-ItemProperty -LiteralPath $path -Name Start).Start
                if ($observed -eq 0) { break }
                Start-Sleep -Milliseconds 50
            } while ($sw.ElapsedMilliseconds -lt 5000)
        } finally {
            if ((Get-ItemProperty -LiteralPath $path -Name Start).Start -ne 0) {
                Set-ItemProperty -LiteralPath $path -Name Start -Value 0 -Type DWord
            }
        }
        if ($observed -eq 0) {
            Write-Host ($M.SelfTestOk -f $sw.ElapsedMilliseconds)
        } else {
            Write-Host ($M.SelfTestFail -f $sw.ElapsedMilliseconds, $observed)
            $allOk = $false
        }
    }
    return $allOk
}

# --- Main -------------------------------------------------------------------
try {
    if ($Status) {
        if (Show-Status) { exit 0 }
        exit 1
    }

    if (-not (Test-Admin)) { throw $M.ErrAdmin }

    if ($SelfTest) {
        Write-Host ''
        if (Invoke-SelfTest) {
            Write-Host ''
            Write-Host $M.SelfTestPassed
            exit 0
        }
        Write-Host ''
        Write-Host $M.SelfTestFailed
        exit 1
    }

    if ($Uninstall) {
        Uninstall-Guard
        if (-not $WhatIfPreference) { Write-Host $M.Removed }
        exit 0
    }

    Install-Guard
    if ($WhatIfPreference) { exit 0 }
    # Il servizio corregge i valori appena parte: gli lascio un istante.
    Start-Sleep -Seconds 1
    Write-Host ''
    $allOk = Show-Status
    Write-Host ''
    if ($allOk) {
        Write-Host $M.Done
        Write-Host $M.NextSelfTest
        exit 0
    }
    Write-Host $M.WarnValues
    exit 1
} catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
