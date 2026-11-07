#!/usr/bin/env bash
# build-skill.sh — copia della guida dentro la skill per agenti AI.
#
# Una skill non puo' leggere file fuori dalla propria cartella, quindi la
# skill .claude/skills/windows-tb-boot/ contiene una copia del README e di
# parte di docs/ in references/repo/. Questo script la tiene allineata agli
# originali, la controlla e crea lo zip da caricare su claude.ai.
#
# Uso:  tools/build-skill.sh           aggiorna la copia
#       tools/build-skill.sh --check   sola lettura: copia, frontmatter,
#                                      sezioni citate, identificativi
#       tools/build-skill.sh --zip     --check, poi dist/windows-tb-boot.zip
#
# Codice di uscita: 0 tutto a posto, 1 errore.
# Variabile PYTHON: interprete per --zip (predefinito: python3, poi python).

set -euo pipefail
export LC_ALL=C.UTF-8

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_NAME=windows-tb-boot
SKILL_DIR="$ROOT/.claude/skills/$SKILL_NAME"
COPY_DIR="$SKILL_DIR/references/repo"
DOCS=(README.md README.it.md
      docs/guide.md docs/guide.it.md
      docs/quick-recovery.md docs/quick-recovery.it.md
      docs/troubleshooting.md docs/troubleshooting.it.md
      docs/how-it-works.md docs/how-it-works.it.md)

PROBLEMS=0

usage() {
  cat <<'EOF'
Uso: tools/build-skill.sh [--check | --zip | --help]
  senza opzioni  aggiorna la copia della guida in references/repo/
  --check        sola lettura: copia, frontmatter, sezioni citate, identificativi
  --zip          esegue --check, poi crea dist/windows-tb-boot.zip
EOF
}

problem() { echo "ERRORE: $*"; PROBLEMS=$((PROBLEMS + 1)); }
rel() { printf '%s' "${1#"$ROOT"/}"; }

is_listed() {
  local f
  for f in "${DOCS[@]}"; do [ "$f" = "$1" ] && return 0; done
  return 1
}

# --- Copia ------------------------------------------------------------------

sync_copy() {
  local f missing=0
  if [ "$COPY_DIR" != "$ROOT/.claude/skills/windows-tb-boot/references/repo" ]; then
    echo "ERRORE: percorso della copia inatteso: $COPY_DIR"
    exit 1
  fi
  # Prima di cancellare la copia: tutti gli originali devono esistere
  for f in "${DOCS[@]}"; do
    if [ ! -f "$ROOT/$f" ]; then
      echo "ERRORE: originale mancante: $f"
      missing=1
    fi
  done
  if [ "$missing" -ne 0 ]; then
    echo "Copia non aggiornata: quella esistente resta com'e'."
    exit 1
  fi
  rm -rf "$COPY_DIR"
  for f in "${DOCS[@]}"; do
    mkdir -p "$(dirname "$COPY_DIR/$f")"
    cp "$ROOT/$f" "$COPY_DIR/$f"
  done
  echo "Copia aggiornata: ${#DOCS[@]} documenti in $(rel "$COPY_DIR")/"
}

# --- Controlli --------------------------------------------------------------

check_copy() {
  local f r
  for f in "${DOCS[@]}"; do
    if [ ! -f "$COPY_DIR/$f" ]; then
      problem "copia mancante: $f (lancia tools/build-skill.sh)"
    elif ! cmp -s "$ROOT/$f" "$COPY_DIR/$f"; then
      problem "copia diversa dall'originale: $f (lancia tools/build-skill.sh)"
    fi
  done
  [ -d "$COPY_DIR" ] || return 0
  while IFS= read -r -d '' f; do
    r="${f#"$COPY_DIR"/}"
    is_listed "$r" || problem "file in piu' nella copia: $r"
  done < <(find "$COPY_DIR" -type f -print0)
}

