# Piano di sviluppo — installazione automatica (`autoinstall/`)

## 1. Obiettivo

Produrre, a partire dalla ISO ufficiale di Windows 11, una **chiavetta di installazione già corretta**. Installando Windows sull'SSD esterno Thunderbolt, deve riprodurre automaticamente il risultato delle Fasi 3–5 della [guida](guide.it.md), senza sessione live di Ubuntu e senza interventi manuali, salvo quelli esclusi di proposito al punto 3.

Risultato atteso, dopo il primo accesso:
- Windows parte dall'SSD via Thunderbolt senza `INACCESSIBLE_BOOT_DEVICE`;
- driver USB4 con `Start = 0` e `BootDriverFlags = 0x14`;
- script di riparazione `repair-usb4-boot.bat` e `thunderbolt-boot-on.vbs` già copiati in `C:\Repair\`;
- driver e firmware esclusi da Windows Update;
- driver Intel VMD bloccato, quindi disco interno invisibile;
- voce di avvio esterna in fondo all'ordine e rinominata "Windows SSD esterno";
- punti di ripristino attivi, con un primo punto creato;
- rete funzionante grazie al driver Wi-Fi integrato nell'immagine.

## 2. Presupposti

- Su questo PC `ThunderboltBoot` è già attivo: lo fa `scripts/thunderbolt-boot.sh`, e resta fuori da questo lavoro. Si può attivare anche da Windows o dal suo ambiente di ripristino, con `windows/thunderbolt-boot-on.vbs` e l'interfaccia WMI del BIOS (§ 9). Un aggiornamento o un azzeramento del BIOS può spegnerlo: è successo il 30/10/2026, e la riparazione è nella Fase 7 della guida.
- La macchina di sviluppo è il Windows esterno, con Windows 11 Pro, PowerShell 5.1 e DISM, tutti inclusi in Windows.
- Facoltativo: Windows ADK, per Windows System Image Manager (validazione di `autounattend.xml`) e `oscdimg` (creazione di ISO).

## 3. Fuori dall'ambito (di proposito)

| Cosa | Perché resta manuale |
|---|---|
| Modifiche al BIOS/firmware | Operazione delicata, si fa una volta sola, e incide anche sul sistema interno |
| Scelta e cancellazione del disco | Una chiavetta che cancella dischi da sola, avviata sul PC sbagliato, fa danni irreparabili |
| BitLocker e PIN | Il PIN è un segreto, e non va scritto in file o script |
| Programmi applicativi (Steam, NVIDIA ecc.) | Fase successiva facoltativa (§ 9) |

## 4. Vincoli di sicurezza (non negoziabili)

1. **Nessuna operazione automatica sui dischi.** `autounattend.xml` non contiene `DiskConfiguration`: il disco si sceglie sempre a mano.
2. **Nessun segreto nel repository:** password, PIN, chiavi di ripristino, codici Product Key.
3. **Nessun identificativo della macchina:** Service Tag, numeri di serie, UUID.
4. **Gli script di build lavorano solo su copie** in una cartella di lavoro. Mai sull'immagine originale, mai sul sistema in uso.
5. **Ogni modifica è idempotente e verificabile:** rilanciare uno script non deve fare danni, e ogni script ha una modalità di verifica.
6. **Pulizia garantita:** hive caricati e immagini montate vanno sempre rilasciati, anche in caso di errore (`try/finally`).

## 5. Architettura

```
autoinstall/
├── README.md                    Istruzioni d'uso
├── build/
│   ├── Build-InstallMedia.ps1   Crea install.wim corretto e i file per la chiavetta
│   ├── Test-InstallImage.ps1    Verifica in sola lettura un install.wim già costruito
│   └── lib/WtbImage.psm1        Funzioni comuni: mount, caricamento hive, logging
├── templates/
│   └── autounattend.xml         Modello del file di risposte (senza segreti, senza dischi)
├── image-scripts/               Copiati DENTRO l'immagine, in Windows\Setup\Scripts\
│   ├── SetupComplete.cmd        Lancia PostInstall.ps1 alla fine del Setup
│   └── PostInstall.ps1          Operazioni della Fase 5 (idempotente, con log)
└── tests/
    └── *.Tests.ps1              Test Pester con mock dei cmdlet DISM
