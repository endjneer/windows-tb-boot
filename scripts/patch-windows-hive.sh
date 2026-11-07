#!/usr/bin/env bash
# patch-windows-hive.sh — Applica al registro di un'installazione Windows OFFLINE
# le modifiche necessarie all'avvio via Thunderbolt:
#   - BootDriverFlags = 0x14 in ControlSet001\Control
#   - Start = 0 per i servizi Usb4HostRouter e Usb4DeviceRouter
# Crea sempre una copia di sicurezza del registro prima di modificarlo.
#
# Uso (sessione live di Ubuntu):
#   ./scripts/patch-windows-hive.sh /dev/nvme0n1p3
#   FORCE=1 ./scripts/patch-windows-hive.sh /dev/nvme0n1p3   # se il volume NTFS e' "dirty"
# Se la partizione e' cifrata con BitLocker, lo script chiede la chiave di ripristino
# (48 cifre) e la sblocca con cryptsetup. Questa funzione non e' ancora stata verificata.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REG_DIR="$SCRIPT_DIR/../registry"
MNT=/mnt/winssd
PART="${1:-}"

die() { echo "ERRORE: $*" >&2; exit 1; }

# --- Controlli sulla partizione -------------------------------------------
[ -n "$PART" ] || die "uso: $0 /dev/<partizione-windows-dell-ssd-esterno>"
[ -b "$PART" ] || die "$PART non e' un dispositivo a blocchi."
[ "$(lsblk -no TYPE "$PART")" = "part" ] || die "$PART non e' una partizione."
FSTYPE="$(lsblk -no FSTYPE "$PART")"
case "$FSTYPE" in
  ntfs|BitLocker) ;;
  *) die "$PART non e' NTFS ne' BitLocker (trovato: ${FSTYPE:-nessun filesystem})." ;;
esac
if findmnt -rn -S "$PART" >/dev/null 2>&1; then
  die "$PART e' gia' montata: smontala prima di procedere."
fi

DISK="/dev/$(lsblk -no PKNAME "$PART")"
echo "Partizione selezionata: $PART"
echo "Disco a cui appartiene:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL "$DISK"
echo
read -r -p "E' la partizione di Windows dell'SSD ESTERNO? Scrivi SI per procedere: " ANS
[ "$ANS" = "SI" ] || { echo "Annullato."; exit 0; }

# --- Strumento hivexregedit ------------------------------------------------
if ! command -v hivexregedit >/dev/null 2>&1; then
  echo "Installo hivexregedit (pacchetto libwin-hivex-perl)..."
  sudo apt-get update
  sudo apt-get install -y libwin-hivex-perl
fi

# --- Mount ---------------------------------------------------------------
MOUNT_OPTS=()
[ "${FORCE:-0}" = "1" ] && MOUNT_OPTS=(-o force)

MAPPER=""
cleanup() {
  sync
  if mountpoint -q "$MNT"; then sudo umount "$MNT" && echo "Partizione smontata."; fi
  if [ -n "$MAPPER" ] && [ -e "/dev/mapper/$MAPPER" ]; then
    sudo cryptsetup close "$MAPPER" && echo "Volume BitLocker richiuso."
  fi
}
trap cleanup EXIT

SRC="$PART"
if [ "$FSTYPE" = "BitLocker" ]; then
  command -v cryptsetup >/dev/null 2>&1 || { sudo apt-get update; sudo apt-get install -y cryptsetup; }
  MAPPER="winssd-$$"
  echo "La partizione e' cifrata con BitLocker: inserisci la chiave di ripristino (48 cifre, con i trattini)."
  sudo cryptsetup open --type bitlk "$PART" "$MAPPER" || die "sblocco BitLocker non riuscito."
  SRC="/dev/mapper/$MAPPER"
fi

sudo mkdir -p "$MNT"
sudo mount -t ntfs3 "${MOUNT_OPTS[@]}" "$SRC" "$MNT" \
  || die "mount fallito. Se il volume risulta 'dirty' riprova con FORCE=1 (vedi docs/troubleshooting.it.md)."

HIVE="$MNT/Windows/System32/config/SYSTEM"
[ -f "$HIVE" ] || die "registro di sistema non trovato ($HIVE): e' davvero la partizione di Windows?"

# --- Controlli sul registro ---------------------------------------------
CUR="$(sudo hivexregedit --export "$HIVE" '\Select' | tr -d '\r' \
        | sed -n 's/^"Current"=dword:0*\([0-9a-fA-F]*\)$/\1/p')"
[ "$CUR" = "1" ] || die "il control set attivo non e' 001 (trovato: ${CUR:-?}): i file .reg andrebbero adattati."

for svc in Usb4HostRouter Usb4DeviceRouter; do
  sudo hivexregedit --export "$HIVE" "\\ControlSet001\\Services\\$svc" >/dev/null 2>&1 \
    || die "il servizio $svc non esiste in questa installazione: versione di Windows non compatibile con questa correzione."
done

# --- Copia di sicurezza ----------------------------------------------------
BACKUP="$HIVE.bak-$(date +%Y%m%d-%H%M%S)"
sudo cp -p "$HIVE" "$BACKUP"
echo "Copia di sicurezza creata: $BACKUP"

# --- Applicazione delle modifiche --------------------------------------------
for f in bootdriverflags.reg usb4-boot-start.reg; do
  [ -f "$REG_DIR/$f" ] || die "file mancante: $REG_DIR/$f"
  echo "Applico $f ..."
  sudo hivexregedit --merge --prefix 'HKEY_LOCAL_MACHINE\SYSTEM' "$HIVE" "$REG_DIR/$f"
done

# --- Verifica ------------------------------------------------------------
echo
echo "Verifica:"
OK=1
check() {  # $1 = chiave, $2 = nome valore, $3 = valore atteso
  local line
  line="$(sudo hivexregedit --export "$HIVE" "$1" | tr -d '\r' | grep "^\"$2\"=" | head -n1 || true)"
  if [ "$line" = "\"$2\"=$3" ]; then
    echo "  OK  $1  $line"
  else
    echo "  NO  $1  ${line:-(valore assente)}  (atteso \"$2\"=$3)"
    OK=0
  fi
}
check '\ControlSet001\Control' BootDriverFlags 'dword:00000014'
check '\ControlSet001\Services\Usb4HostRouter' Start 'dword:00000000'
check '\ControlSet001\Services\Usb4DeviceRouter' Start 'dword:00000000'

echo
if [ "$OK" = "1" ]; then
  echo "Correzione applicata. Riavvia con il box collegato e avvia l'SSD dal menu F12."
else
  echo "Qualcosa non e' andato a buon fine. Puoi ripristinare la copia con ./scripts/restore-hive-backup.sh $PART"
  exit 1
fi
