# Test del servizio Usb4BootGuard (Pester 5 o successivo).
# Il programma gira in modalita' /console su chiavi di prova sotto
# HKEY_CURRENT_USER: il registro di sistema non viene mai toccato.
#
# Uso:  Invoke-Pester .\windows\tests

BeforeAll {
    $source = Join-Path $PSScriptRoot '..\usb4-boot-guard\Usb4BootGuard.cs'
    $csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'
    $script:Exe = Join-Path $TestDrive 'Usb4BootGuard.exe'
    $out = & $csc /nologo /target:exe /optimize+ /warnaserror+ "/out:$script:Exe" /reference:System.ServiceProcess.dll $source 2>&1
    if ($LASTEXITCODE -ne 0) { throw ($out -join "`n") }

    $script:TestRoot = 'Software\WindowsTbBoot\Test-' + [guid]::NewGuid().ToString('N')

    # Crea un control set di prova con i valori "rotti" dopo un aggiornamento.
    function Initialize-TestControlSet([string] $Name) {
        $rel = "$script:TestRoot\$Name\CurrentControlSet"
        $base = "HKCU:\$rel"
        foreach ($svc in 'Usb4HostRouter', 'Usb4DeviceRouter') {
            New-Item -Path "$base\Services\$svc" -Force | Out-Null
            New-ItemProperty -Path "$base\Services\$svc" -Name Start -PropertyType DWord -Value 3 | Out-Null
        }
        New-Item -Path "$base\Control" -Force | Out-Null
        return $rel
    }

    function Open-Guard([string] $RelBase, [int] $Seconds) {
        $psi = New-Object Diagnostics.ProcessStartInfo $script:Exe, "/console `"$RelBase`" $Seconds"
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        return [Diagnostics.Process]::Start($psi)
    }

    function Close-Guard([Diagnostics.Process] $Process) {
        if ($null -eq $Process) { return }
        if (-not $Process.HasExited) {
            $Process.StandardInput.WriteLine()
            if (-not $Process.WaitForExit(5000)) { $Process.Kill() }
        }
        $Process.StandardOutput.ReadToEnd()
    }

    # Valore attuale come "tipo:valore", oppure "assente".
    function Get-TestValue([string] $RelBase, [string] $SubKey, [string] $Name) {
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("$RelBase\$SubKey")
        if ($null -eq $key) { return 'chiave assente' }
        try {
            $value = $key.GetValue($Name, $null)
            if ($null -eq $value) { return 'assente' }
            return '{0}:{1}' -f $key.GetValueKind($Name), $value
        } finally {
            $key.Close()
        }
    }

    function Wait-TestValue([string] $RelBase, [string] $SubKey, [string] $Name, [string] $Expected, [int] $TimeoutMs) {
        $sw = [Diagnostics.Stopwatch]::StartNew()
        do {
            $actual = Get-TestValue $RelBase $SubKey $Name
            if ($actual -eq $Expected) { break }
            Start-Sleep -Milliseconds 50
        } while ($sw.ElapsedMilliseconds -lt $TimeoutMs)
        return $actual
    }
}

AfterAll {
    if ($script:TestRoot) {
        Remove-Item -Path "HKCU:\$script:TestRoot" -Recurse -Force -ErrorAction SilentlyContinue
        $parent = Get-Item -Path 'HKCU:\Software\WindowsTbBoot' -ErrorAction SilentlyContinue
        if ($parent -and $parent.SubKeyCount -eq 0 -and $parent.ValueCount -eq 0) {
            Remove-Item -Path 'HKCU:\Software\WindowsTbBoot'
        }
    }
}

Describe 'Usb4BootGuard.exe' {
    It 'senza argomenti, fuori da un servizio, mostra l''uso ed esce con 2' {
        $null = & $script:Exe 2>&1
        $LASTEXITCODE | Should -Be 2
    }

    It 'rifiuta un intervallo non valido' {
        $null = & $script:Exe /console 'Software\WindowsTbBoot\Nessuno' 0 2>&1
        $LASTEXITCODE | Should -Be 2
    }
}

Describe 'Sorveglianza con notifiche (intervallo periodico lungo)' {
    BeforeAll {
        $script:Base = Initialize-TestControlSet 'notify'
        # 300 secondi: entro i timeout dei test agisce solo la notifica.
        $script:Proc = Open-Guard $script:Base 300
    }
    AfterAll {
        $script:Log = Close-Guard $script:Proc
    }

    It 'all''avvio corregge Start dei due driver e aggiunge BootDriverFlags' {
        Wait-TestValue $script:Base 'Services\Usb4HostRouter' 'Start' 'DWord:0' 5000 | Should -Be 'DWord:0'
        Wait-TestValue $script:Base 'Services\Usb4DeviceRouter' 'Start' 'DWord:0' 5000 | Should -Be 'DWord:0'
        Wait-TestValue $script:Base 'Control' 'BootDriverFlags' 'DWord:20' 5000 | Should -Be 'DWord:20'
    }

    It 'rimette Start = 0 entro un secondo quando viene riportato a 3' {
        foreach ($svc in 'Usb4HostRouter', 'Usb4DeviceRouter') {
            Set-ItemProperty -Path "HKCU:\$script:Base\Services\$svc" -Name Start -Value 3 -Type DWord
            Wait-TestValue $script:Base "Services\$svc" 'Start' 'DWord:0' 1000 | Should -Be 'DWord:0'
        }
    }

    It 'resiste a modifiche ripetute e ravvicinate' {
        1..20 | ForEach-Object {
            Set-ItemProperty -Path "HKCU:\$script:Base\Services\Usb4HostRouter" -Name Start -Value 3 -Type DWord
        }
        Wait-TestValue $script:Base 'Services\Usb4HostRouter' 'Start' 'DWord:0' 1000 | Should -Be 'DWord:0'
    }

    It 'converte un valore di tipo sbagliato in DWORD 0' {
        # Una sola scrittura che cambia il tipo: cancellare e ricreare darebbe
        # al guardiano il tempo di rimettere il DWORD in mezzo.
        Set-ItemProperty -Path "HKCU:\$script:Base\Services\Usb4DeviceRouter" -Name Start -Value '3' -Type String
        Wait-TestValue $script:Base 'Services\Usb4DeviceRouter' 'Start' 'DWord:0' 1000 | Should -Be 'DWord:0'
    }

    It 'ripristina un valore cancellato' {
        Remove-ItemProperty -Path "HKCU:\$script:Base\Control" -Name BootDriverFlags
        Wait-TestValue $script:Base 'Control' 'BootDriverFlags' 'DWord:20' 1000 | Should -Be 'DWord:20'
    }

    It 'non tocca gli altri valori delle chiavi' {
        New-ItemProperty -Path "HKCU:\$script:Base\Services\Usb4HostRouter" -Name ErrorControl -PropertyType DWord -Value 1 | Out-Null
        Start-Sleep -Milliseconds 300
        Get-TestValue $script:Base 'Services\Usb4HostRouter' 'ErrorControl' | Should -Be 'DWord:1'
    }

    It 'registra ogni correzione, col valore trovato' {
        $log = Close-Guard $script:Proc
        $log | Should -Match 'Services\\Usb4DeviceRouter\\Start String "3" -> 0x0'
        $log | Should -Match 'Control\\BootDriverFlags \S+ -> 0x14'
        $log | Should -Not -Match '\[4\]'
    }
}

Describe 'Chiavi mancanti (intervallo periodico breve)' {
    BeforeAll {
        $script:Base2 = Initialize-TestControlSet 'missing'
        $script:Proc2 = Open-Guard $script:Base2 1
    }
    AfterAll {
        $script:Log2 = Close-Guard $script:Proc2
    }

    It 'non ricrea la chiave di un servizio cancellato' {
        Wait-TestValue $script:Base2 'Services\Usb4DeviceRouter' 'Start' 'DWord:0' 5000 | Should -Be 'DWord:0'
        Remove-Item -Path "HKCU:\$script:Base2\Services\Usb4DeviceRouter" -Recurse
        Start-Sleep -Milliseconds 2500
        Get-TestValue $script:Base2 'Services\Usb4DeviceRouter' 'Start' | Should -Be 'chiave assente'
    }

    It 'torna a sorvegliare la chiave quando viene ricreata' {
        New-Item -Path "HKCU:\$script:Base2\Services\Usb4DeviceRouter" | Out-Null
        New-ItemProperty -Path "HKCU:\$script:Base2\Services\Usb4DeviceRouter" -Name Start -PropertyType DWord -Value 3 | Out-Null
        Wait-TestValue $script:Base2 'Services\Usb4DeviceRouter' 'Start' 'DWord:0' 3000 | Should -Be 'DWord:0'
        # E continua a correggerla anche dopo.
        Start-Sleep -Milliseconds 1500
        Set-ItemProperty -Path "HKCU:\$script:Base2\Services\Usb4DeviceRouter" -Name Start -Value 3 -Type DWord
        Wait-TestValue $script:Base2 'Services\Usb4DeviceRouter' 'Start' 'DWord:0' 1000 | Should -Be 'DWord:0'
    }
}