```

**Flusso:**
1. ISO montata → si sceglie l'edizione (Pro) → esportazione del solo indice Pro in un nuovo `install.wim`, convertendo `.esd` in `.wim` se serve.
2. Montaggio del `.wim` → caricamento degli hive offline `SYSTEM` e `SOFTWARE` → scrittura dei valori → rilascio degli hive.
3. Integrazione dei driver di rete con `Add-WindowsDriver -Recurse`. È facoltativa.
4. Copia di `image-scripts/` in `Windows\Setup\Scripts\` dentro l'immagine.
5. Smontaggio con salvataggio → verifica in sola lettura → hash SHA256 → log.
6. Generazione di `autounattend.xml` dal modello.
7. L'utente crea la chiavetta con Rufus (installazione standard, NTFS), sostituisce `sources\install.*` e copia `autounattend.xml` nella radice.

**Perché correggere l'immagine funziona:** nei test, la correzione applicata dopo la copia dei file ma **prima del primo avvio** è rimasta valida anche dopo la configurazione dei dispositivi e quella iniziale. I valori risultavano ancora a `0x0`. Correggere `install.wim` produce lo stesso stato iniziale. Va comunque riverificato nella milestone M7.

## 6. Milestone

Ogni milestone corrisponde a un branch e a una pull request.

### M0 — Preparazione
- [ ] Branch `feature/autoinstall`.
- [x] `.gitattributes` (30/10/2026): `*.bat`, `*.cmd`, `*.vbs` e `*.ps1` `-text`, cioè con CRLF conservato byte per byte; `*.sh text eol=lf`, `*.reg text eol=lf`.
- [ ] Strumenti: PSScriptAnalyzer e Pester 5 (`Install-Module -Scope CurrentUser`), shellcheck per gli script bash.
- [ ] Rendere esplicita in `CLAUDE.md` la convenzione di codifica: `.ps1` in ASCII oppure UTF-8 con BOM.

**Accettazione:** `Invoke-ScriptAnalyzer -Recurse` e `shellcheck scripts/*.sh` passano senza errori.

### M1 — Scheletro di `Build-InstallMedia.ps1`
- [ ] Parametri: `-IsoPath`, `-Edition` (default `"Windows 11 Pro"`), `-WorkDir`, `-OutDir`, `-DriversPath` (facoltativo), `-VmdHardwareId` (facoltativo), `-ListEditions`.
- [ ] `[CmdletBinding(SupportsShouldProcess)]`: con `-WhatIf` mostra le azioni previste senza eseguirle.
- [ ] Controlli iniziali: diritti di amministratore, ISO esistente, almeno 25 GB liberi in `WorkDir`, nessun montaggio DISM residuo (`Get-WindowsImage -Mounted`).
- [ ] Log con data e ora in `OutDir\build.log`.

**Accettazione:** `-ListEditions` elenca gli indici della ISO. `-WhatIf` non modifica nulla.

### M2 — Esportazione e correzione offline del registro
- [ ] `Export-WindowsImage` del solo indice scelto, con compressione `max`.
- [ ] `Mount-WindowsImage` in `WorkDir\mount`.
- [ ] Caricamento degli hive con nomi univoci (`reg load HKLM\WTB_SYSTEM …`, `HKLM\WTB_SOFTWARE …`).
- [ ] Controllo che `Select\Current` sia 1. In caso contrario usare il control set indicato: non presupporre 001.
- [ ] Controllo che esistano le chiavi dei servizi `Usb4HostRouter` e `Usb4DeviceRouter`. Se mancano, errore esplicito: build di Windows non compatibile.
- [ ] Valori in `SYSTEM`:
  - `ControlSet00X\Services\Usb4HostRouter\Start = 0`
  - `ControlSet00X\Services\Usb4DeviceRouter\Start = 0`
  - `ControlSet00X\Control\BootDriverFlags = 0x14`
- [ ] Valori in `SOFTWARE`:
  - `Policies\Microsoft\Windows\WindowsUpdate\ExcludeWUDriversInQualityUpdate = 1`
  - se è indicato `-VmdHardwareId`: `Policies\Microsoft\Windows\DeviceInstall\Restrictions` (`DenyDeviceIDs = 1`, `DenyDeviceIDsRetroactive = 1`, sottochiave `DenyDeviceIDs` con `1 = <ID>`)
  - `Microsoft\Windows NT\CurrentVersion\SystemRestore\SystemRestorePointCreationFrequency = 0`
- [ ] Rilascio degli hive in un blocco `finally`, con `[gc]::Collect()` e alcuni tentativi in caso di "Accesso negato".
- [ ] `Dismount-WindowsImage -Save`. In caso di errore: `-Discard` più `Clear-WindowsCorruptMountPoint`.

**Accettazione:** `Test-InstallImage.ps1` (M2b) riporta tutti i valori come OK. Una seconda esecuzione produce lo stesso risultato. Interrompere lo script a metà non lascia immagini montate né hive caricati.

### M2b — `Test-InstallImage.ps1`
- [ ] Monta l'immagine in sola lettura (`-ReadOnly`), carica gli hive, confronta ogni valore con quello atteso, mostra una tabella OK/NO, rilascia tutto.
- [ ] Codice di uscita diverso da 0 se anche un solo valore non corrisponde.

### M3 — Driver di rete (facoltativo)
- [ ] `-DriversPath` punta a una cartella con i driver **estratti** (file `.inf`). Documentare come estrarre i pacchetti Dell, per esempio `Pacchetto.exe /s /e=C:\Driver\estratti`: le opzioni esatte vanno verificate sul pacchetto.
- [ ] `Add-WindowsDriver -Path <mount> -Driver <cartella> -Recurse`, con l'elenco dei driver aggiunti nel log.

**Accettazione:** `Get-WindowsDriver -Path <mount>` mostra i driver Wi-Fi e Bluetooth.

### M4 — Script di fine installazione
- [ ] `PostInstall.ps1`, idempotente, con log in `C:\ProgramData\windows-tb-boot\postinstall.log`:
  1. verifica dei valori `Start` dei driver USB4, ripristinati se servisse;
  2. copia di `repair-usb4-boot.bat` e `thunderbolt-boot-on.vbs` in `C:\Repair\`;
  3. `bcdedit /set {fwbootmgr} displayorder {bootmgr} /addlast` e `bcdedit /set {bootmgr} description "Windows SSD esterno"`;
  4. `Enable-ComputerRestore -Drive C:\`, poi `Checkpoint-Computer -Description "Installazione automatica"`;
  5. un file indicatore per non ripetere le operazioni già fatte.
- [ ] `SetupComplete.cmd` lancia `PostInstall.ps1` con `-ExecutionPolicy Bypass`.
- [ ] **Soluzione di riserva:** `FirstLogonCommands` in `autounattend.xml` richiama lo stesso script. Vedi il rischio R1.

**Accettazione:** eseguito a mano sul Windows esterno attuale, già configurato, `PostInstall.ps1` riconosce lo stato esistente e non fa danni. È un test sicuro, che non richiede reinstallazioni.

### M5 — `autounattend.xml`
- [ ] Fase `windowsPE`: lingua e tastiera italiane, accettazione della licenza, **nessun `DiskConfiguration`**, scelta del disco interattiva.
- [ ] Fase `oobeSystem`: `HideEULAPage`, `HideOnlineAccountScreens`, `HideWirelessSetupInOOBE`, fuso orario `W. Europe Standard Time`, `FirstLogonCommands` (M4).
- [ ] **Account locale senza password nel file.** Verificare se, con le schermate online nascoste e senza `LocalAccounts`, la configurazione iniziale chiede di creare un account locale in modo interattivo. Altrimenti trovare un'alternativa che non scriva credenziali nel file.
- [ ] **Codice Product Key:** controllare quale edizione indica il codice nel firmware, con `(Get-CimInstance SoftwareLicensingService).OA3xOriginalProductKeyDescription`. Decidere se serve `sources\ei.cfg`. Nessun codice nel repository.
- [ ] Validazione con Windows System Image Manager, oppure almeno contro lo schema.

**Accettazione:** il file viene validato senza errori. Lista di controllo: niente segreti, niente `DiskConfiguration`, niente identificativi.

### M6 — Preparazione della chiavetta
- [ ] `Copy-ToUsb.ps1 -UsbRoot E:\`: richiede conferma, controlla che sulla chiavetta ci sia un supporto di installazione di Windows, sostituisce `sources\install.esd/.wim` con quello corretto **rimuovendo l'originale**, copia `autounattend.xml` e scrive un file con gli hash SHA256.
- [ ] Documentare la creazione con Rufus: installazione standard, NTFS, nessuna opzione di personalizzazione di Rufus, perché genererebbe un proprio `autounattend.xml`.

**Accettazione:** la chiavetta contiene esattamente i file previsti, con hash coincidenti.

### M7 — Test completo sull'hardware

**Solo con un SSD di prova, oppure quando si è disposti a reinstallare da zero.** L'installazione cancella il disco scelto.

- [ ] Avvio della chiavetta con F12; l'unico intervento manuale è la scelta del disco.
- [ ] Primo avvio dall'SSD **senza schermata blu**.
- [ ] Configurazione iniziale ridotta al minimo, con creazione dell'account locale.
- [ ] Log di `PostInstall.ps1` senza errori.
- [ ] Controlli con `reg query` sui valori `Start`, `bcdedit /enum {fwbootmgr}`, punto di ripristino presente, script in `C:\Repair\`.
- [ ] Wi-Fi funzionante, e in Gestione disco solo l'SSD esterno.
- [ ] Tre riavvii consecutivi, poi un ciclo completo di Windows Update, poi nuovo controllo dei valori.

**Accettazione:** tutte le voci superate, e risultati riportati nella tabella di stato del README.

### M8 — Documentazione
- [ ] `autoinstall/README.md`.
- [ ] In `docs/guide.it.md`, una sezione "Alternativa: installazione automatica", con rimando ad `autoinstall/`.
- [ ] Nuovi casi in `docs/troubleshooting.it.md`.
- [ ] Nuove righe nella tabella di stato del README principale.

## 7. Rischi e mitigazioni

| # | Rischio | Mitigazione |
|---|---|---|
| R1 | Microsoft documenta che `SetupComplete.cmd` **non viene eseguito se si usa un codice Product Key OEM**, e questo notebook ne ha uno nel firmware | `FirstLogonCommands` come riserva; `PostInstall.ps1` idempotente e con file indicatore; verifica in M7 |
| R2 | Gli aggiornamenti di Windows riportano i driver USB4 a `Start = 3` (osservato) | Nessuna protezione preventiva verificata; riparazione dall'ambiente di ripristino con `repair-usb4-boot.bat` (guida, Fase 6), verificata di nuovo il 30/10/2026 nella versione precedente a quella attuale; la versione attuale ha `/check` per il controllo in sola lettura, provato il 30/10/2026 da Windows avviato e in WinRE, con i valori già corretti. Da studiare: una soluzione che regga gli aggiornamenti. Già esclusa: `BootFlags = 0x14` sui due servizi (provato il 16 ottobre, con `Start = 3` non parte). In prova: il servizio `Usb4BootGuard` (`windows/usb4-boot-guard/`, guida Fase 5.9), che rimette `Start = 0` quando l'aggiornamento lo cambia; testato su un registro di prova e con `-SelfTest` sul sistema in uso, non ancora con un aggiornamento reale. Se regge, `PostInstall.ps1` (M4) potrà installarlo |
| R3 | Il rilascio di un hive fallisce perché qualche handle è ancora aperto | `[gc]::Collect()`, tentativi ripetuti, `finally`; in caso estremo, istruzioni di pulizia manuale |
| R4 | Montaggi DISM rimasti appesi | Controllo all'avvio e `Clear-WindowsCorruptMountPoint` |
| R5 | Una nuova build di Windows rinomina o rimuove i servizi USB4 | Controllo di esistenza con errore esplicito (M2) |
| R6 | L'ID del controller VMD è diverso su altri modelli | Parametro facoltativo; obbligo di verificarlo prima con `windows/show-disk-paths.ps1` |
| R7 | Microsoft cambia la configurazione iniziale, e gli account locali non funzionano più | Test a ogni nuova build; documentare la build verificata |
| R8 | Chiavetta avviata sul PC sbagliato | Nessuna operazione automatica sui dischi (vincolo 1) |

## 8. Convenzioni

- **PowerShell:** compatibile con Windows PowerShell 5.1, `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`, funzioni avanzate con `[CmdletBinding()]`, commenti in italiano.
- **Bash:** `set -euo pipefail`, superare shellcheck.
- **Lingua:** documentazione e messaggi per l'utente in italiano.
- **Commit** piccoli, uno per attività, con messaggi descrittivi.
- Nessuno script modifica il sistema in uso senza una conferma esplicita.

## 9. Sviluppi successivi (facoltativi)

- **Programmi al primo accesso:** `winget import` da un elenco versionato nel repository.
- **BIOS da Windows:** l'interfaccia WMI Dell `root\dcim\sysman\biosattributes` come alternativa allo script Linux per `ThunderboltBoot`. **Verificata il 30/10/2026** dall'ambiente di ripristino, con il BIOS aggiornato: lettura con `wmic` (classe `EnumerationAttribute`) e scrittura con `SetAttribute` di `BIOSAttributeInterface` in un VBScript minimo (`Status = 0`, poi `Enabled`). Lo script completo è `windows/thunderbolt-boot-on.vbs`, non ancora verificato nel suo insieme. Restano da verificare l'ambiente della chiavetta di installazione (Shift+F10) e l'attivazione dal Windows esterno avviato. Rischio alto: nessuna automazione senza conferma.
- **Generazione di una ISO** con `oscdimg`, al posto della sostituzione dei file sulla chiavetta.
