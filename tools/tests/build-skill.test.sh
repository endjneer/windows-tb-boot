#!/usr/bin/env bash
# build-skill.test.sh — test di tools/build-skill.sh.
# Ogni test lavora su una copia di prova del repository, in una cartella
# temporanea con uno spazio nel nome. Non tocca il repository vero.
#
# Uso:  bash tools/tests/build-skill.test.sh

set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/build-skill.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/build skill test.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

DOCS=(README.md README.it.md
      docs/guide.md docs/guide.it.md
      docs/quick-recovery.md docs/quick-recovery.it.md
      docs/troubleshooting.md docs/troubleshooting.it.md
      docs/how-it-works.md docs/how-it-works.it.md)
SKILL_REL=.claude/skills/windows-tb-boot
COPY_REL=$SKILL_REL/references/repo
TRIAGE=$SKILL_REL/references/triage.md
B=./tools/build-skill.sh
NAME_OK='name: windows-tb-boot'
DESC_OK='description: "Guides users through booting Windows from a Thunderbolt SSD."'

OUT=""
RC=0

# --- Strumenti ---------------------------------------------------------------

fail() { echo "     $*"; exit 1; }
run() { set +e; OUT="$("$@" 2>&1)"; RC=$?; set -e; }
assert_rc() { [ "$RC" -eq "$1" ] || fail "codice di uscita $RC, atteso $1. Output: $OUT"; }
assert_out() { case "$OUT" in *"$1"*) ;; *) fail "l'output non contiene '$1'. Output: $OUT" ;; esac; }
repeat() { local i s=""; for ((i = 0; i < $2; i++)); do s+="$1"; done; printf '%s' "$s"; }
tree_sum() { find . -type f -print0 | sort -z | xargs -0 sha256sum; }

# write_skill_md <cartella> <righe del frontmatter...>: license viene aggiunta sempre
write_skill_md() {
  local d="$1"; shift
  { echo '---'; printf '%s\n' "$@"; echo 'license: CC-BY-4.0'; echo '---'; echo; echo '# Skill'; } \
    > "$d/$SKILL_REL/SKILL.md"
}

make_fixture() {
  local d="$1" f
  mkdir -p "$d/tools" "$d/docs" "$d/$SKILL_REL/references"
  cp "$SCRIPT" "$d/tools/build-skill.sh" 2>/dev/null || true
  for f in "${DOCS[@]}"; do printf '# %s\n\nTesto di prova.\n' "$f" > "$d/$f"; done
  printf '\n### 7.2 Titolo\n\nTesto.\n' >> "$d/docs/guide.md"
  printf '\n### 7.2 Titolo\n\nTesto.\n' >> "$d/docs/guide.it.md"
  write_skill_md "$d" "$NAME_OK" "$DESC_OK"
  printf '# Triage\n\nSee guide §7.2.\n' > "$d/$TRIAGE"
}

# --- Copia ------------------------------------------------------------------

test_sync_crea_copia() {
  local f
  for f in "${DOCS[@]}"; do cmp -s "$f" "$COPY_REL/$f" || fail "copia di $f assente o diversa"; done
}

test_sync_non_cancella_se_manca_un_originale() {
  # se un originale manca, la copia esistente resta intatta
  local before
  before="$(cd "$COPY_REL" && find . -type f -print0 | sort -z | xargs -0 sha256sum)"
  rm docs/how-it-works.md
  run $B; assert_rc 1; assert_out "how-it-works.md"
  [ "$before" = "$(cd "$COPY_REL" && find . -type f -print0 | sort -z | xargs -0 sha256sum)" ] \
    || fail "la copia e' stata modificata"
}

test_sync_toglie_file_in_piu() {
  echo x > "$COPY_REL/docs/vecchio.md"
  run $B; assert_rc 0
  [ ! -e "$COPY_REL/docs/vecchio.md" ] || fail "vecchio.md non e' stato tolto"
}

# --- Controllo --------------------------------------------------------------

test_check_ok() { run $B --check; assert_rc 0; assert_out "Controllo superato."; }

test_check_non_scrive() {
  local before after
  before="$(tree_sum)"; run $B --check; after="$(tree_sum)"
  [ "$before" = "$after" ] || fail "--check ha modificato dei file"
}

test_check_copia_diversa() { echo x >> "$COPY_REL/docs/guide.md"; run $B --check; assert_rc 1; assert_out "docs/guide.md"; }
test_check_copia_mancante() { rm "$COPY_REL/README.it.md"; run $B --check; assert_rc 1; assert_out "README.it.md"; }
test_check_file_in_piu() { echo x > "$COPY_REL/docs/vecchio.md"; run $B --check; assert_rc 1; assert_out "vecchio.md"; }

test_check_nome_non_valido() { write_skill_md . 'name: Windows_TB' "$DESC_OK"; run $B --check; assert_rc 1; assert_out "name"; }
test_check_nome_diverso_da_cartella() { write_skill_md . 'name: altro-nome' "$DESC_OK"; run $B --check; assert_rc 1; assert_out "cartella"; }
test_check_nome_riservato() { write_skill_md . 'name: claude-tb' "$DESC_OK"; run $B --check; assert_rc 1; assert_out "riservat"; }
test_check_campo_non_standard() { write_skill_md . "$NAME_OK" "$DESC_OK" 'allowed-tools: Bash'; run $B --check; assert_rc 1; assert_out "allowed-tools"; }

