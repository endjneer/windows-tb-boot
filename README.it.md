**🌐 Lingua:** [English](README.md) · **Italiano**

# Windows 11 da SSD esterno Thunderbolt su notebook Dell

Guida e script per installare e **avviare nativamente** Windows 11 da un SSD NVMe montato in un box Thunderbolt, su un notebook Dell, **senza modificare il disco interno**.

> ⚠️ **Procedura non supportata né da Dell né da Microsoft.** Prevede la modifica di un'impostazione nascosta del BIOS e del registro di un'installazione di Windows. Leggi la sezione [Avvertenze](#avvertenze) prima di iniziare.

> 🚑 **Emergenza?** Windows non parte dopo un aggiornamento, oppure l'SSD è sparito dal menu F12: **[docs/quick-recovery.it.md](docs/quick-recovery.it.md)**, i passi minimi in una pagina.

> 🤖 **Assistente AI.** Una skill per Claude Code e altri agenti AI ti guida passo passo e legge con te l'output dei comandi: per installarla vedi [Assistente AI](#assistente-ai).

---

## Assistente AI

La skill per agenti AI `windows-tb-boot` ti accompagna passo passo nella procedura e nella diagnosi: capisce a che punto sei, ti porta alla sezione giusta della guida e legge con te l'output dei comandi. È pensata per qualunque notebook con un SSD in un box Thunderbolt o USB4, ma la procedura è verificata solo sull'hardware descritto in [Ambiente di test](#ambiente-di-test).

**Installala in un modo solo**, quello dell'agente che usi: con il clone aperto e il plugin installato, Claude Code mostra la skill due volte.

### Claude Code

In Claude Code scrivi questi due comandi, uno alla volta:

```
/plugin marketplace add endjneer/windows-tb-boot
```

```
/plugin install windows-tb-boot@windows-tb-boot
```

Se apri Claude Code in un clone di questo repository non devi installare niente: la skill è già in `.claude/skills/windows-tb-boot/`.

### claude.ai

1. Crea lo zip. In un terminale bash (Linux, oppure Git Bash su Windows), nella cartella del repository:

   ```
   bash tools/build-skill.sh --zip
   ```

   Il file è `dist/windows-tb-boot.zip`. Senza bash: in Esplora file, clic destro sulla cartella `.claude\skills\windows-tb-boot` e *Comprimi in file ZIP*.
2. Su claude.ai attiva l'esecuzione di codice e carica lo zip nelle impostazioni delle skill.

### Codex, Gemini CLI

Copia la cartella della skill in `~/.agents/skills/`. In un terminale bash, nella cartella del repository:

```
mkdir -p ~/.agents/skills && cp -r .claude/skills/windows-tb-boot ~/.agents/skills/
```

Su Windows puoi copiare con Esplora file la cartella `.claude\skills\windows-tb-boot` in `%USERPROFILE%\.agents\skills\`.

### Usarla in sicurezza

- L'agente non sostituisce la guida: la segue. Da solo esegue solo comandi in sola lettura. I comandi che modificano BIOS, registro, dischi o BitLocker li lanci tu, dopo che l'agente ti ha spiegato cosa cambiano.
- Non usare modalità che approvano i comandi in automatico.
- Non scrivere nella chat chiavi di ripristino, PIN, password, numeri di serie o il Service Tag, e coprili nelle foto dello schermo.

---

## Il problema in breve

Su questo notebook Windows si **installa** senza problemi su un SSD esterno Thunderbolt, ma poi **non si avvia**. Gli ostacoli sono due, indipendenti fra loro:

1. **Il firmware non vede i dischi Thunderbolt prima del boot.** L'opzione che lo permette (`Enable Thunderbolt Boot Support`) esiste nel firmware, ma il menu del BIOS non la mostra. Si attiva da Linux attraverso l'interfaccia `dell-wmi-sysman` del kernel, oppure dall'ambiente di ripristino di Windows con l'interfaccia WMI del BIOS.
2. **Windows perde il disco nel passaggio dal firmware al kernel** e si blocca con la schermata blu `INACCESSIBLE_BOOT_DEVICE` (0x7B). Il motivo è che i driver USB4 che gestiscono il tunnel Thunderbolt (`Usb4HostRouter` e `Usb4DeviceRouter`) vengono caricati solo dopo l'avvio. La soluzione è impostarli come driver di avvio nel registro dell'installazione esterna.

Due tipi di aggiornamento possono annullare queste correzioni, e si riparano entrambi dall'ambiente di ripristino di Windows, senza Ubuntu:
- **gli aggiornamenti di Windows** riportano i driver USB4 a `Start = 3`, e Windows non parte più (Fase 6 della guida);
- **gli aggiornamenti del BIOS**, o un azzeramento delle impostazioni, possono riportare `ThunderboltBoot` a `Disabled`, e l'SSD sparisce dal menu F12 (Fase 7). È successo il 30/10/2026: il resoconto è in [docs/incident-2026-10-30.it.md](docs/incident-2026-10-30.it.md).

La spiegazione tecnica completa è in [docs/how-it-works.it.md](docs/how-it-works.it.md).

---

## Stato delle verifiche

| Passaggio | Stato |
|---|---|
| Attivazione di `ThunderboltBoot` da Linux; SSD visibile nel menu F12 e nel File Explorer del BIOS | ✅ verificato |
| Il firmware avvia il boot manager di Windows presente sull'SSD | ✅ verificato |
| Senza correzioni: schermata blu `INACCESSIBLE_BOOT_DEVICE` | ✅ osservato |
| Solo `BootDriverFlags = 0x14`: ancora `INACCESSIBLE_BOOT_DEVICE` | ✅ osservato |
| Driver USB4 caricati all'avvio (`Start = 0`) insieme a `BootDriverFlags`: il Setup di Windows riparte dall'SSD | ✅ verificato |
| Completamento del Setup e configurazione iniziale offline, compresi i riavvii del Setup | ✅ verificato |
| Ordine di avvio ripristinato con `bcdedit` (sistema interno di nuovo predefinito) | ✅ verificato |
| Ordine di avvio stabile nei riavvii successivi, dopo l'eliminazione della voce manuale doppia | ⏳ da verificare |
| Ordine di avvio dopo un aggiornamento di Windows | ⚠️ la voce esterna torna al primo posto: si riordina con `bcdedit` (Fase 6.4) |
| Avvio dall'SSD dopo la configurazione iniziale (F12 → *Windows SSD esterno*) | ✅ verificato |
| Disco interno nascosto al Windows esterno (blocco del driver Intel VMD) | ✅ verificato |
| Tenuta della correzione dopo gli aggiornamenti di Windows | ❌ non regge: due aggiornamenti (15 e 16 ottobre) hanno riportato i driver USB4 a `Start = 3`, durante la fase di installazione del riavvio. Non si può quindi correggere prima di riavviare |
| `BootFlags = 0x14` sui servizi dei driver USB4, per avviare con `Start = 3` | ❌ non funziona: con `Start = 3` Windows non parte e va nel ripristino automatico (16 ottobre) |
| Servizio `Usb4BootGuard`, che rimette `Start = 0` mentre Windows è acceso (guida, Fase 5.9) | ⏳ da verificare con un aggiornamento reale. Sul sistema in uso, `-SelfTest` superato (16 ottobre): `Start` riportato a 3 torna a 0 in 2–25 ms, grazie alla notifica di Windows |
| Riparazione dall'ambiente di ripristino di Windows con i comandi manuali, disco cifrato (Fase 6) | ✅ verificato |
| Script `windows/repair-usb4-boot.bat`, con Windows avviato | ✅ verificato, nella versione precedente a quella del 30/10 |
| Script `windows/repair-usb4-boot.bat`, dall'ambiente di ripristino | ✅ verificato anche il 30/10 (disco cifrato, messaggi in italiano), nella versione precedente a quella attuale |
| Versioni attuali di `repair-usb4-boot.bat /check` e `thunderbolt-boot-on.vbs /status`, con Windows avviato | ✅ verificato il 30/10, con e senza diritti di amministratore. Senza, `ThunderboltBoot` non si legge (accesso negato, come previsto) |
| Versioni attuali dei due script dall'ambiente di ripristino (`/check`, `/status`, modalità normale) | ✅ verificato il 30/10, disco cifrato, con i valori già corretti: nessuna scrittura |
| Correzione vera e propria con le versioni attuali (valori del registro, attivazione di `ThunderboltBoot`) | ⏳ da verificare: si prova solo quando serve davvero |
| Permessi di scrittura su `C:\Repair` limitati agli amministratori con `icacls` (Fase 5.1) | ✅ verificato il 7/11: cartella e script modificabili solo da SYSTEM e Administrators, `/check` funziona senza diritti di amministratore |
| Lettura e scrittura di `ThunderboltBoot` dall'ambiente di ripristino, con WMI (`wmic` e VBScript) | ✅ verificato il 30/10, con il BIOS aggiornato |
| Attivazione di `ThunderboltBoot` dal Windows esterno avviato | ⏳ da verificare |
| Ambiente di ripristino avviato in modalità USB (cavo USB-C → USB-A su una porta USB-A) | ✅ verificato il 30/10 |
| Windows avviato in modalità USB | ❌ non parte: `INACCESSIBLE_BOOT_DEVICE` (30/10); causa non chiarita |
| `ThunderboltBoot` dopo un aggiornamento del BIOS | ⚠️ tornato `Disabled` (30/10): riparazione nella Fase 7 |
| BitLocker dopo l'aggiornamento del BIOS | ⚠️ protezione sospesa e chiave di ripristino chiesta (30/10): va riattivata (Fase 5.6.6) |
| Riavvio con il PIN dopo la riattivazione della protezione | ⏳ da verificare |
| Blocco del software Dell che aggiorna il BIOS (Fase 5.10) | ⏳ applicato il 30/10, tenuta da verificare |
| Installazione senza Ubuntu, dalla chiavetta di Windows con Shift+F10 (Fase 1 e punto 3.4) | ⏳ da verificare |
| Cifratura BitLocker TPM + PIN dell'SSD esterno; sblocco con la chiave di ripristino | ✅ verificato |
| Sblocco BitLocker dalla sessione live negli script di riparazione | ⏳ da verificare |
| Sospensione (standby moderno, S0) | ⚠️ 187 cicli dal 5/10 al 10/11, con tre schermate blu (0xEF, 0x154) tra pochi minuti e mezz'ora dopo una ripresa. Il blocco senza schermata blu notato all'inizio è quello del 16/10, che i registri mostrano come un passaggio all'ibernazione (riga successiva). Dati e soluzioni da provare in [docs/troubleshooting.it.md](docs/troubleshooting.it.md) |
| Ibernazione | ❌ bloccata in due tentativi su due (16/10 e 6/11), con lo schermo nero e le ventole accese fino allo spegnimento forzato |
| Dock Thunderbolt 3 collegata insieme al box, su un'altra porta | ⚠️ dal primo collegamento (28/10): un blocco al riconoscimento del monitor della dock (2/11) e quattro schermate blu (3/11 e 10/11), due delle quali a pochi secondi dall'avvio. Causa non chiarita |
| Soluzioni per sospensione, ibernazione e dock (problemi frequenti) | ⏳ da verificare |
| Ambiente di ripristino di Windows avviato dall'SSD Thunderbolt, con accesso alla partizione di Windows | ✅ verificato |
| Ripristino da un punto di ripristino | ⏳ da verificare |
| Ubuntu installato sull'SSD esterno | ⏳ da verificare |
| Skill `windows-tb-boot`: i 10 casi di prova simulati di `evals/` (Claude Sonnet, chat e shell, 2 esecuzioni ciascuno, con e senza la skill) | ✅ superati il 30/10 con la skill; senza, il punteggio medio è 0,34. Eseguiti con `tools/run-evals.py` (`claude -p`, giudice a 3 voti), perché `claude plugin eval` non riusciva ad avviare le sue sessioni nell'ambiente di sviluppo. Conversazioni simulate, non utenti reali |
| Skill `windows-tb-boot` in Claude Code aperto nel clone, nel Windows esterno | ⏳ da verificare |
| Skill `windows-tb-boot` installata come plugin dal marketplace | ⏳ da verificare |
| Skill `windows-tb-boot` caricata su claude.ai | ⏳ da verificare |
| Skill `windows-tb-boot` in Codex o Gemini CLI | ⏳ da verificare |
| Skill `windows-tb-boot` su notebook diversi da quello dei test | ⏳ da verificare: solo diagnosi guidata |

Se completi uno dei passaggi "da verificare", apri una issue o una pull request: è il modo più utile per rendere questa guida affidabile.

---

## Ambiente di test

| Componente | Modello |
|---|---|
| Notebook | Un notebook Dell recente: è stato provato un solo modello, di cui il nome e le versioni del BIOS sono omessi di proposito. `ThunderboltBoot` presente sia nel BIOS dei test iniziali sia dopo l'aggiornamento del 30/10/2026 |
| Controller Thunderbolt del notebook | Intel Thunderbolt 5, connection manager software (USB4) |
| Box esterno | ACASIS TBU405Pro, doppio chip: Intel JHL7440 (Titan Ridge, Thunderbolt 3) + Realtek RTL9210B (USB) |
| SSD | WD_BLACK SN850X 1 TB (NVMe Gen4) |
| Collegamento | Porta Thunderbolt 5 del notebook, cavo Thunderbolt, collegamento a 40 Gb/s (2 × 20 Gb/s) |
| Dock (dal 28/10/2026) | Dock Thunderbolt 3, su una porta Thunderbolt del notebook diversa da quella del box |
| Windows | Windows 11, build 26300 (26H2), supporto creato con Rufus |
| Ambiente Linux | Ubuntu Desktop 26.04.1 LTS in sessione live (kernel 7.0) |
| Impostazioni BIOS invariate | Secure Boot attivo, Microsoft UEFI CA abilitata, Pre-Boot DMA attivo, archiviazione in modalità RAID/RST (Intel VMD) |

**Altri modelli.** Il metodo potrebbe funzionare su altri notebook Dell con controller Thunderbolt 4/5 gestito via USB4, a condizione che il firmware contenga l'attributo nascosto `ThunderboltBoot`. Lo script [`scripts/check-bios.sh`](scripts/check-bios.sh) ti dice in pochi secondi se il tuo modello ce l'ha. Sui notebook di altri produttori la parte sul BIOS non si applica.

---

## Avvertenze

- **PC non tuoi.** Se il notebook non è tuo, chiedi il permesso a chi lo gestisce prima di modificare il BIOS o avviare un altro sistema operativo. Se è impostata una password di amministratore del BIOS, `check-bios.sh` lo segnala e `thunderbolt-boot.sh` si ferma: non tentare di aggirarla.
- **BitLocker sul disco interno.** Una modifica alle impostazioni del BIOS può, a seconda della configurazione, far chiedere la recovery key al Windows interno. **Assicurati di poterla ottenere prima di iniziare.**
- **Gli aggiornamenti di Windows possono impedire l'avvio.** È successo nei test: un aggiornamento ha riportato i driver USB4 a `Start = 3`, e il Windows esterno è andato in `INACCESSIBLE_BOOT_DEVICE` chiedendo la chiave di ripristino di BitLocker. La riparazione si fa dall'ambiente di ripristino di Windows (Fase 6 della guida). Prima di aggiornare, tieni a portata di mano la chiave di ripristino dell'SSD esterno. Il servizio `Usb4BootGuard` (Fase 5.9) prova a prevenire il problema, ma non è ancora stato verificato con un aggiornamento reale.
- **Gli aggiornamenti del BIOS possono impedire l'avvio dall'SSD.** È successo il 30/10/2026: un aggiornamento avviato molto probabilmente da Dell SupportAssist, arrivato nel Windows esterno senza essere stato scelto, ha riportato `ThunderboltBoot` a `Disabled` e sospeso la protezione BitLocker. La riparazione è nella Fase 7, la prevenzione nella Fase 5.10. Il BIOS è unico e condiviso con il sistema interno: se il PC è gestito da qualcun altro, gli aggiornamenti li decide chi lo gestisce.
- **Sicurezza.** Con `ThunderboltBoot` attivo, il firmware autorizza da solo, all'accensione, i dispositivi collegati alla porta Thunderbolt, prima che partano le protezioni del sistema operativo. Un dispositivo malevolo collegato all'avvio può quindi tentare un attacco DMA: su altri modelli Dell la stessa funzione, attiva per impostazione predefinita, è stata classificata come vulnerabilità ([CVE-2019-18579](https://nvd.nist.gov/vuln/detail/CVE-2019-18579)). Lascia attivi Secure Boot e `Pre-Boot DMA Support` (`PreBootDma`, di cui `check-bios.sh` mostra il valore). Quanto `Pre-Boot DMA Support` protegga davvero su questo modello non è stato verificato.
- **Il sistema interno può vedere l'SSD esterno.** Se il box è collegato all'accensione, viene autorizzato anche quando avvii il sistema interno, che vedrebbe l'SSD insieme a tutti i programmi che ci girano. Scollega il box prima di avviare il sistema interno.
- **Opzione non documentata.** `ThunderboltBoot` è nascosta dal menu del BIOS di questo modello e potrebbe non essere stata validata da Dell. Si disattiva con `scripts/thunderbolt-boot.sh --disable` dalla sessione live di Ubuntu: la modifica vale dal riavvio successivo, e da quel momento l'SSD esterno non è più avviabile. Un aggiornamento del BIOS l'ha riportata al valore predefinito il 30/10/2026 (Fase 7).
- **Nessuna garanzia.** Usi questa guida e questi script a tuo rischio. Nessuno script scrive sul disco interno, ma nessuno controlla da solo che il disco scelto sia quello esterno: la protezione dipende dalla modalità RAID/RST del BIOS, che nasconde il disco interno all'installer di Windows e, con `modprobe.blacklist=vmd`, alla sessione live, e dalla tua attenzione. I punti delicati sono:
  - `diskpart clean` nella Fase 2, che cancella tutto il disco selezionato;
  - `patch-windows-hive.sh` e `restore-hive-backup.sh`, che modificano il registro della partizione indicata: chiedono conferma, e il primo mostra prima il disco e crea una copia di sicurezza;
  - `repair-usb4-boot.bat` nell'ambiente di ripristino, che corregge l'installazione di Windows sull'unità da cui è lanciato o su quella indicata. Con `/check` non modifica nulla;
  - `thunderbolt-boot-on.vbs`, che scrive l'attributo `ThunderboltBoot` nel BIOS. Lanciato da `repair-usb4-boot.bat` chiede prima conferma; lanciato da solo senza `/status` scrive subito, se il valore non è già `Enabled`.

  In modalità AHCI/NVMe il disco interno resta visibile ovunque, e il Setup di Windows potrebbe scrivere i file di avvio sulla sua ESP.

---

## Occorrente

- Il notebook, con la possibilità di entrare nel BIOS (F2) e nel menu di avvio (F12).
- Un box NVMe Thunderbolt 3/4/5 con il suo **cavo Thunderbolt**, e un SSD NVMe da dedicare a Windows: verrà cancellato.
- Un **cavo USB-C → USB-A**, solo per il ripristino: se un aggiornamento del BIOS spegne `ThunderboltBoot`, serve a raggiungere l'ambiente di ripristino di Windows con il box in modalità USB (Fase 7). Vale per un box a doppio chip come quello dei test.
- **Due chiavette USB** da almeno 8 GB: una per l'installazione di Windows, una per la sessione live di Ubuntu. Con una sola chiavetta si può fare, ma dovrai riscriverla fra una fase e l'altra. Ubuntu serve per il percorso verificato; esiste un'alternativa senza Ubuntu, dalla chiavetta di Windows con Shift+F10, non ancora verificata (Fase 1 e punto 3.4 della guida).
- Le immagini ISO di Windows 11 e di Ubuntu Desktop LTS, e [Rufus](https://rufus.ie) per scriverle.
- Una connessione a Internet nella sessione live, per scaricare il repository e installare un pacchetto (`libwin-hivex-perl`).

---

## Procedura

La guida passo passo è in **[docs/guide.it.md](docs/guide.it.md)**. In sintesi:

| Fase | Dove | Cosa |
|---|---|---|
| 0 | Su un PC qualsiasi | Preparazione delle due chiavette |
| 1 | Ubuntu live | Verifica e attivazione di `ThunderboltBoot` |
| 2 | Installer di Windows | Prima fase dell'installazione sull'SSD esterno |
| 3 | Ubuntu live | Correzione del registro dell'installazione esterna |
| 4 | BIOS, poi Windows | Voce di avvio dedicata e completamento del Setup, senza Internet |
| 5 | Windows esterno | Esclusione dei firmware da Windows Update prima di andare online, script di riparazione, ordine di avvio, driver, cifratura, punti di ripristino, servizio `Usb4BootGuard` (5.9), blocco del software Dell che aggiorna il BIOS (5.10) |
| 6 | Ambiente di ripristino di Windows | Riparazione quando un aggiornamento di Windows impedisce l'avvio |
| 7 | Ambiente di ripristino di Windows, box in modalità USB | Riattivazione di `ThunderboltBoot` quando l'SSD sparisce dal menu F12 dopo un aggiornamento o un azzeramento del BIOS |

In caso di problemi consulta [docs/troubleshooting.it.md](docs/troubleshooting.it.md). In emergenza: [docs/quick-recovery.it.md](docs/quick-recovery.it.md).

---

## Struttura del repository

```
.
├── README.md                 Questo documento, in inglese
├── README.it.md              Questo documento, in italiano
├── CLAUDE.md                 Istruzioni e regole di sicurezza per Claude Code
├── LICENSE
├── .gitattributes            Terminatori di riga: script per Windows con CRLF, script bash con LF
├── .claude/skills/windows-tb-boot/ Skill per agenti AI; references/repo/ è una copia generata della guida
├── .claude-plugin/           Il repository come plugin e marketplace di Claude Code
├── docs/                     Ogni documento in inglese (.md) e in italiano (.it.md)
│   ├── guide.it.md           Procedura passo passo
│   ├── quick-recovery.it.md  Ripristino rapido: i passi minimi in emergenza
│   ├── how-it-works.it.md    Spiegazione tecnica
│   ├── troubleshooting.it.md Problemi frequenti e soluzioni
│   ├── incident-2026-10-30.it.md Resoconto dell'aggiornamento del BIOS del 30/10/2026
│   ├── piano-autoinstall.md  Piano di sviluppo della chiavetta di installazione automatica (solo in italiano)
│   └── piano-skill-agenti*.md Piano della skill per agenti AI (solo in italiano)
├── evals/                    Casi di prova della skill, per claude plugin eval
├── tools/
│   ├── build-skill.sh        Aggiorna, controlla e comprime la copia della guida nella skill
│   ├── run-evals.py          Esegue i casi di prova di evals/ con claude -p
│   └── tests/                Test di build-skill.sh
├── scripts/                  Da eseguire nella sessione live di Ubuntu
│   ├── check-bios.sh         Verifica (sola lettura) degli attributi BIOS e del collegamento Thunderbolt
│   ├── thunderbolt-boot.sh   Attiva o disattiva ThunderboltBoot
│   ├── patch-windows-hive.sh Applica la correzione al registro di Windows, con copia di sicurezza
│   └── restore-hive-backup.sh Ripristina la copia di sicurezza del registro
├── registry/                 Le modifiche al registro in formato .reg
│   ├── bootdriverflags.reg
│   └── usb4-boot-start.reg
└── windows/
    ├── repair-usb4-boot.bat  Ripristino: reimposta i driver USB4 e controlla ThunderboltBoot, da WinRE o da Windows; /check in sola lettura
    ├── thunderbolt-boot-on.vbs Legge (/status) e attiva ThunderboltBoot con l'interfaccia WMI del BIOS, anche da WinRE
    ├── show-disk-paths.ps1   Sola lettura: mostra da quale controller dipende ogni disco
    ├── usb4-boot-guard/      Servizio che rimette Start = 0 dopo gli aggiornamenti (non verificato)
    │   ├── Usb4BootGuard.cs  Codice del servizio
    │   └── usb4-boot-guard.ps1 Installa, prova, controlla o rimuove il servizio
    └── tests/                Test Pester del servizio, su un registro di prova
```

Gli script bash stampano i messaggi in italiano. `repair-usb4-boot.bat`, `thunderbolt-boot-on.vbs` e `usb4-boot-guard.ps1` parlano italiano o inglese secondo la lingua di sistema, e la lingua si può forzare con `/it` oppure `/en`.

---

## Come annullare tutto

- **Correzione del registro:** `scripts/restore-hive-backup.sh` ripristina la copia di sicurezza creata dallo script.
- **ThunderboltBoot:** dalla sessione live, `scripts/thunderbolt-boot.sh --disable`.
- **Voce di avvio:** nel BIOS, Boot Configuration → Boot Sequence → DELETE sulla voce creata.
- **Blocco del driver VMD** (nel Windows esterno): `reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /f`, poi in Gestione dispositivi *Azione → Rileva modifiche hardware*. Questo comando toglie l'intera regola, compreso il blocco del software Dell.
- **Blocco del software Dell** (nel Windows esterno, Fase 5.10): togli solo i valori 2 e 3 della regola, con `reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 2 /f` e lo stesso comando con `/v 3`.
- **Servizio `Usb4BootGuard`** (nel Windows esterno): `windows\usb4-boot-guard\usb4-boot-guard.ps1 -Uninstall`, da un PowerShell aperto come amministratore.
- **Installazione di Windows:** basta cancellare o riformattare l'SSD esterno. In modalità RAID/RST il disco interno non viene mai modificato.

---

## Riferimenti

- [Windows 11 on USB4 (ASM2464PD) SSD cannot boot (BSOD Inaccessible Boot Device) from USB4 port](https://egpu.io/forums/thunderbolt-enclosures/windows-11-on-usb4-asm2464pd-ssd-cannot-boot-bsod-inaccessable-boot-device-from-usb4-port/), egpu.io: stesso sintomo su un altro notebook USB4.
- [Why is BSOD: INACCESSIBLE BOOT DEVICE reported if I put the NVMe SSD into a USB enclosure as a boot device?](https://learn.microsoft.com/en-us/answers/questions/5599163/why-is-bsod-inaccessible-boot-device-reported-if-i), Microsoft Q&A: uso di `BootDriverFlags = 0x14`.
- Documentazione del kernel Linux: `Documentation/ABI/testing/sysfs-class-firmware-attributes`, che descrive l'interfaccia `/sys/class/firmware-attributes` usata da `dell-wmi-sysman`.

---

## Contribuire

Le segnalazioni di compatibilità sono la cosa più preziosa: usa il modello di issue "Compatibility report", in italiano o in inglese. Indica modello, versione del BIOS, controller Thunderbolt, box ed esito. **Non pubblicare numeri di serie, Service Tag o altri identificativi della tua macchina.**

---

## Licenza

- Script (compresa `tools/`) e file `.reg`: licenza MIT, vedi [LICENSE](LICENSE).
- Documentazione (`README.md`, `README.it.md`, cartella `docs/`, skill in `.claude/skills/` e casi di prova in `evals/`): [Creative Commons Attribuzione 4.0 Internazionale (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/deed.it).
