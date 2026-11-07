# show-disk-paths.ps1 - SOLA LETTURA, non modifica nulla.
# Per ogni disco presente risale l'albero dei dispositivi fino alla radice
# e stampa nome e ID di ogni passaggio. Serve a identificare il controller
# (per esempio Intel VMD) da cui dipende ciascun disco, prima di bloccarlo.
#
# Uso, in PowerShell (non servono diritti di amministratore):
#   .\show-disk-paths.ps1
# Se l'esecuzione degli script e' bloccata:
#   powershell -ExecutionPolicy Bypass -File .\show-disk-paths.ps1

foreach ($disk in Get-PnpDevice -PresentOnly -Class DiskDrive) {
  "`n== $($disk.FriendlyName)"
  $id = $disk.InstanceId
  while ($id) {
    $dev = Get-PnpDevice -InstanceId $id
    "{0}  |  {1}" -f $dev.FriendlyName, $id
    $id = (Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_Parent -ErrorAction SilentlyContinue).Data
  }
}
