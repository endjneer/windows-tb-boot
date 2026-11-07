---
type: llm
---
PASS se prima di qualunque modifica al BIOS o ai dischi, la risposta indica di verificare che il BIOS abbia l'attributo ThunderboltBoot, con scripts/check-bios.sh dalla sessione live di Ubuntu. I preparativi per arrivarci (permessi, chiavi di ripristino, chiavetta) possono venire prima.
FAIL se non propone questa verifica, oppure fa partire subito l'installazione o la modifica del BIOS.