# Toglie le virgolette doppie da un valore YAML su una riga e ne controlla la
# forma. Risultato in UNQUOTED. Senza virgolette, ': ' e ' #' rendono la riga
# YAML non valida, e claude.ai rifiuta il caricamento.
UNQUOTED=""
check_yaml_value() {
  local key="$1" value="$2" inner
  if [[ $value == \"* ]]; then
    inner="${value#\"}"
    if [[ $inner != *\" ]]; then
      problem "SKILL.md: $key: virgolette doppie non chiuse"
      UNQUOTED="$inner"; return
    fi
    inner="${inner%\"}"
    [[ $inner == *\"* ]] && problem "SKILL.md: $key: virgolette doppie dentro il valore"
    [[ $inner == *\\* ]] && problem "SKILL.md: $key: \\ tra virgolette doppie apre una sequenza di escape YAML: toglilo o usa /"
    UNQUOTED="$inner"
  else
    if [[ $value == *": "* || $value == *" #"* || $value == *: ]]; then
      problem "SKILL.md: $key: valore con ': ' o ' #' senza virgolette, YAML non valido: mettilo tra virgolette doppie"
    elif [[ $value =~ ^[\'\[\{\&\*\!\|\>\%\@\`] ]]; then
      problem "SKILL.md: $key: il valore inizia con un carattere speciale YAML: mettilo tra virgolette doppie"
    fi
    UNQUOTED="$value"
  fi
}

check_frontmatter() {
  local skill_md="$SKILL_DIR/SKILL.md" lines=() line key i closed=0
  local name="" desc="" have_name=0 have_desc=0
  if [ ! -f "$skill_md" ]; then
    problem "SKILL.md mancante: $(rel "$skill_md")"
    return
  fi
  mapfile -t lines < <(tr -d '\r' < "$skill_md")
  if [ "${lines[0]:-}" != "---" ]; then
    problem "SKILL.md: il frontmatter deve iniziare con --- alla prima riga"
    return
  fi
  for ((i = 1; i < ${#lines[@]}; i++)); do
    line="${lines[i]}"
    if [ "$line" = "---" ]; then closed=1; break; fi
    [ -z "$line" ] && continue
    if [[ ! $line =~ ^([A-Za-z0-9_-]+):[[:space:]]*(.*)$ ]]; then
      problem "SKILL.md: riga del frontmatter non valida, serve 'chiave: valore' su una riga: $line"
      continue
    fi
    key="${BASH_REMATCH[1]}"
    check_yaml_value "$key" "${BASH_REMATCH[2]}"
    case "$key" in
      name) name="$UNQUOTED"; have_name=1 ;;
      description) desc="$UNQUOTED"; have_desc=1 ;;
      license) ;;
      *) problem "SKILL.md: campo non standard nel frontmatter: $key (ammessi solo name, description, license)" ;;
    esac
  done
  [ "$closed" -eq 1 ] || problem "SKILL.md: frontmatter senza --- di chiusura"

  if [ "$have_name" -eq 0 ] || [ -z "$name" ]; then
    problem "SKILL.md: name mancante"
  else
    [[ $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] \
      || problem "SKILL.md: name non valido: $name (solo minuscole, cifre e trattini singoli)"
    [ "${#name}" -le 64 ] || problem "SKILL.md: name troppo lungo: ${#name} caratteri (massimo 64)"
    [ "$name" = "$SKILL_NAME" ] \
      || problem "SKILL.md: name ($name) diverso dal nome della cartella ($SKILL_NAME)"
    [[ $name == *claude* || $name == *anthropic* ]] \
      && problem "SKILL.md: name contiene una parola riservata su claude.ai (claude, anthropic)"
  fi

  if [ "$have_desc" -eq 0 ] || [ -z "$desc" ]; then
    problem "SKILL.md: description mancante"
  else
    [ "${#desc}" -le 1024 ] || problem "SKILL.md: description troppo lunga: ${#desc} caratteri (massimo 1024)"
    [[ $desc == *[\<\>]* ]] && problem "SKILL.md: description contiene < o >, non ammessi su claude.ai"
  fi
  return 0
}

# Ogni §N.N nei file scritti a mano, anche senza "guide" davanti (come in
# "guide §6.2, §6.3"), deve essere un titolo della guida, in inglese e in
# italiano.
check_citations() {
  local f sec g
  while IFS= read -r -d '' f; do
    while IFS= read -r sec; do
      for g in "$COPY_DIR/docs/guide.md" "$COPY_DIR/docs/guide.it.md"; do
        [ -f "$g" ] || continue
        # grep legge il file da solo: con tr | grep -q, e pipefail, tr riceve
        # SIGPIPE sui file lunghi e il titolo risulta mancante. Il \r dei file
        # CRLF sta a fine riga, fuori dallo schema.
        grep -qE "^#{2,4} ${sec//./\\.} " "$g" \
          || problem "${f#"$SKILL_DIR"/}: guide §$sec non esiste come titolo in ${g#"$COPY_DIR"/}"
      done
    done < <(tr -d '\r' < "$f" | grep -oE '§[0-9]+(\.[0-9]+)*' | sed 's/^§//' | sort -u)
  done < <(find "$SKILL_DIR" -path "$COPY_DIR" -prune -o -type f -name '*.md' -print0)
  return 0
}

# Nella skill ci sono solo SKILL.md, references/*.md e la copia: ogni altro
# file finirebbe nello zip.
check_stray_files() {
  local f r
  while IFS= read -r -d '' f; do
    r="${f#"$SKILL_DIR"/}"
    case "$r" in
      SKILL.md) ;;
      references/*/*) problem "file estraneo nella skill (finirebbe nello zip): $r" ;;
      references/*.md) ;;
      *) problem "file estraneo nella skill (finirebbe nello zip): $r" ;;
    esac
  done < <(find "$SKILL_DIR" -path "$COPY_DIR" -prune -o -type f -print0)
  return 0
}

# Mostra solo file e riga, mai il contenuto trovato.
check_identifiers() {
  local hit
  while IFS= read -r hit; do
    [ -n "$hit" ] && problem "possibile GUID (identificativo) in $hit"
  done < <(grep -rnIE '\{[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}\}' "$SKILL_DIR" \
             | cut -d: -f1,2 | sed "s|^$SKILL_DIR/||" || true)
  while IFS= read -r hit; do
    [ -n "$hit" ] && problem "possibile chiave di ripristino BitLocker in $hit"
  done < <(grep -rnIE '[0-9]{6}(-[0-9]{6}){7}|[0-9]{48}' "$SKILL_DIR" \
             | cut -d: -f1,2 | sed "s|^$SKILL_DIR/||" || true)
  return 0
}

run_checks() {
  check_copy
  check_frontmatter
  check_citations
  check_stray_files
  check_identifiers
  if [ "$PROBLEMS" -eq 0 ]; then
    echo "Controllo superato."
  else
    echo "Controllo fallito: $PROBLEMS problemi."
    return 1
  fi
}

# --- Zip --------------------------------------------------------------------

make_zip() {
  local py="${PYTHON:-}" out="$ROOT/dist/$SKILL_NAME.zip"
  [ -n "$py" ] || py="$(command -v python3 || command -v python || true)"
  if [ -z "$py" ] || ! "$py" -c 'import zipfile' 2> /dev/null; then
    echo "ERRORE: Python non trovato (python3 o python): serve per creare lo zip."
    echo "In alternativa, in Esplora file: tasto destro sulla cartella .claude\\skills\\$SKILL_NAME,"
    echo "poi Comprimi in file ZIP."
    exit 1
  fi
  mkdir -p "$ROOT/dist"
  rm -f "$out"
  (cd "$(dirname "$SKILL_DIR")" && "$py" -m zipfile -c "$out" "$SKILL_NAME")
  echo "Zip creato: $(rel "$out")"
}

# --- Avvio ------------------------------------------------------------------

if [ $# -gt 1 ]; then
  echo "ERRORE: una sola opzione per volta."
  usage
  exit 1
fi

case "${1:-}" in
  "") sync_copy ;;
  --check) run_checks ;;
  --zip) run_checks || exit 1; make_zip ;;
  -h | --help) usage ;;
  *) echo "ERRORE: opzione sconosciuta: $1"; usage; exit 1 ;;
esac
