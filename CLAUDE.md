# CLAUDE.md

Istruzioni per Claude Code su questo repository.

## Il progetto

Guida e script per avviare Windows 11 da un SSD NVMe in un box Thunderbolt su un notebook Dell, senza modificare il disco interno. Leggi `README.it.md` per il quadro generale e `docs/how-it-works.it.md` per i motivi tecnici. Il lavoro in corso è descritto in `docs/piano-autoinstall.md`.

In breve: il firmware avvia l'SSD solo con l'attributo BIOS nascosto `ThunderboltBoot`. Windows ci arriva solo se i driver `Usb4HostRouter` e `Usb4DeviceRouter` hanno `Start = 0`; altrimenti si blocca con `INACCESSIBLE_BOOT_DEVICE`. Gli aggiornamenti di Windows riportano quei valori a 3: la riparazione è nella Fase 6 della guida. Gli aggiornamenti o gli azzeramenti del BIOS possono riportare `ThunderboltBoot` a `Disabled`, e l'SSD sparisce dal menu F12 (successo il 30/10/2026 con un aggiornamento del BIOS, molto probabilmente per Dell SupportAssist): la riparazione, da WinRE con il box in modalità USB, è nella Fase 7. Il resoconto è in `docs/incident-2026-10-30.it.md`, la versione per le emergenze in `docs/quick-recovery.it.md`.

## Ambiente

- Lavori sul **Windows esterno**, cioè quello sull'SSD Thunderbolt. Sul notebook c'è anche un **disco interno con un altro sistema operativo, da non toccare mai**.
- Il disco interno dovrebbe essere invisibile, perché il driver Intel VMD è bloccato da una regola di sistema. Non dare per scontato che lo sia.
- L'SSD esterno è cifrato con BitLocker.

## Regole di sicurezza (vincolanti)

1. **Non eseguire mai comandi che modificano dischi o partizioni** (`diskpart`, `Clear-Disk`, `Format-Volume`, `Initialize-Disk`, `New-Partition` e simili), neanche per un test.
2. **Non toccare BIOS o firmware.** Niente interfacce WMI Dell in scrittura, niente aggiornamenti firmware, niente comandi che cambiano `ThunderboltBoot` o altri attributi. In particolare **non lanciare mai `windows\thunderbolt-boot-on.vbs` senza `/status`**: scrive nel BIOS.
3. **Non modificare la configurazione di avvio del sistema in uso** (`bcdedit /set`, `bcdboot`) senza una richiesta esplicita.
4. **Non modificare il registro del sistema in uso** (`reg add`, `reg delete`, `Set-ItemProperty` su `HKLM`) senza una richiesta esplicita. In particolare non toccare i servizi `Usb4HostRouter` e `Usb4DeviceRouter`, la chiave `Policies\Microsoft\Windows\DeviceInstall` e le chiavi di BitLocker (`Policies\Microsoft\FVE`). **Non lanciare mai `windows\repair-usb4-boot.bat` in modalità normale**, cioè senza `/check`: scrive il registro e propone di scrivere nel BIOS.
5. **Non toccare BitLocker né il TPM:** niente `manage-bde` in scrittura, niente `Clear-Tpm`.
6. **Le operazioni DISM avvengono solo su copie** in una cartella di lavoro: mai su `C:\`, mai sull'immagine originale della ISO.
7. **Nessun segreto o identificativo nel repository:** password, PIN, chiavi di ripristino, Product Key, Service Tag, numeri di serie, UUID dei dispositivi. Il repository è pubblico: niente nemmeno sul notebook dei test (modello, codice, versioni del BIOS, modello del controller Thunderbolt, ID hardware come `SUBSYS_xxxx1028`, che individua il modello Dell, o i `DEV_` di VMD, controller Thunderbolt, porte radice e disco interno); scrivi "notebook Dell", "il notebook dei test", "il BIOS aggiornato". Prima di ogni commit controlla i file modificati.
8. In caso di dubbio su un comando con effetti sul sistema, **fermati e chiedi**.

È sempre permesso, perché in sola lettura:
- `reg query`, `Get-WindowsImage`, `Get-PnpDevice`, `bcdedit /enum`, `manage-bde -status`, `schtasks /query`, `winget list`, `windows/show-disk-paths.ps1`;
- `windows\repair-usb4-boot.bat /check` e `cscript //nologo windows\thunderbolt-boot-on.vbs /status`;
- la lettura del BIOS con `wmic /namespace:\\root\dcim\sysman\biosattributes path EnumerationAttribute where "AttributeName='ThunderboltBoot'" get AttributeName,CurrentValue`;
- `manage-bde -protectors -get C: -Type TPMAndPIN`. **Mai `-get` senza `-Type`:** stampa la chiave di ripristino.

Gli output di questi comandi contengono identificativi (GUID delle voci di avvio, ID istanza dei dispositivi, numeri `oemNN.inf`, numeri di serie dei volumi): non copiarli nel repository.

## Struttura

