#!/usr/bin/env bash
# restore-hive-backup.sh — Ripristina una copia di sicurezza del registro di sistema
# (SYSTEM.bak*) creata da patch-windows-hive.sh, sull'installazione Windows OFFLINE.
#
# Uso (sessione live di Ubuntu):
#   ./scripts/restore-hive-backup.sh /dev/nvme0n1p3            # ripristina la copia piu' recente
#   ./scripts/restore-hive-backup.sh /dev/nvme0n1p3 NOMEFILE   # ripristina una copia specifica
# Se la partizione e' cifrata con BitLocker, lo script chiede la chiave di ripristino
# (48 cifre) e la sblocca con cryptsetup. Questa funzione non e' ancora stata verificata.

set -euo pipefail

MNT=/mnt/winssd
PART="${1:-}"
CHOICE="${2:-}"

die() { echo "ERRORE: $*" >&2; exit 1; }

[ -n "$PART" ] || die "uso: $0 /dev/<partizione-windows> [nome-copia]"
[ -b "$PART" ] || die "$PART non e' un dispositivo a blocchi."
FSTYPE="$(lsblk -no FSTYPE "$PART")"
case "$FSTYPE" in
  ntfs|BitLocker) ;;
  *) die "$PART non e' NTFS ne' BitLocker (trovato: ${FSTYPE:-nessun filesystem})." ;;
esac
if findmnt -rn -S "$PART" >/dev/null 2>&1; then die "$PART e' gia' montata: smontala prima."; fi

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

MOUNT_SRC="$PART"
if [ "$FSTYPE" = "BitLocker" ]; then
  command -v cryptsetup >/dev/null 2>&1 || { sudo apt-get update; sudo apt-get install -y cryptsetup; }
  MAPPER="winssd-$$"
  echo "La partizione e' cifrata con BitLocker: inserisci la chiave di ripristino (48 cifre, con i trattini)."
  sudo cryptsetup open --type bitlk "$PART" "$MAPPER" || die "sblocco BitLocker non riuscito."
  MOUNT_SRC="/dev/mapper/$MAPPER"
fi

sudo mkdir -p "$MNT"
sudo mount -t ntfs3 "${MOUNT_OPTS[@]}" "$MOUNT_SRC" "$MNT" || die "mount fallito (eventualmente riprova con FORCE=1)."

CFG="$MNT/Windows/System32/config"
[ -f "$CFG/SYSTEM" ] || die "registro di sistema non trovato in $CFG."

echo "Copie disponibili:"
ls -1t "$CFG"/SYSTEM.bak* 2>/dev/null | sed 's|.*/|  |' || die "nessuna copia SYSTEM.bak* trovata."

if [ -n "$CHOICE" ]; then
  SRC="$CFG/$CHOICE"
else
  SRC="$(ls -1t "$CFG"/SYSTEM.bak* | head -n1)"
fi
[ -f "$SRC" ] || die "copia non trovata: $SRC"

echo
echo "Ripristino: $(basename "$SRC")  ->  SYSTEM"
read -r -p "Confermi? Scrivi SI per procedere: " ANS
[ "$ANS" = "SI" ] || { echo "Annullato."; exit 0; }

# Conserva anche lo stato attuale, per sicurezza
sudo cp -p "$CFG/SYSTEM" "$CFG/SYSTEM.prerestore-$(date +%Y%m%d-%H%M%S)"
sudo cp -p "$SRC" "$CFG/SYSTEM"
echo "Ripristino completato."