test_check_descrizione_1024() {
  # caratteri accentati: si contano i caratteri, non i byte
  write_skill_md . "$NAME_OK" "description: \"$(repeat 'è' 1024)\""
  run $B --check; assert_rc 0
  write_skill_md . "$NAME_OK" "description: \"$(repeat 'è' 1025)\""
  run $B --check; assert_rc 1; assert_out "1024"
}

test_check_backslash_tra_virgolette() {
  # tra virgolette doppie \ apre una sequenza di escape YAML: C:\Repair\ e' un errore
  write_skill_md . "$NAME_OK" 'description: "Use when the scripts in C:\Repair\ fail."'
  run $B --check; assert_rc 1; assert_out "description"
}

test_check_descrizione_xml() { write_skill_md . "$NAME_OK" 'description: "Use <b>this</b> skill."'; run $B --check; assert_rc 1; }

test_check_descrizione_due_punti() {
  write_skill_md . "$NAME_OK" 'description: Guides users: boot from Thunderbolt.'
  run $B --check; assert_rc 1
  write_skill_md . "$NAME_OK" 'description: "Guides users: boot from Thunderbolt."'
  run $B --check; assert_rc 0
}

test_check_sezione_inesistente() { printf 'See guide §9.99.\n' >> "$TRIAGE"; run $B --check; assert_rc 1; assert_out "9.99"; }

test_check_citazione_senza_prefisso() {
  # in "guide §7.2, §9.99" anche la seconda citazione va controllata
  printf 'See guide §7.2, §9.99.\n' >> "$TRIAGE"
  run $B --check; assert_rc 1; assert_out "9.99"
}

test_check_file_estraneo_nella_skill() {
  # finirebbe nello zip
  echo x > "$SKILL_REL/appunti.txt"
  run $B --check; assert_rc 1; assert_out "appunti.txt"
}

test_check_sezione_in_guida_lunga() {
  # titolo all'inizio di un file lungo: la ricerca non deve fallire per SIGPIPE
  local i
  for ((i = 0; i < 50000; i++)); do echo "Riga di testo numero $i della guida."; done >> docs/guide.md
  run $B; assert_rc 0
  run $B --check; assert_rc 0
}

test_check_citazioni_solo_file_scritti_a_mano() {
  # le citazioni dentro la copia della guida non si controllano
  printf 'See guide §9.99.\n' >> README.md
  run $B; assert_rc 0
  run $B --check; assert_rc 0
}

test_check_sezione_solo_inglese() {
  sed -i '/^### 7.2 /d' docs/guide.it.md
  run $B; assert_rc 0
  run $B --check; assert_rc 1; assert_out "guide.it.md"
}

test_check_guid() {
  printf '{%s-%s-%s-%s-%s}\n' 12345678 1234 1234 1234 123456789abc >> "$TRIAGE"
  run $B --check; assert_rc 1; assert_out "GUID"
}

test_check_chiave_48() {
  printf '%s-%s-%s-%s-%s-%s-%s-%s\n' 111111 222222 333333 444444 555555 666666 777777 888888 >> "$TRIAGE"
  run $B --check; assert_rc 1; assert_out "chiave"
}

test_check_crlf() {
  local f
  for f in "${DOCS[@]}" "$SKILL_REL/SKILL.md" "$TRIAGE"; do sed -i 's/$/\r/' "$f"; done
  run $B; assert_rc 0
  run $B --check; assert_rc 0
}

test_avvio_da_altra_cartella() {
  local abs
  (cd tools && ./build-skill.sh --check > /dev/null) || fail "lanciato da tools/"
  abs="$(pwd)/tools/build-skill.sh"
  (cd / && "$abs" --check > /dev/null) || fail "lanciato da /"
}

# --- Zip --------------------------------------------------------------------

test_zip_struttura() {
  local names
  run $B --zip; assert_rc 0
  [ -f dist/windows-tb-boot.zip ] || fail "dist/windows-tb-boot.zip assente"
  names="$("${PYTHON:-python3}" -c 'import sys, zipfile; print("\n".join(zipfile.ZipFile(sys.argv[1]).namelist()))' dist/windows-tb-boot.zip)"
  grep -qx 'windows-tb-boot/SKILL.md' <<< "$names" || fail "manca windows-tb-boot/SKILL.md: $names"
  ! grep -v '^windows-tb-boot/' <<< "$names" || fail "voci fuori da windows-tb-boot/"
}

test_zip_rifiuta_se_check_fallisce() {
  write_skill_md . 'name: Windows_TB' "$DESC_OK"
  run $B --zip; assert_rc 1
  [ ! -e dist/windows-tb-boot.zip ] || fail "zip creato nonostante il controllo fallito"
}

test_zip_senza_python() { run env PYTHON=/inesistente $B --zip; assert_rc 1; assert_out "Comprimi"; }

# --- Opzioni ----------------------------------------------------------------

test_opzione_sconosciuta() { run $B --boh; assert_rc 1; assert_out "Uso:"; }

# --- Esecuzione -------------------------------------------------------------

passed=0
failed=0
for name in $(declare -F | awk '{print $3}' | grep '^test_'); do
  D="$TMP_ROOT/$name"
  make_fixture "$D"
  if ( cd "$D" && { $B > /dev/null 2>&1 || fail "sincronizzazione iniziale fallita"; } && "$name" ); then
    echo "ok   ${name#test_}"; passed=$((passed + 1))
  else
    echo "FAIL ${name#test_}"; failed=$((failed + 1))
  fi
done
echo
echo "Superati: $passed, falliti: $failed"
[ "$failed" -eq 0 ]