- `scripts/`: script bash da eseguire nella sessione live di Ubuntu (BIOS, correzione offline del registro, ripristino).
- `registry/`: le modifiche al registro in formato `.reg` (testate con `hivexregedit --merge`).
- `windows/`: script da eseguire nel Windows esterno o nel suo ambiente di ripristino. `repair-usb4-boot.bat` è il punto d'ingresso per il ripristino (registro e `ThunderboltBoot`, con `/check` in sola lettura); `thunderbolt-boot-on.vbs` legge e attiva `ThunderboltBoot` con l'interfaccia WMI del BIOS; `usb4-boot-guard/` è il servizio che rimette `Start = 0`; `tests/` contiene i test Pester.
- `docs/`: guida, ripristino rapido (`quick-recovery`), spiegazione tecnica, problemi frequenti, resoconto dell'incidente del 30/10/2026 (`incident-2026-10-30`), piano di sviluppo.
- `.gitattributes`: `.bat`, `.cmd`, `.vbs` e `.ps1` sono `-text`, cioè conservati byte per byte con CRLF; `.sh` con LF.
- `autoinstall/`: (in sviluppo) creazione della chiavetta di installazione automatica.
- `.claude/skills/windows-tb-boot/`: la skill per agenti AI, generica per qualunque notebook con un SSD Thunderbolt o USB4 e verificata solo sull'hardware dei test. `SKILL.md` e `references/*.md` sono in inglese. `references/repo/` è una copia generata del README e di parte di `docs/`: non modificarla a mano.
- `.claude-plugin/`: il repository come plugin e marketplace di Claude Code (senza `version`, quindi ogni commit è una versione).
- `evals/`: casi di prova della skill per `claude plugin eval` (`prompt.md` e `graders/`).
- `tools/`: `build-skill.sh`, che aggiorna la copia della guida nella skill, la controlla (`--check`) e crea lo zip (`--zip`), con i suoi test in `tools/tests/`; `run-evals.py`, che esegue i casi di `evals/` con `claude -p`.

## Convenzioni

- **PowerShell:** compatibile con 5.1, `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`, `[CmdletBinding(SupportsShouldProcess)]` per tutto ciò che modifica qualcosa, risorse rilasciate in `try/finally`.
- **Codifica:** file `.ps1` in ASCII oppure UTF-8 con BOM; `.bat`, `.cmd` e `.vbs` solo ASCII (`e'` invece di `è`); `.ps1`, `.bat`, `.cmd` e `.vbs` con terminatori di riga CRLF; `.sh` con LF. Dopo ogni modifica a un `.bat` o a un `.vbs` da Linux, riconvertilo con `sed -i 's/\r*$/\r/' <file>` e controlla con `git ls-files --eol windows/` (atteso `i/crlf w/crlf`).
- **Script per WinRE:** l'ambiente di ripristino non ha PowerShell né `where`; ci sono `reg`, `find`, `wmic`, `cscript`, `notepad`, `manage-bde` e `bcdedit`. Nei `.bat`: niente messaggi dentro blocchi tra parentesi (usa `goto`), niente `|`, `&`, `<`, `>`, `%` e `^` nelle righe `rem` e nei messaggi, `reg query` invece di `sc qc ... | findstr` (output tradotto).
- **Bash:** `set -euo pipefail`, conferma esplicita (`SI`) prima di qualunque scrittura su disco.
- **Lingua:**
  - script bash: commenti e messaggi in italiano;
  - script in `windows/`: commenti in inglese, messaggi bilingui, con la lingua scelta dalla lingua di sistema e forzabile con `/it` o `/en`. `show-disk-paths.ps1`, `usb4-boot-guard/` e `tests/` hanno ancora i commenti in italiano;
  - documentazione bilingue: inglese predefinito (`README.md`, `docs/<nome>.md`) e italiano (`README.it.md`, `docs/<nome>.it.md`), con il selettore di lingua in cima a ogni file. Ogni modifica va fatta in entrambe le lingue, tabella di stato compresa. `docs/piano-autoinstall.md` resta solo in italiano.
- **Dove si lancia un comando:** nella documentazione ogni blocco di comandi indica se va lanciato nel *Prompt dei comandi come amministratore*, in *PowerShell come amministratore*, nel *prompt di WinRE* (cmd, senza PowerShell) o nella *sessione live di Ubuntu*.
- **Verifica:** `Invoke-ScriptAnalyzer -Recurse`, test Pester in `autoinstall/tests` e `windows/tests` (Pester 5 o successivo), `bash -n` e shellcheck sugli script bash. Per la skill: `bash tools/tests/build-skill.test.sh`, `bash tools/build-skill.sh --check`, `claude plugin validate .` e `claude plugin eval . --no-publish --trust-plugin --model sonnet`; dove `plugin eval` non può avviare le sue sessioni, `python3 tools/run-evals.py` esegue gli stessi casi con `claude -p` (`--list` li controlla senza eseguirli).
- **Skill:** dopo ogni modifica a `README.md`, `README.it.md` o ai documenti di `docs/` copiati nella skill (`guide`, `quick-recovery`, `troubleshooting`, `how-it-works`), lancia `bash tools/build-skill.sh`. `bash tools/build-skill.sh --check` deve passare prima di ogni commit. Nella skill le sezioni della guida si citano come `guide §N.N`, così `--check` le controlla.
- **Onestà nella documentazione:** tutto ciò che non è stato provato su hardware reale va indicato come "non verificato", e la tabella di stato nel README va tenuta aggiornata.

## Flusso di lavoro

- Una milestone del piano per volta, su un branch dedicato, con commit piccoli.
- Repository pubblico: `https://github.com/endjneer/windows-tb-boot`. I commit sono a nome `electroendjneer <electroendjneer@users.noreply.github.com>`: mai un'email che rimandi a un account personale. Push e creazione di repository li lancia l'utente.
- Prima di implementare una milestone, riassumi cosa farai e quali comandi eseguirai sul sistema.
- I test sull'hardware (milestone M7) li esegue l'utente: tu prepari la lista di controllo e analizzi i risultati.
