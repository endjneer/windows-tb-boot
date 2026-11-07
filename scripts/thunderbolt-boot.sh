#!/usr/bin/env bash
# thunderbolt-boot.sh — Attiva (default) o disattiva l'attributo BIOS nascosto
# "ThunderboltBoot" (Enable Thunderbolt Boot Support) tramite dell-wmi-sysman.
#
# Uso (sessione live di Ubuntu):
#   ./scripts/thunderbolt-boot.sh            # imposta Enabled
#   ./scripts/thunderbolt-boot.sh --disable  # imposta Disabled
#
# La modifica viene applicata al riavvio successivo.

set -euo pipefail

BASE=/sys/class/firmware-attributes/dell-wmi-sysman
ATTR="$BASE/attributes/ThunderboltBoot"

die() { echo "ERRORE: $*" >&2; exit 1; }

case "${1:-}" in
  "")        WANT="Enabled" ;;
  --disable) WANT="Disabled" ;;
  *)         die "argomento non riconosciuto: $1 (usa nessun argomento oppure --disable)" ;;
esac

sudo modprobe dell-wmi-sysman 2>/dev/null || true
[ -d "$BASE" ] || die "interfaccia dell-wmi-sysman non disponibile."
[ -d "$ATTR" ] || die "l'attributo ThunderboltBoot non esiste su questo firmware: procedura non applicabile."

if [ "$(cat "$BASE/authentication/Admin/is_enabled" 2>/dev/null || echo 0)" != "0" ]; then
  die "e' impostata una password di amministratore del BIOS. Senza di essa non si puo' modificare l'attributo."
fi

grep -q "$WANT" "$ATTR/possible_values" || die "il valore $WANT non e' tra quelli ammessi: $(cat "$ATTR/possible_values")"

CUR="$(sudo cat "$ATTR/current_value")"
echo "Attributo:       $(cat "$ATTR/display_name")"
echo "Valore attuale:  $CUR"
echo "Valore richiesto: $WANT"

if [ "$CUR" = "$WANT" ]; then
  echo "Nessuna modifica necessaria."
  exit 0
fi

if [ "$WANT" = "Enabled" ]; then
  cat <<'EOF'

ATTENZIONE
- Con ThunderboltBoot attivo, i dispositivi collegati alla porta Thunderbolt durante
  l'avvio vengono autorizzati prima del sistema operativo (protezione DMA ridotta).
- La modifica del BIOS potrebbe far chiedere la recovery key di BitLocker al sistema
  del disco interno: assicurati di poterla ottenere.
- Non modificare PreBootDma: deve restare Enabled.
EOF
fi

read -r -p "Confermi la modifica del BIOS? Scrivi SI per procedere: " ANS
[ "$ANS" = "SI" ] || { echo "Annullato."; exit 0; }

echo "$WANT" | sudo tee "$ATTR/current_value" >/dev/null

PENDING="$(sudo cat "$BASE/attributes/pending_reboot" 2>/dev/null || echo '?')"
echo "pending_reboot = $PENDING  (1 = modifica in attesa di riavvio)"
echo "Fatto. Spegni il PC, lascia il box collegato e riaccendi: con F12 dovrebbe comparire l'SSD."
