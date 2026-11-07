#!/usr/bin/env bash
# check-bios.sh — Verifica in SOLA LETTURA.
# Mostra gli attributi del BIOS Dell rilevanti per l'avvio via Thunderbolt
# e lo stato del collegamento Thunderbolt. Non modifica nulla.
#
# Uso (sessione live di Ubuntu):  ./scripts/check-bios.sh

set -uo pipefail

BASE=/sys/class/firmware-attributes/dell-wmi-sysman

echo "== Interfaccia BIOS Dell (dell-wmi-sysman)"
sudo modprobe dell-wmi-sysman 2>/dev/null || true
if [ ! -d "$BASE" ]; then
  echo "   Non disponibile: il firmware non espone gli attributi tramite dell-wmi-sysman."
  echo "   Questa procedura non e' applicabile a questo PC."
  exit 1
fi

if [ -r "$BASE/authentication/Admin/is_enabled" ]; then
  pw="$(cat "$BASE/authentication/Admin/is_enabled")"
  if [ "$pw" = "0" ]; then
    echo "   Password amministratore del BIOS: non impostata"
  else
    echo "   Password amministratore del BIOS: IMPOSTATA (le modifiche richiedono la password)"
  fi
fi
echo

show_attr() {
  local name="$1" d="$BASE/attributes/$1"
  if [ -d "$d" ]; then
    echo "== $name"
    echo "   Nome:              $(cat "$d/display_name" 2>/dev/null)"
    echo "   Valore attuale:    $(sudo cat "$d/current_value" 2>/dev/null)"
    echo "   Valori possibili:  $(cat "$d/possible_values" 2>/dev/null || echo n/d)"
  else
    echo "== $name: NON PRESENTE"
  fi
  echo
}

show_attr ThunderboltBoot
show_attr PreBootDma

echo "== Altri attributi con 'thunder', 'tbt' o 'boot' nel nome"
ls "$BASE/attributes/" | grep -iE 'thunder|tbt|boot' | sed 's/^/   /'
echo

echo "== Controller Thunderbolt/USB4 (lspci)"
lspci | grep -i thunderbolt | sed 's/^/   /' || echo "   Nessuno trovato"
echo

echo "== Dispositivi Thunderbolt collegati (boltctl)"
if command -v boltctl >/dev/null 2>&1; then
  boltctl list
  echo "   Nota: se pubblichi questo output, togli la riga 'uuid'."
else
  echo "   boltctl non disponibile"
fi
echo

echo "== Dischi (il disco interno non dovrebbe comparire se hai usato modprobe.blacklist=vmd)"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL | grep -v '^loop'
echo

echo "Esito:"
if [ -d "$BASE/attributes/ThunderboltBoot" ]; then
  echo "  ThunderboltBoot e' presente: puoi proseguire con ./scripts/thunderbolt-boot.sh"
else
  echo "  ThunderboltBoot non e' presente: questa procedura non e' applicabile."
fi
