# check-standby.ps1 - READ-ONLY, changes nothing.
# Collects in one run the checks of the troubleshooting entries about sleep,
# black screens and unexpected restarts when Windows runs from an external
# Thunderbolt/USB4 SSD: sleep states, power settings, restarts without a clean
# shutdown (event 41) with their stop code, failed dump writes (volmgr 161),
# Modern Standby cycles (506) and corrected PCIe errors (WHEA-Logger 17).
#
# The output contains no hardware IDs, serial numbers or device names, so it can
# be pasted into an issue as it is. Only the "powercfg /a" section is localized.
# First run on real hardware: 18/11/2026.
#
# Usage, in PowerShell (administrator rights are not needed):
#   .\check-standby.ps1              last 30 days
#   .\check-standby.ps1 -Days 7      last 7 days
#   .\check-standby.ps1 -Lang en     force the language (it or en)
# If script execution is blocked:
#   powershell -ExecutionPolicy Bypass -File .\check-standby.ps1

[CmdletBinding()]
param(
  [ValidateRange(1, 365)][int]$Days = 30,
  [ValidateSet('it', 'en')][string]$Lang
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Lang) {
  $Lang = if ([cultureinfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'it') { 'it' } else { 'en' }
}
function T([string]$It, [string]$En) { if ($Lang -eq 'it') { $It } else { $En } }
function Title([string]$Text) { ''; "== $Text" }

$since = (Get-Date).AddDays(-$Days)

# Events of one provider and one or more IDs since $since, oldest first. Empty array if none.
function Get-Events([string]$Provider, [int[]]$Id) {
  $filter = @{ LogName = 'System'; ProviderName = $Provider; Id = $Id; StartTime = $since }
  @(Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue | Sort-Object TimeCreated)
}

# The named <Data> fields of an event, as a hashtable.
function Get-EventData($Evt) {
  $data = @{}
  foreach ($node in ([xml]$Evt.ToXml()).Event.EventData.Data) {
    $name = $node.GetAttribute('Name')
    if ($name) { $data[$name] = $node.InnerText }
  }
  $data
}

# AC and DC values of a power setting of the active scheme, or $null if the setting is hidden.
function Get-PowerSetting([string]$SubGroup, [string]$Setting) {
  $lines = @(& powercfg.exe /query SCHEME_CURRENT $SubGroup $Setting 2>$null)
  $values = @($lines | Where-Object { $_ -match ':\s*0x[0-9a-fA-F]{8}\s*$' } |
      ForEach-Object { [Convert]::ToInt64(($_ -replace '^.*:\s*', '').Trim(), 16) })
  # The last two matching lines are the current AC and DC indexes.
  if ($values.Count -lt 2) { return $null }
  [pscustomobject]@{ AC = $values[$values.Count - 2]; DC = $values[$values.Count - 1] }
}
function Format-Seconds($Value) {
  if ($null -eq $Value) { return (T 'non disponibile' 'not available') }
  if ($Value -eq 0) { return (T 'mai' 'never') }
  '{0} s' -f $Value
}
function Get-RegistryValue([string]$Path, [string]$Name) {
  $item = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
  if ($null -eq $item) { return $null }
  $item.$Name
}

"check-standby.ps1 - $(T 'sola lettura' 'read-only') - $(T 'ultimi' 'last') $Days $(T 'giorni' 'days')"

# --- 1. Sleep states -------------------------------------------------------
Title (T 'Stati di sospensione (powercfg /a)' 'Sleep states (powercfg /a)')
& powercfg.exe /a 2>$null | Where-Object { $_.Trim() }

# --- 2. Power settings -----------------------------------------------------
Title (T 'Impostazioni, a corrente / a batteria' 'Settings, on AC / on battery')
$standby = Get-PowerSetting 'SUB_SLEEP' 'STANDBYIDLE'
$video = Get-PowerSetting 'SUB_VIDEO' 'VIDEOIDLE'
$aspm = Get-PowerSetting 'SUB_PCIEXPRESS' 'ASPM'
$aspmNames = @{ 0 = (T 'inattivo' 'off'); 1 = (T 'moderato' 'moderate'); 2 = (T 'massimo' 'maximum') }
function Format-Aspm($Value) {
  if ($null -eq $Value) { return (T 'non disponibile' 'not available') }
  if ($aspmNames.ContainsKey([int]$Value)) { return ('{0} ({1})' -f $Value, $aspmNames[[int]$Value]) }
  "$Value"
}
$ac = { param($s) if ($null -eq $s) { $null } else { $s.AC } }
$dc = { param($s) if ($null -eq $s) { $null } else { $s.DC } }
'{0,-46} {1} / {2}' -f (T 'Entra in sospensione dopo' 'Sleep after'), (Format-Seconds (& $ac $standby)), (Format-Seconds (& $dc $standby))
'{0,-46} {1} / {2}' -f (T 'Disattiva schermo dopo' 'Turn off the display after'), (Format-Seconds (& $ac $video)), (Format-Seconds (& $dc $video))
'{0,-46} {1} / {2}' -f (T 'Risparmio energia collegamenti PCIe (ASPM)' 'PCIe link power saving (ASPM)'), (Format-Aspm (& $ac $aspm)), (Format-Aspm (& $dc $aspm))

$hibernate = Get-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
$crashDump = Get-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' 'CrashDumpEnabled'
$autoReboot = Get-RegistryValue 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' 'AutoReboot'
$show = { param($v) if ($null -eq $v) { T 'non impostato' 'not set' } else { '0x{0:X}' -f [int64]$v } }
'{0,-46} {1}' -f (T 'Ibernazione attiva (HibernateEnabled)' 'Hibernation enabled (HibernateEnabled)'), (& $show $hibernate)
'{0,-46} {1}' -f (T 'Scrittura del dump (CrashDumpEnabled)' 'Dump writing (CrashDumpEnabled)'), (& $show $crashDump)
'{0,-46} {1}' -f (T 'Riavvio automatico (AutoReboot)' 'Automatic restart (AutoReboot)'), (& $show $autoReboot)

# --- 3. System disk path ---------------------------------------------------
# Walks the device tree from the system disk to the root, like show-disk-paths.ps1,
# but keeps the instance IDs to itself and prints only what it concludes.
Title (T 'Disco di sistema' 'System disk')
$pathIds = @()
$onUsb4 = $false
$external = $false
try {
  $disks = @(Get-PnpDevice -PresentOnly -Class DiskDrive)
  $bootName = (Get-Disk | Where-Object { $_.IsBoot } | Select-Object -First 1).FriendlyName
  $systemDisk = @($disks | Where-Object { $_.FriendlyName -eq $bootName }) | Select-Object -First 1
  if (-not $systemDisk -and $disks.Count -eq 1) { $systemDisk = $disks[0] }
  (T 'Dischi visibili: ' 'Visible disks: ') + $disks.Count
  if ($systemDisk) {
    $id = $systemDisk.InstanceId
    while ($id) {
      $pathIds += $id
      $device = Get-PnpDevice -InstanceId $id -ErrorAction SilentlyContinue
      if ($device -and ("$($device.Service)" -match '^Usb4(Host|Device)Router$')) { $onUsb4 = $true }
      # A disk tunnelled over PCIe does not descend from the USB4 router device: its
      # path is made of PCI bridges. What marks it as external is its device container.
      $local = Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_InLocalMachineContainer -ErrorAction SilentlyContinue
      if ($local -and $local.PSObject.Properties['Data'] -and ($local.Data -eq $false)) { $external = $true }
      $parent = Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_Parent -ErrorAction SilentlyContinue
      # At the root of the tree the property object has no Data member.
      $id = if ($parent -and $parent.PSObject.Properties['Data'] -and $parent.Data) { [string]$parent.Data } else { $null }
    }
    if ($onUsb4 -or $external) { T 'Il disco di sistema risulta esterno al notebook.' 'The system disk appears to be external to the notebook.' }
    else { T 'Nessun indizio che il disco di sistema sia esterno. Il controllo non riconosce tutti i box: non prenderlo come prova che sia interno.' 'No sign that the system disk is external. The check does not recognize every enclosure: do not take it as proof that it is internal.' }
  } else {
    T 'Disco di sistema non identificato tra i dispositivi.' 'System disk not identified among the devices.'
  }
} catch {
  (T 'Controllo non riuscito: ' 'Check failed: ') + $_.Exception.Message
}

# --- 4. Restarts without a clean shutdown ----------------------------------
Title (T 'Riavvii senza un regolare arresto (evento 41)' 'Restarts without a clean shutdown (event 41)')
$restarts = Get-Events 'Microsoft-Windows-Kernel-Power' 41
$dumpFailures = Get-Events 'volmgr' 161
$rows = foreach ($evt in $restarts) {
  $data = Get-EventData $evt
  $code = 0
  if ($data['BugcheckCode']) { $code = [int64]$data['BugcheckCode'] }
  # volmgr 161 is logged at the next boot, a few seconds around event 41.
  $noDump = @($dumpFailures | Where-Object { [math]::Abs(($_.TimeCreated - $evt.TimeCreated).TotalSeconds) -le 120 }).Count -gt 0
  [pscustomobject]@{
    Time            = $evt.TimeCreated.ToString('yyyy-MM-dd HH:mm')
    BugcheckCode    = '0x{0:X}' -f $code
    SleepInProgress = $data['SleepInProgress']
    ModernStandby   = $data['ConnectedStandbyInProgress']
    DumpNotWritten  = $noDump
  }
}
$rows = @($rows)
if ($rows.Count) { $rows | Format-Table -AutoSize | Out-String -Width 160 }
else { T 'Nessuno.' 'None.' }

# --- 5. Modern Standby cycles ----------------------------------------------
Title (T 'Standby moderno' 'Modern Standby')
$entries = Get-Events 'Microsoft-Windows-Kernel-Power' 506
(T 'Ingressi in standby (evento 506): ' 'Standby entries (event 506): ') + $entries.Count
if ($entries.Count) {
  T 'Per motivo (codice del campo Reason):' 'By reason (code of the Reason field):'
  $entries | ForEach-Object { (Get-EventData $_)['Reason'] } | Group-Object | Sort-Object Count -Descending |
    ForEach-Object { '  {0,5}  Reason = {1}' -f $_.Count, $_.Name }
}

# --- 6. Corrected PCIe errors ----------------------------------------------
Title (T 'Errori hardware corretti (WHEA-Logger 17)' 'Corrected hardware errors (WHEA-Logger 17)')
$whea = Get-Events 'Microsoft-Windows-WHEA-Logger' 17
$onPath = 0
$deviceNames = @{}
foreach ($evt in $whea) {
  $name = (Get-EventData $evt)['PrimaryDeviceName']
  if (-not $name) { continue }
  $deviceNames[$name] = $true
  if (@($pathIds | Where-Object { $_.StartsWith("$name\", [StringComparison]::OrdinalIgnoreCase) }).Count) { $onPath++ }
}
(T 'Totale: ' 'Total: ') + $whea.Count
if ($whea.Count) {
  (T 'Su dispositivi del percorso del disco di sistema: ' 'On devices of the system disk path: ') + $onPath
  (T 'Dispositivi diversi coinvolti: ' 'Different devices involved: ') + $deviceNames.Count
  $firstDay = $whea[0].TimeCreated.ToString('yyyy-MM-dd')
  $lastDay = $whea[$whea.Count - 1].TimeCreated.ToString('yyyy-MM-dd')
  (T 'Dal ' 'From ') + $firstDay + (T ' al ' ' to ') + $lastDay
}

# --- 7. Reading ------------------------------------------------------------
Title (T 'Lettura' 'Reading')
$notes = @()
$withCode = @($rows | Where-Object { $_.BugcheckCode -ne '0x0' })
$inStandby = @($rows | Where-Object { "$($_.ModernStandby)" -eq 'true' })
$inHibernate = @($rows | Where-Object { "$($_.SleepInProgress)" -eq '5' })
$withoutDump = @($rows | Where-Object { $_.DumpNotWritten })
if ($withoutDump.Count) {
  $notes += (T "$($withoutDump.Count) riavvii con il dump non scritto: Windows aveva perso il disco di sistema. Problemi frequenti, 'Lo schermo resta nero, le ventole girano e Windows non si riavvia da solo'." "$($withoutDump.Count) restarts with the dump not written: Windows had lost the system disk. Troubleshooting, 'The screen stays black, the fans spin and Windows does not restart by itself'.")
}
if ($inStandby.Count) {
  $notes += (T "$($inStandby.Count) riavvii con lo standby moderno in corso. Problemi frequenti, 'Dopo la sospensione lo schermo resta nero e le ventole girano'." "$($inStandby.Count) restarts with Modern Standby in progress. Troubleshooting, 'After sleep the screen stays black and the fans keep running'.")
}
if ($inHibernate.Count) {
  $notes += (T "$($inHibernate.Count) riavvii durante un passaggio all'ibernazione (SleepInProgress = 5)." "$($inHibernate.Count) restarts during a transition to hibernation (SleepInProgress = 5).")
}
if ($whea.Count -and $onPath -gt 0) {
  $notes += (T "Errori PCIe corretti sul collegamento con il disco di sistema: $onPath." "Corrected PCIe errors on the link to the system disk: $onPath.")
}
if ($standby -and $standby.AC -eq 0 -and $inStandby.Count) {
  $notes += (T 'A corrente la sospensione e'' su mai, ma ci sono riavvii in standby: controlla lo spegnimento dello schermo e la chiusura del coperchio.' 'On AC sleep is set to never, yet there are restarts in standby: check the display timeout and the lid action.')
}
if (-not $notes.Count) {
  if ($rows.Count -eq 0) { $notes += (T 'Nessun riavvio anomalo nel periodo.' 'No unexpected restart in the period.') }
  elseif ($withCode.Count -eq 0) { $notes += (T 'Solo spegnimenti forzati senza codice di arresto.' 'Only forced power-offs with no stop code.') }
}
$notes | ForEach-Object { "- $_" }
