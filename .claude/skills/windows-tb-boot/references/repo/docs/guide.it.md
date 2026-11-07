**🌐 Lingua:** [English](guide.md) · **Italiano**

# Guida passo passo

Questa guida descrive la procedura completa, nell'ordine consigliato. Ogni fase spiega anche **perché** si fa quello che si fa: se qualcosa va storto, capire il motivo ti aiuta a trovare la soluzione.

Prima di iniziare leggi le [avvertenze nel README](../README.it.md#avvertenze).

**Convenzioni**
- F2 apre il BIOS, F12 il menu di avvio una tantum.
- "Disco interno" è il disco originale del notebook, che non va mai toccato. "SSD esterno" è l'SSD nel box Thunderbolt.
- Ogni blocco di comandi indica dove va lanciato:
  - *sessione live di Ubuntu*: il terminale della chiavetta B. Vale questo, salvo dove indicato diversamente;
  - *Prompt dei comandi come amministratore*: `cmd` nel Windows esterno, aperto con *Esegui come amministratore*;
  - *PowerShell come amministratore*: PowerShell nel Windows esterno, aperto allo stesso modo;
  - *prompt di WinRE*: il Prompt dei comandi dell'ambiente di ripristino di Windows, oppure quello che si apre con Shift+F10 dalla chiavetta di installazione. È un `cmd` **senza PowerShell** e senza `where`; ci sono `reg`, `wmic`, `cscript` (VBScript), `notepad`, `manage-bde` e `bcdedit`.
- **I comandi PowerShell non funzionano nel Prompt dei comandi.** È l'errore più frequente: se `Get-PnpDevice`, `Get-Tpm` o `Select-String` non vengono riconosciuti come comandi interni o esterni, sei nel Prompt dei comandi. Apri PowerShell come amministratore; in WinRE, dove PowerShell non c'è, usa l'alternativa per `cmd` indicata nel testo.

---

## Fase 0 — Preparazione

### 0.1 Le immagini

- **Windows 11:** scarica l'ISO ufficiale dal sito Microsoft.
- **Ubuntu Desktop:** scarica l'ultima versione LTS (testata la 26.04.1, kernel 7.0) da ubuntu.com, e verifica il checksum SHA256 pubblicato sul sito.

### 0.2 Chiavetta A: installazione di Windows

In Rufus:
- **Dispositivo:** la chiavetta.
- **Selezione boot:** l'ISO di Windows 11.
- **Opzione immagine:** *Installazione standard di Windows*. **Non** usare *Windows To Go*.
- **Schema partizione:** GPT. **Sistema di destinazione:** UEFI (non CSM).
- Nella finestra delle opzioni di Windows che compare dopo START puoi rimuovere i requisiti di TPM, Secure Boot e RAM e l'obbligo dell'account Microsoft. Sono facoltative: la procedura non dipende da queste scelte.

**Perché l'installazione standard e non Windows To Go:** l'SSD verrà avviato via Thunderbolt, cioè come un disco NVMe su PCIe, non come un disco USB.

**Per il percorso senza Ubuntu (non verificato, Fase 1 e punto 3.4):** finita la scrittura, crea sulla chiavetta una cartella `Repair` e copiaci il contenuto della cartella `windows\` del repository. Servono `repair-usb4-boot.bat` e `thunderbolt-boot-on.vbs`.

### 0.3 Chiavetta B: sessione live di Ubuntu

In Rufus:
- **Selezione boot:** l'ISO di Ubuntu.
- **Partizione persistente:** 0.
- Schema GPT, destinazione UEFI.
- Quando Rufus chiede se scrivere in modalità ISO o DD, scegli **DD**.

**Perché DD:** copia l'immagine esattamente com'è, ed è il metodo più affidabile per avviare Ubuntu con Secure Boot attivo.

### 0.4 Prima di iniziare

- Monta l'SSD nel box e collegalo a una porta **Thunderbolt 5** del notebook con il **cavo Thunderbolt**. Con il box ACASIS dei test, un cavo USB-C collegato a una porta Thunderbolt negozia comunque il Thunderbolt. La modalità USB si ottiene solo con un cavo USB-C → USB-A su una porta USB-A.
- Tieni da parte anche un **cavo USB-C → USB-A**. Non serve per l'uso normale, ma solo per il ripristino: quando `ThunderboltBoot` è spento, è il modo di raggiungere l'ambiente di ripristino di Windows (Fase 7).
- Collega il box **prima di accendere** il notebook, in tutte le fasi.
- Tieni a portata di mano la recovery key BitLocker del disco interno, o sappi dove è salvata (per esempio nell'account Microsoft usato su quel sistema).
- Scollega dischi e chiavette che non servono.

---

## Fase 1 — Verifica e attivazione di ThunderboltBoot

**Obiettivo:** far vedere l'SSD esterno al firmware prima del boot. Senza questo passaggio il firmware non può avviare nulla dall'SSD.

### 1.1 Avvia la sessione live nascondendo il disco interno

1. Accendi il notebook, premi F12 e scegli la chiavetta B.
2. Nel menu di GRUB evidenzia *Try or Install Ubuntu* e premi `e`.
3. Vai in fondo alla riga che inizia con `linux`, aggiungi uno spazio e scrivi:
   ```
   modprobe.blacklist=vmd
   ```
4. Avvia con **Ctrl+X**. Quando si apre l'installer di Ubuntu, scegli *Prova Ubuntu* oppure chiudilo.

**Perché:** se il BIOS è in modalità RAID/RST, il disco interno è collegato attraverso il controller Intel VMD. Impedendo a Linux di caricare il driver `vmd`, il disco interno sparisce dalla sessione live: non puoi selezionarlo per errore, e l'SSD esterno prende un nome prevedibile (`nvme0n1`). Il parametro va riaggiunto a ogni avvio della sessione live, perché la sessione non salva nulla.

**Se il tuo BIOS è in modalità AHCI/NVMe**, il parametro non nasconde il disco interno. In quel caso identifica i dischi con estrema attenzione, dalla dimensione e dal modello.

### 1.2 Controlla i dischi

```
lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL
```

Deve comparire solo l'SSD esterno, oltre alla chiavetta (`sda`) e ai dispositivi `loop` della sessione live.

### 1.3 Scarica il repository

Collegati al Wi-Fi. Poi, nel terminale:

```
sudo apt update
sudo apt install -y git
git clone https://github.com/endjneer/windows-tb-boot.git
cd windows-tb-boot
chmod +x scripts/*.sh
```

Se `git clone` non funziona, apri la pagina del repository con Firefox, scarica lo ZIP (**Code → Download ZIP**), estrailo, entra nella cartella `windows-tb-boot-main` e lancia lo stesso `chmod`.

### 1.4 Verifica il BIOS (sola lettura)

```
./scripts/check-bios.sh
```

Lo script mostra:
- se esiste l'attributo `ThunderboltBoot` e il suo valore attuale;
- lo stato di `PreBootDma`, la protezione DMA prima del boot, che deve restare **Enabled**;
- se è impostata una password di amministratore del BIOS;
- il controller Thunderbolt e il box collegato.

**Se `ThunderboltBoot` non esiste**, il tuo firmware non permette l'avvio via Thunderbolt e questa procedura non è applicabile. Vedi le alternative in fondo alla guida.

**Se è impostata una password di amministratore**, lo script si ferma. Se il PC non è tuo, la modifica va concordata con chi lo gestisce.

### 1.5 Attiva ThunderboltBoot

```
./scripts/thunderbolt-boot.sh
```

Lo script mostra il valore attuale, chiede conferma, scrive `Enabled` e verifica che la modifica sia in attesa di riavvio.

**Perché da Linux:** il driver `dell-wmi-sysman` espone in `/sys/class/firmware-attributes/` le impostazioni del BIOS, comprese alcune che il menu non mostra. È lo stesso meccanismo usato dagli strumenti di gestione Dell. Gli stessi attributi sono raggiungibili da Windows e dal suo ambiente di ripristino, tramite l'interfaccia WMI del BIOS: vedi il riquadro qui sotto e la Fase 7.

### 1.6 Verifica

Spegni il notebook, lascia il box collegato, riaccendi e premi F12. Nel menu deve comparire una voce con il modello dell'SSD, per esempio `UEFI WD_BLACK SN850X 1000GB`. Se compare, il firmware vede l'SSD via Thunderbolt.

Per ora **non avviarla**: l'SSD è ancora vuoto, oppure contiene un'installazione non ancora corretta.

> **Alternativa senza Ubuntu (non verificata).** Il 30/10/2026 `ThunderboltBoot` è stato letto e attivato dal prompt dell'ambiente di ripristino di Windows, con `wmic` e con un VBScript (Fase 7). Per un'installazione nuova, l'ambiente equivalente è la chiavetta A aperta con **Shift+F10**:
>
> 1. copia gli script nella cartella `Repair` della chiavetta (punto 0.2);
> 2. avvia la chiavetta A e premi **Shift+F10**. Trova la lettera della chiavetta, per esempio con `dir E:\Repair`; qui sotto è `E:`;
> 3. prova in sola lettura, nel *prompt di WinRE*:
>    ```
>    wmic /namespace:\\root\dcim\sysman\biosattributes path EnumerationAttribute where "AttributeName='ThunderboltBoot'" get AttributeName,CurrentValue
>    ```
> 4. attiva l'attributo:
>    ```
>    cscript //nologo E:\Repair\thunderbolt-boot-on.vbs
>    ```
>    Lo script mostra il valore, lo imposta a `Enabled` se serve e lo rilegge;
> 5. spegni e verifica come al punto 1.6.
>
> Resta da chiarire se l'ambiente della chiavetta di installazione contiene `cscript` e l'interfaccia WMI come l'ambiente di ripristino. Il percorso verificato resta quello con Ubuntu.

---

## Fase 2 — Prima fase dell'installazione di Windows

### 2.1 Avvia l'installer

Con il box collegato, premi F12 e scegli la chiavetta A.

### 2.2 Scegli l'edizione

Se puoi, scegli **Windows 11 Pro**: serve per cifrare l'SSD esterno con BitLocker (Fase 5).

### 2.3 Scegli il disco

Nella schermata di scelta del disco:
- **Il disco interno potrebbe non comparire.** Se il BIOS è in modalità RAID/RST, l'installer di Windows non ha il driver VMD e non vede il disco interno. È normale, e anzi è un vantaggio: non puoi sceglierlo per errore.
- Identifica l'SSD esterno dalla dimensione.

Se l'SSD contiene già delle partizioni, cancellale da diskpart. Premi **Shift+F10** e scrivi:

```
diskpart
list disk
select disk N
detail disk
clean
convert gpt
exit
```

`N` è il numero dell'SSD esterno. Prima di `clean` controlla con `detail disk` che il modello sia quello giusto: `clean` cancella tutto il disco selezionato.

Torna all'installer, aggiorna l'elenco, seleziona lo spazio non allocato dell'SSD e procedi. Il Setup creerà da solo le partizioni (ESP da 200 MB, MSR e partizione di Windows).

**Se il disco interno è visibile** (BIOS in modalità AHCI/NVMe), il Setup potrebbe scrivere i file di avvio sull'ESP del disco interno, anche se installi Windows sull'SSD. Prima di procedere valuta se puoi rendere invisibile il disco interno. Dopo l'installazione verifica che sull'ESP dell'SSD esista la cartella `EFI\Microsoft\Boot`.

### 2.4 Al riavvio, vai alla Fase 3

Dopo la copia dei file il Setup riavvia il PC. **Al riavvio premi F12 e scegli la chiavetta B (Ubuntu).**

**Perché:** se avviassi ora l'SSD, otterresti la schermata blu `INACCESSIBLE_BOOT_DEVICE`. Se non premi nulla, parte il sistema del disco interno con il box collegato. Non è dannoso, ma è meglio evitarlo.

**Perché l'installazione funziona e l'avvio no:** durante l'installazione è il sistema WinPE della chiavetta a creare il tunnel Thunderbolt, con i propri driver USB4, dopo essere partito. All'avvio dall'SSD invece il kernel di Windows deve ritrovare il disco prima che quei driver siano caricati. Dettagli in [how-it-works.it.md](how-it-works.it.md).

---

## Fase 3 — Correzione del registro

**Obiettivo:** fare in modo che l'installazione sull'SSD carichi all'avvio i driver che gestiscono il tunnel Thunderbolt.

### 3.1 Avvia la sessione live

Come al punto 1.1, con `modprobe.blacklist=vmd`. Collegati al Wi-Fi e rientra nella cartella del repository: se hai riavviato, la sessione live ha perso tutto e va riscaricato come al punto 1.3.

### 3.2 Individua la partizione di Windows

```
lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL
```

È la partizione NTFS più grande dell'SSD esterno, di solito `nvme0n1p3`.

### 3.3 Applica la correzione

```
./scripts/patch-windows-hive.sh /dev/nvme0n1p3
```

Lo script:
1. mostra il disco a cui appartiene la partizione e chiede di confermare scrivendo `SI`;
2. installa, se manca, il pacchetto `libwin-hivex-perl`, che fornisce `hivexregedit`;
3. monta la partizione;
4. crea una copia di sicurezza del registro di sistema (`SYSTEM.bak-<data>`), senza mai sovrascrivere copie precedenti;
5. applica le due modifiche della cartella `registry/`:
   - `BootDriverFlags = 0x14` in `Control`, che chiede a Windows di caricare all'avvio i driver dei dischi USB;
   - `Start = 0` per i servizi `Usb4HostRouter` e `Usb4DeviceRouter`, cioè i driver USB4 caricati all'avvio invece che su richiesta;
6. verifica che i valori siano stati scritti, e smonta la partizione.

**Nota sulla prima modifica:** nei test, `BootDriverFlags` da sola non è bastata, ed è stata decisiva la seconda. La prima è rimasta applicata nella configurazione che ha funzionato, e non ci sono motivi per toglierla, ma non è dimostrato che sia necessaria.

**Perché `hivexregedit --merge`:** aggiunge o aggiorna solo i valori elencati nel file `.reg`. Non usare il comando `setval` di `hivexsh`: sostituisce tutti i valori della chiave in cui ti trovi, e nella chiave `Control` cancellerebbe decine di impostazioni di sistema.

**Se il mount fallisce** perché il volume risulta "dirty", per esempio dopo una schermata blu, puoi riprovare con:
```
FORCE=1 ./scripts/patch-windows-hive.sh /dev/nvme0n1p3
```

### 3.4 Alternativa senza Linux (non verificata)

Le stesse modifiche si possono fare dalla chiavetta A, con lo script che si usa per la riparazione dall'ambiente di ripristino. La sua modalità offline è stata verificata il 30/10/2026 in WinRE; dalla chiavetta di installazione non è ancora stata provata.

1. Al riavvio del punto 2.4 premi F12 e scegli la **chiavetta A** invece della B.
2. Quando compare l'installer, premi **Shift+F10**.
3. Trova le due lettere: quella della chiavetta, con la cartella `Repair` (punto 0.2), e quella della partizione di Windows dell'SSD:
   ```
   dir E:\Repair
   dir D:\Windows
   ```
   Prova le lettere una per una. Di solito, dalla chiavetta, il disco interno non è visibile (punto 2.3); se lo fosse, controlla con particolare attenzione di aver scelto la partizione dell'SSD.
4. Lancia lo script indicando la lettera dell'SSD, nell'esempio `D:`:
   ```
   E:\Repair\repair-usb4-boot.bat D:
   ```
   Lo script mostra i valori, chiede conferma con `SI` e scrive le stesse modifiche della cartella `registry/`. Alla fine controlla anche `ThunderboltBoot`, se `thunderbolt-boot-on.vbs` è nella stessa cartella.
5. Chiudi il prompt con `exit`, poi chiudi l'installer confermando l'annullamento: il PC si riavvia. Premi F12 e prosegui con la Fase 4, avviando l'SSD.

Senza script, i comandi manuali sono quelli del punto 6.3, con la lettera dell'SSD al posto di `D:`.

---

## Fase 4 — Voce di avvio e completamento del Setup

### 4.1 Crea una voce di avvio dedicata

Il firmware crea da solo una voce per l'SSD, per esempio `UEFI WD_BLACK SN850X 1000GB`, che avvia il file di riserva `\EFI\BOOT\BOOTX64.EFI`. Nei test è stata usata una voce esplicita, che punta direttamente al boot manager di Windows:

1. Entra nel BIOS (F2) → **Boot Configuration** → **Boot Sequence** → **Add Boot Option**.
2. Premi **Browse for file**. Il File Explorer elenca le partizioni leggibili di tutti i dischi.
3. Riconosci l'ESP dell'SSD esterno dal percorso:
   - le partizioni del **disco interno** hanno un'etichetta (ESP, OS, WINRETOOLS…) e un percorso corto, con un solo nodo `Pci(...)` prima di `NVMe(...)`;
   - quelle dell'**SSD esterno** compaiono come *NO VOLUME LABEL* e hanno un percorso lungo, con molti nodi `Pci(...)`. Sono i ponti PCIe del controller Thunderbolt del notebook e del box;
   - l'ESP è quella con `HD(1,GPT,...,0x800,0x64000)`: prima partizione, `0x64000` settori da 512 byte, cioè 200 MB.
4. Apri `EFI` → `Microsoft` → `Boot` → `bootmgfw.efi` e premi **Submit**.
5. In **Boot Option Name** scrivi un nome, per esempio `Windows SSD`. Entrambi i campi sono obbligatori: senza nome il BIOS risponde *Invalid Parameters*.
6. Premi **Add Boot Option**.

**Se la nuova voce non compare nell'elenco**, togli e rimetti la spunta a una delle voci, premi **Apply Changes**, esci dal BIOS e rientra.

**Lascia `Windows Boot Manager` al primo posto**, così l'avvio predefinito resta il sistema interno. Il Windows esterno lo avvii con F12.

**Non spuntare** *Save as Custom User Settings* all'uscita: sovrascriverebbe un eventuale profilo personalizzato del BIOS.

### 4.2 Primo avvio dall'SSD

Riavvia con il box collegato, premi F12 e scegli **Windows SSD**. Deve comparire la schermata *Installazione in corso* del Setup di Windows. La voce manuale serve solo fino alla fine del Setup: alla Fase 5.2 la elimini, perché diventa un doppione.

### 4.3 Durante il Setup

Il Setup riavvia il PC alcune volte. Nei primi riavvii il firmware parte dalla voce predefinita, cioè il sistema interno: **premi F12 e scegli Windows SSD**. A un certo punto il Setup registra nel firmware una propria voce *Windows Boot Manager* e la mette al primo posto, e da lì i riavvii proseguono da soli sull'SSD. L'ordine originale si ripristina alla Fase 5.2.

Se per errore parte il sistema interno, riavvia e scegli Windows SSD: il Setup riprende da dove si era fermato. **Non scollegare il box durante il Setup.**

### 4.4 Configurazione iniziale, senza Internet

Alla schermata *Connettiamoci a una rete* scegli **Non ho Internet** e crea un account locale. L'opzione compare se in Rufus hai rimosso l'obbligo dell'account Microsoft (Fase 0.2).

**Perché offline:**
- è il percorso più veloce;
- probabilmente Windows non ha ancora il driver della scheda Wi-Fi;
- soprattutto, Windows Update non deve partire prima che la correzione sia protetta (Fase 5.1). Un aggiornamento dei driver USB4 potrebbe riportarli al caricamento su richiesta, e al riavvio ricomparirebbe la schermata blu.

---

## Fase 5 — Dopo l'installazione

### 5.1 Prima di collegarti a Internet

Apri il **Prompt dei comandi come amministratore** e controlla i valori:

```
reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4HostRouter /v Start
reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4DeviceRouter /v Start
```

Entrambi devono mostrare `Start    REG_DWORD    0x0`.

Usa `reg query` e non `sc qc ... | findstr START_TYPE`: su Windows in italiano l'output di `sc qc` è tradotto, e il filtro non trova nulla.

**Escludi driver e firmware da Windows Update.** Windows Update può distribuire anche gli aggiornamenti del BIOS Dell, presentati come aggiornamenti dei driver "Firmware" e applicati al riavvio. Il BIOS è unico e condiviso con il sistema del disco interno: un aggiornamento lanciato dal Windows esterno può far chiedere la recovery key di BitLocker al sistema interno, e può riportare `ThunderboltBoot` al valore predefinito. È successo il 30/10/2026 (Fase 7), con un aggiornamento avviato molto probabilmente da Dell SupportAssist: questa regola non lo impedisce, per questo serve anche il punto 5.10. Sempre nel prompt da amministratore:

```
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate
```

Il secondo comando deve mostrare `0x1`. Da questo momento Windows Update non installa più driver né firmware, e i driver li installi a mano (Fase 5.4). La regola è documentata da Microsoft per le edizioni Pro, Enterprise ed Education: su Home potrebbe essere ignorata.

Se ti sei già collegato a Internet prima di impostarla, controlla in **Impostazioni → Windows Update → Cronologia aggiornamenti → Aggiornamenti driver** che non compaia una voce *Dell Inc. – Firmware*. Vedi anche [troubleshooting.it.md](troubleshooting.it.md).

**Prepara gli script di riparazione.** Copia [`windows/repair-usb4-boot.bat`](../windows/repair-usb4-boot.bat) e [`windows/thunderbolt-boot-on.vbs`](../windows/thunderbolt-boot-on.vbs) in `C:\Repair\`, nella stessa cartella. Servono a riparare dall'ambiente di ripristino senza riscrivere i comandi:
- un aggiornamento di Windows può riportare i driver USB4 a `Start = 3`, e allora Windows non parte più (Fase 6). Al momento non esiste una protezione preventiva verificata; un tentativo, ancora da verificare, è il servizio della Fase 5.9;
- un aggiornamento o un azzeramento del BIOS può spegnere `ThunderboltBoot`, e allora l'SSD sparisce dal menu F12 (Fase 7).

Per provarli senza modificare nulla, nel *Prompt dei comandi*:

```
C:\Repair\repair-usb4-boot.bat /check
```

`/check` è in sola lettura: mostra i tre valori del registro con l'esito e lo stato di `ThunderboltBoot`, ed esce con 0 se è tutto a posto, 2 se c'è qualcosa da correggere, 1 in caso di errore. Per il registro non servono i diritti di amministratore; per leggere `ThunderboltBoot` sì, e senza lo script lo segnala senza considerarlo un errore. Il 30/10/2026 `/check` e `/status` sono stati provati da Windows, con e senza diritti di amministratore, e in WinRE (Fase 6).

### 5.2 Rimetti al primo posto il sistema interno

Alla fine del Setup, Windows registra nel firmware la propria voce *Windows Boot Manager* e la mette al primo posto. Nel menu F12 compaiono quindi due voci *Windows Boot Manager*, una per disco e indistinguibili dal nome, e l'avvio predefinito diventa il Windows esterno. Dal BIOS non si capisce quale sia quale; da Windows sì.

Nel Prompt dei comandi da amministratore del Windows esterno:

```
bcdedit /enum firmware
```

- `{bootmgr}` è la voce del Windows esterno, quello in cui ti trovi. Ha `device partition=\Device\HarddiskVolume...`, cioè l'ESP dell'SSD.
- La voce del sistema interno è un'altra *Windows Boot Manager*, con un identificativo tra parentesi graffe e `device unknown`: il Windows esterno non ha il driver VMD e non vede il disco interno.

Sposta in fondo la voce esterna e rinominala, così nel menu F12 la riconosci:

```
bcdedit /set {fwbootmgr} displayorder {bootmgr} /addlast
bcdedit /set {bootmgr} description "Windows SSD esterno"
```

Verifica:

```
bcdedit /enum {fwbootmgr}
```

Il primo valore di `displayorder` deve essere l'identificativo della voce interna, e `{bootmgr}` deve essere l'ultimo.

Non serve provare riavviando con il box collegato: partirebbe il sistema interno con l'SSD visibile. Il controllo con `bcdedit` è sufficiente. Dopo un aggiornamento importante di Windows ricontrolla l'ordine, perché Windows potrebbe rimettersi al primo posto.

**Elimina la voce creata a mano alla Fase 4 (*Windows SSD*).** A questo punto è un doppione: punta allo stesso file, sullo stesso disco e sulla stessa partizione, della voce di Windows. Nei test il firmware, all'accensione, ha eliminato una delle due voci doppie. Avviandosi, Windows non ha trovato la propria voce, l'ha ricreata e l'ha rimessa al primo posto. Con due voci identiche questo ciclo si ripete a ogni riavvio.

Trova l'identificativo della voce manuale con `bcdedit /enum firmware`: è quella con `description Windows SSD`. Poi, **un comando per volta**, perché incollandone più insieme le righe possono fondersi e dare errori:

```
bcdedit /delete {IDENTIFICATIVO-DELLA-VOCE-MANUALE}
bcdedit /set {fwbootmgr} displayorder {bootmgr} /addlast
bcdedit /set {bootmgr} description "Windows SSD esterno"
bcdedit /enum {fwbootmgr}
```

In alternativa la voce manuale si può cancellare dal BIOS, con DELETE.

Una voce di riserva resta comunque: quella che il firmware crea da solo per l'SSD (*UEFI* seguito dal modello del disco), che avvia il file di riserva `\EFI\Boot\BootX64.efi`.

Alla prima occasione verifica che il ciclo si sia interrotto: nel menu F12 deve comparire *Windows SSD esterno*, e `bcdedit /enum {fwbootmgr}` deve mostrare `{bootmgr}` ancora in fondo. Se Windows continuasse comunque a rimettersi in cima, non sarebbe grave: con il box scollegato il firmware salta la voce del disco assente, e con il box collegato parte il Windows esterno, che è cifrato e chiede il PIN.

### 5.3 Driver di rete senza Internet

Se Windows non ha il driver della scheda Wi-Fi, queste sono le strade, in ordine di comodità:
1. **cavo Ethernet:** Windows potrebbe avere già il driver della porta di rete;
2. **telefono Android collegato via USB**, con la condivisione della connessione: funziona senza driver. Con un iPhone servono i driver Apple;
3. **scaricare il driver altrove e installarlo offline:** i pacchetti di driver Dell (`.exe`) si installano senza connessione.

Per capire quale driver serve, nel prompt da amministratore lancia:

```
pnputil /enum-devices /problem
```

Nell'*ID istanza* del controller di rete trovi il produttore: `VEN_8086` è Intel (anche per le schede Killer), `VEN_17CB` è Qualcomm, `VEN_14C3` è MediaTek. Sul sito di supporto Dell, nella pagina del modello, categoria Rete, scegli il driver Wi-Fi di quel produttore.

**Per scaricarlo dalla sessione live di Ubuntu**, se non hai un altro PC:
1. Spegni Windows completamente con `shutdown /s /t 0`, così la partizione NTFS viene chiusa in modo pulito.
2. Avvia la sessione live con `modprobe.blacklist=vmd`, collegati al Wi-Fi e scarica il driver con Firefox.
3. Copialo sull'SSD:
   ```
   sudo mkdir -p /mnt/win
   sudo mount -t ntfs3 /dev/nvme0n1p3 /mnt/win
   sudo mkdir -p /mnt/win/Driver
   sudo cp ~/Scaricati/*.exe /mnt/win/Driver/ 2>/dev/null || sudo cp ~/Downloads/*.exe /mnt/win/Driver/
   sync && sudo umount /mnt/win
   ```
4. Avvia il Windows esterno ed esegui il file da `C:\Driver`.

Una volta in rete, installa gli altri driver come descritto al punto 5.4: con la regola impostata alla Fase 5.1, Windows Update non li installa più. Dopo i primi aggiornamenti di Windows, ricontrolla i valori `Start` come al punto 5.1.

### 5.4 Driver: cosa installare e cosa evitare

Con driver e firmware esclusi da Windows Update (Fase 5.1), i driver si installano a mano. Scaricali dalla pagina di supporto Dell del modello, scegliendo il modello dall'elenco: il rilevamento automatico richiede SupportAssist.

**Da Dell** (Windows 11), in quest'ordine:
1. **Rete:** Wi-Fi, Bluetooth, Ethernet. Probabilmente li hai già installati alla Fase 5.3.
2. **Chipset:** Intel Chipset Device Software, Intel Serial IO e Intel Management Engine, **solo il pacchetto driver**, non il "Firmware Update".
3. **Gestione termica ed energetica:** Intel Dynamic Tuning Technology o Innovation Platform Framework, secondo cosa elenca la pagina.
4. **Software di controllo Dell del modello:** profili energetici, ventole, illuminazione. Il profilo scelto determina la potenza disponibile per la GPU.
5. **Audio** (Realtek) e **grafica integrata Intel**.
6. Facoltativi: webcam e Windows Hello, NPU.

**Da nvidia.com:** il driver della GPU, versione *Studio* per carichi di calcolo e IA, *Game Ready* per i giochi. La versione OEM sul sito Dell è di solito più vecchia.

**Da evitare:**
- **aggiornamenti del BIOS e dei firmware**: BIOS, Management Engine, Thunderbolt/USB4, SSD interno. Il firmware è condiviso con il sistema interno;
- **Intel RST/VMD**: al Windows esterno non serve, perché parte dal Thunderbolt, e renderebbe visibile il disco interno. Per impedirne del tutto l'installazione vedi il punto 5.5.2;
- **SupportAssist e Dell Command Update**: propongono automaticamente anche gli aggiornamenti del BIOS. Possono anche arrivare da soli, senza che tu li installi: è successo con SupportAssist. Controlla e bloccali come descritto al punto 5.10.

**Dopo ogni pacchetto, prima di riavviare**, soprattutto chipset, Serial IO e tutto ciò che riguarda USB o Thunderbolt, ricontrolla i valori `Start` come al punto 5.1. Se uno è tornato a `0x3`, lancia `C:\Repair\repair-usb4-boot.bat` da un Prompt dei comandi come amministratore: rimette i valori a 0 prima del riavvio.

Alla fine, `pnputil /enum-devices /problem` non deve elencare più nulla: tutti i dispositivi hanno il loro driver.

### 5.5 Nascondi il disco interno al Windows esterno

Apri **Gestione disco**: deve comparire solo l'SSD esterno. Subito dopo l'installazione è così, perché il Windows esterno non ha il driver Intel RST/VMD e non vede il disco interno. Basta però che il driver arrivi, da un pacchetto Dell, da un installer del chipset o da Windows Update prima della regola della Fase 5.1, e il disco interno compare con le sue partizioni. Se il disco non è cifrato in un modo che il Windows esterno non sa sbloccare, diventano leggibili anche i file.

L'obiettivo è che niente di ciò che gira sul Windows esterno possa leggere o modificare il disco interno: un malware, una scansione antivirus completa, l'indicizzazione, uno strumento di automazione o di intelligenza artificiale con accesso ai file.

#### 5.5.1 Misura immediata: disco offline

Nel Prompt dei comandi da amministratore:

```
diskpart
list disk
select disk N
offline disk
exit
```

`N` è il numero del disco interno, riconoscibile dalla dimensione. L'impostazione viene salvata nel registro del Windows esterno e non scrive nulla sul disco interno. È però una misura debole: qualunque programma con diritti di amministratore può rimettere il disco online.

#### 5.5.2 Misura robusta: blocco del driver VMD

Senza driver VMD il disco interno sparisce del tutto, come durante l'installazione. Il Windows esterno non ne ha bisogno, perché parte dal Thunderbolt. Prima però bisogna essere certi di bloccare il controller giusto: bloccare per errore un ponte del percorso Thunderbolt renderebbe il Windows esterno non avviabile.

**1. Identifica il controller.** In PowerShell, anche senza diritti di amministratore, lancia [`windows/show-disk-paths.ps1`](../windows/show-disk-paths.ps1), oppure incolla il suo contenuto. Per ogni disco risale l'albero dei dispositivi fino alla radice, e stampa nome e ID di ogni passaggio. Nell'ambiente di test:

```
== (disco interno)
NVMe xxxx                       |  SCSI\DISK&VEN_NVME&PROD_xxxx\...
Intel RST VMD Controller xxxx   |  PCI\VEN_8086&DEV_xxxx&SUBSYS_xxxxxxxx&REV_xx\...
Complesso radice PCI Express    |  ACPI\PNP0A08\0
...
== SN850X
WD_BLACK SN850X 1000GB          |  SCSI\DISK&VEN_NVME&PROD_WD_BLACK_SN850X\...
Controller Standard NVM Express |  PCI\VEN_15B7&DEV_5030&...
Porta di commutazione ...       |  PCI\VEN_8086&DEV_15EF&...   (box, JHL7440)
Porta di commutazione ...       |  PCI\VEN_8086&DEV_xxxx&...   (Thunderbolt 5 del notebook)
Porta radice PCI Express        |  PCI\VEN_8086&DEV_xxxx&...
Complesso radice PCI Express    |  ACPI\PNP0A08\0
...
```

Il controller da bloccare è quello con **VMD** nel nome sopra il disco interno. Prima di procedere verifica che **non** compaia nel percorso dell'SSD esterno. Prendi il suo ID dal tuo output, fermandoti alla parte `PCI\VEN_xxxx&DEV_xxxx`: nell'esempio `PCI\VEN_8086&DEV_xxxx`, con i quattro caratteri del tuo output al posto di `xxxx`.

**2. Imposta il blocco.** Nel Prompt dei comandi da amministratore, sostituendo l'ID con il tuo:

```
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /v DenyDeviceIDs /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /v DenyDeviceIDsRetroactive /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 1 /t REG_SZ /d "PCI\VEN_8086&DEV_xxxx" /f
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /s
```

È la regola di sistema *Impedisci l'installazione di dispositivi che corrispondono a uno di questi ID*: nessun driver può più agganciarsi a quel controller.

**3. Rimuovi il driver attuale.** In **Gestione dispositivi → Controller di archiviazione**, fai clic destro sul controller VMD → **Disinstalla dispositivo**, spunta **Tenta di rimuovere il driver per questo dispositivo** e conferma.

**4. Riavvia e verifica.**
- In Gestione disco deve comparire solo l'SSD esterno.
- In Gestione dispositivi il controller VMD resta senza driver, con l'avviso che l'installazione è vietata dai criteri di sistema. È il risultato atteso.

La regola sta nel registro del Windows esterno e non ha effetto sul sistema interno. Per annullarla:

```
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /f
```

Poi, in Gestione dispositivi, usa **Azione → Rileva modifiche hardware**.

#### 5.5.3 Limiti

- Offline e blocco del driver si possono annullare da un programma con diritti di amministratore. Proteggono da errori, scansioni, indicizzazione e malware comuni, non da un attacco mirato. Usa un **account standard** per l'uso quotidiano, ed esegui gli strumenti di automazione e di intelligenza artificiale senza diritti di amministratore.
- La protezione vera dei dati del disco interno "a riposo" è la sua cifratura, da attivare sul sistema interno stesso. Se il disco è leggibile da un altro sistema operativo, lo è anche da una qualunque chiavetta avviabile.

### 5.6 Cifra l'SSD esterno con BitLocker (TPM + PIN)

**Perché:** l'SSD è esterno, quindi si porta via, si perde, si presta. La cifratura lo protegge da chiunque lo avvii con una chiavetta live, e dal sistema interno se un giorno dimentichi il box collegato all'accensione.

**Requisiti:** Windows **Pro**: verificalo in Impostazioni → Sistema → Informazioni. Su Home BitLocker non è disponibile, e VeraCrypt cifra il disco di sistema solo disattivando Secure Boot, cosa sconsigliata qui.

**Quando:** dopo gli aggiornamenti cumulativi di Windows e l'installazione dei driver, e dopo aver verificato che i valori `Start` dei driver USB4 restino a `0x0` anche dopo qualche riavvio. Gli script di riparazione sanno sbloccare una partizione cifrata, ma su una partizione in chiaro la riparazione è più semplice.

#### 5.6.1 Verifica il TPM

In PowerShell come amministratore:

```
Get-Tpm
```

`TpmPresent` e `TpmReady` devono valere `True`.

**Non cancellare mai il TPM** (Sicurezza di Windows → Processore di sicurezza, oppure `tpm.msc`). È unico e condiviso fra i due sistemi: cancellarlo invaliderebbe le chiavi di BitLocker del Windows esterno e, se il sistema interno usa il TPM, anche le sue. Entrambi chiederebbero la chiave di ripristino.

#### 5.6.2 Abilita il PIN all'avvio

Di default BitLocker usa solo il TPM. Il PIN rende la chiave indipendente dallo stato della piattaforma, che qui è condivisa con un altro sistema. Nel Prompt dei comandi come amministratore:

```
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v UseAdvancedStartup /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v EnableBDEWithNoTPM /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v UseTPM /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v UseTPMPIN /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v UseTPMKey /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v UseTPMKeyPIN /t REG_DWORD /d 2 /f
```

Corrispondono alla regola di sistema *Richiedi autenticazione aggiuntiva all'avvio*, con le varie combinazioni consentite.

#### 5.6.3 Attiva la cifratura

```
manage-bde -on C: -TPMAndPIN -RecoveryPassword -UsedSpaceOnly -EncryptionMethod xts_aes256
```

- **Scegli un PIN numerico**, da 6 cifre in su. Prima dell'avvio la tastiera potrebbe avere il layout americano, e un PIN con lettere rischierebbe di non corrispondere a quello impostato.
- Il comando mostra le protezioni create: **password numerica**, con un *ID* e una *password* di 48 cifre, e **TPM e PIN**.
- `-UsedSpaceOnly` cifra solo lo spazio occupato. Su un'installazione nuova è la scelta più rapida.

#### 5.6.4 Salva la chiave di ripristino

Salva **sia l'ID sia la password numerica**. La password è la chiave vera e propria. L'ID serve a capire quale chiave usare: la schermata di ripristino di BitLocker mostra le sue prime cifre, e su un PC con due sistemi è il modo per non confondersi.

- **Dove sì:** un gestore di password (etichetta *BitLocker – Windows SSD esterno*, nome utente = ID, password = 48 cifre, data e disco nelle note), e una copia su carta conservata lontano dal notebook.
- **Dove no:** il disco interno, servizi cloud condivisi con altri, l'SSD stesso, uno screenshot nel rullino fotografico.
- Ricontrolla le cifre gruppo per gruppo. Puoi rileggerle in qualsiasi momento con `manage-bde -protectors -get C:`. Questo comando **stampa la chiave di ripristino**: usalo solo per rileggerla, mai in uno screenshot o in un output da condividere. Per i controlli usa la forma con `-Type` del punto 5.6.6.

#### 5.6.5 Riavvia e verifica

1. Riavvia con F12 → *Windows SSD esterno* e inserisci il PIN. Se usi il tastierino numerico, controlla che il Bloc Num sia attivo. Al primo riavvio BitLocker verifica il TPM, e solo dopo inizia a cifrare. Se per errore parte il sistema interno, il test aspetta semplicemente il prossimo avvio del Windows esterno.
2. Controlla lo stato:
   ```
   manage-bde -status C:
   ```
   Devi vedere la cifratura in corso, o completata, e le due protezioni: *TPM e PIN* e *password numerica*. La cifratura procede in background e riprende da sola dopo uno spegnimento.

#### 5.6.6 Conseguenze

- **Modifiche al BIOS o al firmware fanno chiedere la chiave di ripristino anche al Windows esterno.** Nell'ambiente di test gli eventi di BitLocker 813, 881 e 893 indicano che BitLocker non può usare Secure Boot per la verifica dell'integrità (PCR7), e usa quindi il profilo PCR 0, 2, 4, 11, che cambia con ogni modifica al BIOS o al firmware. Per controllare il profilo in uso, in sola lettura, nel *Prompt dei comandi come amministratore*:
  ```
  manage-bde -protectors -get C: -Type TPMAndPIN
  ```
  **Non usare mai `-get` senza `-Type`:** stampa anche la chiave di ripristino.
- **Gli aggiornamenti del BIOS sospendono la protezione.** Dopo quello del 30/10/2026, `manage-bde -status C:` mostrava la protezione disattivata. Finché è sospesa, l'SSD è leggibile da qualunque sistema: non avviare il sistema interno con il box collegato. Riattivala, nel *Prompt dei comandi come amministratore*:
  ```
  manage-bde -protectors -enable C:
  ```
- **Se la chiave viene chiesta a ogni avvio** anche dopo la riattivazione, una possibile soluzione, non verificata, è ricreare la protezione TPM e PIN: `manage-bde -protectors -delete C: -Type TPMAndPIN`, poi `manage-bde -protectors -add C: -TPMAndPIN`, che chiede il nuovo PIN.
- **Riparazione dalla sessione live.** La partizione risulta di tipo `BitLocker` invece che `ntfs`. Gli script `patch-windows-hive.sh` e `restore-hive-backup.sh` la riconoscono e chiedono la chiave di ripristino per sbloccarla con `cryptsetup`. Questa parte non è ancora stata verificata. A mano:
  ```
  sudo cryptsetup open --type bitlk /dev/nvme0n1p3 winssd
  sudo mount -t ntfs3 /dev/mapper/winssd /mnt/win
  # ... operazioni ...
  sync && sudo umount /mnt/win && sudo cryptsetup close winssd
  ```
- **Riparazione dall'ambiente di ripristino di Windows** (Fase 6): funziona anche con il disco cifrato. Serve la chiave di ripristino.
- **Prestazioni:** l'impatto è trascurabile. La cifratura usa le istruzioni AES del processore, molto più veloci del collegamento Thunderbolt.

### 5.7 Sospensione

Non è ancora stato verificato se il collegamento Thunderbolt sopravvive alla sospensione e all'ibernazione. Finché non l'hai provato con calma, spegni il PC invece di sospenderlo.

### 5.8 Punti di ripristino

**Obiettivo:** poter riportare Windows, con driver e programmi, a uno stato precedente funzionante usando solo strumenti ufficiali, senza toccare i file personali. Questi vanno salvati a parte, con un backup a livello di file.

**Ripristino configurazione di sistema** riporta file di sistema, registro, driver e programmi a un momento precedente. Il registro ripristinato comprende anche i valori `Start = 0` dei driver USB4, a condizione che il punto sia stato creato dopo la correzione della Fase 3. In Windows 11 è **disattivato di default**.

#### 5.8.1 Attivazione e primo punto

In PowerShell come amministratore:

```
Enable-ComputerRestore -Drive "C:\"
Checkpoint-Computer -Description "Configurazione completa" -RestorePointType MODIFY_SETTINGS
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=10%
```

- Il primo comando attiva la protezione del disco C:.
- Il secondo crea subito un punto di ripristino con un nome riconoscibile. Crealo quando Windows, driver e programmi sono configurati come vuoi.
- Il terzo riserva fino al 10% del disco ai punti di ripristino. Se risponde che non trova nessuna associazione, imposta lo spazio dall'interfaccia: `SystemPropertiesProtection` → **Configura** → cursore *Utilizzo massimo*.

Da qui in avanti Windows crea da solo un punto prima degli aggiornamenti e delle installazioni di driver.

**Nota:** di default `Checkpoint-Computer` non crea più di un punto ogni 24 ore. Se ne ha già creato uno, si limita a un avviso. Se vuoi poter creare punti manuali in qualsiasi momento, per esempio prima di installare un driver:

```
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f
```

#### 5.8.2 Uso

- **Con Windows funzionante:** Start → *Crea un punto di ripristino* → **Ripristino configurazione di sistema**, poi scegli il punto.
- **Se Windows non parte:** dall'ambiente di ripristino, in **Risoluzione dei problemi → Opzioni avanzate → Ripristino configurazione di sistema**. Con BitLocker attivo potrebbe chiederti la chiave di ripristino per sbloccare C:.

#### 5.8.3 Verifica dell'ambiente di ripristino

Controlla che l'ambiente di ripristino sia attivo e che stia sull'SSD esterno:

```
reagentc /info
```

Lo stato deve essere *Enabled*. Il percorso indica disco e partizione, per esempio `harddisk0\partition4\Recovery\WindowsRE`. Nel Windows esterno, con il disco interno nascosto (Fase 5.5), `harddisk0` è l'SSD esterno, e la partizione è una partizione di ripristino creata da Windows. Puoi confermarlo da `diskpart` con `list disk`, dove deve comparire un solo disco, poi `select disk 0` e `list partition`.

L'ambiente di ripristino, avviato dall'SSD Thunderbolt, vede la partizione di Windows: è stato verificato durante la riparazione descritta nella Fase 6. Gira dalla RAM come l'installer, e ricostruisce da solo il tunnel Thunderbolt.

**Prova consigliata, da fare una volta:** verifica che compaia il punto di ripristino. Il ripristino da un punto non è ancora stato provato.
1. `reagentc /boottore`, poi riavvia con F12 → *Windows SSD esterno*.
2. **Risoluzione dei problemi → Opzioni avanzate → Ripristino configurazione di sistema**: deve comparire il punto creato al punto 5.8.1.
3. **Annulla senza ripristinare**, poi scegli **Spegni il PC**. Riaccendi, premi F12 e scegli *Windows SSD esterno*. Non scegliere **Continua**: avvia la voce predefinita del firmware, cioè il sistema interno, con il box collegato.

#### 5.8.4 Limiti, e cosa non usare

- **I punti di ripristino stanno sullo stesso disco.** Non proteggono da guasto, perdita o furto dell'SSD, né da un file system danneggiato. Per questi casi ti serve un'immagine del disco, oppure reinstallare seguendo questa guida: con i file personali salvati a parte, è un'alternativa legittima.
- **Non usare "Reimposta il PC".** Reinstalla Windows togliendo driver e programmi, e ricrea il registro da zero. I driver USB4 tornerebbero a `Start = 3`, e già al primo riavvio della procedura comparirebbe `INACCESSIBLE_BOOT_DEVICE`: dovresti rifare la Fase 3 a metà dell'operazione.

### 5.9 Protezione dagli aggiornamenti: il servizio Usb4BootGuard (non verificato)

Un aggiornamento di Windows può riportare i driver USB4 a `Start = 3`, e allora Windows non parte più (Fase 6). Il reset avviene mentre Windows installa gli aggiornamenti prima di spegnersi, quando i servizi sono ancora attivi: vedi [how-it-works.it.md](how-it-works.it.md), sezione 6. Il servizio `Usb4BootGuard` sfrutta quel momento: si fa avvisare da Windows a ogni modifica delle chiavi dei due driver e rimette subito `Start = 0`. Controlla i valori anche all'avvio, ogni minuto e allo spegnimento.

**Stato:** provato con i test automatici in `windows/tests`, su un registro di prova, e con `-SelfTest` sul sistema in uso: `Start` riportato a 3 torna a 0 in pochi millisecondi. Non è ancora stato verificato con un aggiornamento reale: tieni pronti lo script di riparazione e la chiave di ripristino (Fase 6).

**Installazione.** In PowerShell aperto come amministratore, dalla cartella del repository:

```
powershell -ExecutionPolicy Bypass -File .\windows\usb4-boot-guard\usb4-boot-guard.ps1
```

Lo script compila il servizio con il compilatore C# incluso in Windows (.NET Framework 4), lo copia in `C:\Program Files\Usb4BootGuard`, lo registra con avvio automatico e lo avvia. Alla fine mostra lo stato: permessi e valori devono risultare `OK`.

Il servizio gira come `SYSTEM`, quindi il suo programma deve poterlo modificare solo un amministratore con diritti elevati. Ereditando i permessi da `Program Files` non basta: Windows dà il controllo completo a chi crea la cartella, cioè al tuo account, anche da un programma avviato senza diritti elevati. Lo script imposta quindi permessi espliciti (`SYSTEM` e `Administrators` con controllo completo, `Users` in sola lettura) e rende proprietario il gruppo `Administrators`. `-Status` controlla anche questo.

**Prova.** Subito dopo l'installazione:

```
powershell -ExecutionPolicy Bypass -File .\windows\usb4-boot-guard\usb4-boot-guard.ps1 -SelfTest
```

Lo script porta `Start` a 3 su ciascun driver e misura quanto ci mette il servizio a rimetterlo a 0. In ogni caso, prima di uscire, rimette `Start = 0` da solo: la prova non lascia il sistema in uno stato che impedisce l'avvio.

**Dopo ogni aggiornamento di Windows**, controlla cosa è successo:

```
powershell -ExecutionPolicy Bypass -File .\windows\usb4-boot-guard\usb4-boot-guard.ps1 -Status
```

`-Status` è in sola lettura e non richiede diritti di amministratore. Mostra lo stato del servizio, i permessi del programma, i valori e gli ultimi eventi del servizio nel registro Applicazione. Un evento con ID 2 (*Valore ripristinato*) indica che il servizio ha corretto un valore. Annota data e motivo (*modifica rilevata*, *controllo periodico*, *spegnimento*): servono a verificare se la protezione regge.

**Rimozione:** `usb4-boot-guard.ps1 -Uninstall` toglie il servizio e il programma. I valori nel registro restano come sono, e la sorgente degli eventi resta registrata, così gli eventi passati restano leggibili.

**Lingua:** come gli altri script per Windows, italiano o inglese secondo la lingua di sistema, forzabile con `/it` oppure `/en`.

**Limiti.**
- Se un aggiornamento reimpostasse i valori dopo l'arresto dei servizi, il servizio non lo vedrebbe: in quel caso resta la Fase 6.
- Un antivirus potrebbe segnalare un servizio che riscrive chiavi di sistema.
- Il servizio corregge solo i valori della correzione (`Start` dei due driver e `BootDriverFlags`), e non crea chiavi mancanti.

### 5.10 Blocca il software Dell che aggiorna il BIOS

**Perché.** Il 30/10/2026 un aggiornamento del BIOS è partito mentre il Windows esterno era acceso, e ha spento `ThunderboltBoot` (Fase 7). La causa molto probabile, non certa, è Dell SupportAssist, che risultava installato nel Windows esterno senza che lo avessimo scelto, insieme ad altri due componenti:

| Programma | Versione | Installato il |
|---|---|---|
| Dell Connected Service Delivery + SubAgent | 1.1.2 | 05/10 |
| Dell Core Services | 1.15.18 | 07/10 |
| Dell SupportAssist | 5.2.5 | 24/10 |

Dell Connected Service Delivery è un componente software (classe *SoftwareComponent*) agganciato a un dispositivo ACPI Dell dedicato, `ACPI\DELL0033`, e porta con sé il resto. Come sia arrivato non è accertato. L'esclusione dei driver da Windows Update (punto 5.1) era attiva, ma non impedisce a SupportAssist di aggiornare il BIOS per conto suo. Per questo, oltre a disinstallare i programmi, si blocca il dispositivo a cui si aggancia il componente, con la stessa regola usata per il driver VMD.

Tutti i comandi di questa sezione vanno lanciati in **PowerShell come amministratore**.

**1. Controlla.**

```
winget list Dell
```

**2. Disinstalla**, nell'ordine:

```
winget uninstall --name "Dell SupportAssist" --exact
winget uninstall --name "Dell Core Services" --exact
winget uninstall --name "Dell Connected Service Delivery SubAgent" --exact
winget uninstall --name "Dell Connected Service Delivery" --exact
```

Ripeti `winget list Dell` finché non resta nulla di questi programmi. Se compare un altro *SubAgent* Dell, disinstallalo allo stesso modo con il nome esatto mostrato da `winget` (da verificare: il 30/10 potrebbe esserne rimasto uno). Non è verificato che il software di controllo Dell (punto 5.4) funzioni senza Dell Core Services.

**3. Blocca i dispositivi.** Si aggiungono due ID alla regola `DenyDeviceIDs` del punto 5.5.2, continuando la numerazione dopo il VMD:

```
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 2 /t REG_SZ /d "SWC\VID001&PID0001&DCSDSoftware" /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 3 /t REG_SZ /d "ACPI\DELL0033" /f
```

Il blocco funziona solo con i valori `DenyDeviceIDs` e `DenyDeviceIDsRetroactive` impostati a 1, come al punto 5.5.2. Se non hai bloccato il driver VMD, imposta prima quei due valori con i primi due comandi del punto 5.5.2, e numera gli ID da 1.

**4. Rimuovi i dispositivi e i loro driver.** Individua i dispositivi Dell fra i componenti software:

```
Get-PnpDevice -Class SoftwareComponent | Format-Table Status, FriendlyName, InstanceId -AutoSize -Wrap
```

Poi trova i pacchetti di driver `dcsdsoftware.inf` e `dcsddriver.inf`: con `pnputil /enum-drivers` cerca le voci con questi nomi originali, e annota il nome pubblicato, del tipo `oemNN.inf`. Per vedere quali dispositivi usano un pacchetto:

```
pnputil /enum-devices /drivers | Select-String -Context 10,2 -Pattern 'oemNN.inf'
```

Rimuovi i due dispositivi, uno per volta, con l'ID istanza mostrato dai comandi precedenti, e poi i due pacchetti:

```
pnputil /remove-device "<ID istanza>"
pnputil /delete-driver oemNN.inf /uninstall /force
```

**5. Verifica.**

```
winget list Dell
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /s
Get-PnpDevice -Class SoftwareComponent | Format-Table Status, FriendlyName, InstanceId -AutoSize -Wrap
```

`winget` non deve più elencare i quattro programmi, e la regola deve contenere i tre ID: 1 = l'ID del controller VMD (punto 5.5.2), 2 = `SWC\VID001&PID0001&DCSDSoftware`, 3 = `ACPI\DELL0033`.

**Stato:** applicato il 30/10/2026, con esito positivo di tutti i comandi. Se il blocco regga nel tempo è da verificare: dopo gli aggiornamenti di Windows, ripeti ogni tanto `winget list Dell`.

**Per annullare:**

```
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 2 /f
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 3 /f
```

---

## Fase 6 — Se Windows non parte dopo un aggiornamento

**Sintomo**, osservato dopo un aggiornamento di Windows: al riavvio compare *Preparazione del ripristino automatico* e poi la schermata blu di BitLocker che chiede la chiave di ripristino. Nel menu F12 *Windows SSD esterno* è tornato al primo posto.

**Causa:** l'aggiornamento ha reinstallato i driver USB4 riportandoli a `Start = 3`, il valore predefinito. Windows va in `INACCESSIBLE_BOOT_DEVICE`, si riavvia da solo e avvia il ripristino automatico, che non sa correggere il problema. La schermata di BitLocker appartiene all'ambiente di ripristino: per accedere al disco serve la chiave di ripristino, il PIN lì non vale.

**Riparazione:** dall'ambiente di ripristino di Windows, che si avvia dall'SSD e lo vede. Non serve la sessione live di Ubuntu.

### 6.1 Preparazione, una volta sola

Copia [`windows/repair-usb4-boot.bat`](../windows/repair-usb4-boot.bat) e [`windows/thunderbolt-boot-on.vbs`](../windows/thunderbolt-boot-on.vbs) in `C:\Repair\` nel Windows esterno (Fase 5.1). Nell'ambiente di ripristino la stessa cartella compare di solito come `D:\Repair\`. Per provarli senza modificare nulla: `C:\Repair\repair-usb4-boot.bat /check`.

### 6.2 Arriva al prompt dei comandi

1. Sulla schermata di BitLocker controlla che l'**ID chiave di ripristino** corrisponda a quello salvato (Fase 5.6.4). Inserisci la chiave di 48 cifre, solo i numeri (i trattini si aggiungono da soli), e premi **Continua**: è il pulsante di questa schermata, non la voce *Continua* del menu, da evitare all'uscita (punto 6.4).
2. Dalla schermata del ripristino automatico scegli **Opzioni avanzate → Risoluzione dei problemi → Opzioni avanzate → Prompt dei comandi**. È l'ordine verificato. Se viene chiesta la chiave di ripristino, inseriscila. Se il ripristino automatico riavvia il PC e torna alla schermata di BitLocker, scegli **Ignora questa unità** e prosegui dallo stesso menu.
3. Nel prompt individua l'unità di Windows. Nell'ambiente di ripristino la lettera può essere diversa da C: (nei test era **D:**); `X:` è l'ambiente di ripristino stesso. Questo prompt è un `cmd` **senza PowerShell** e senza `where`: usa solo i comandi indicati qui.
   ```
   manage-bde -status
   dir D:\Windows
   ```
   Se il volume risulta *Bloccato*, sbloccalo:
   ```
   manage-bde -unlock D: -RecoveryPassword CHIAVE-DI-48-CIFRE
   ```

### 6.3 Correggi i valori

Con lo script:

```
D:\Repair\repair-usb4-boot.bat
```

Lo script corregge l'installazione che si trova sulla sua stessa unità:
1. carica il registro offline e mostra i tre valori, ciascuno con l'esito;
2. se sono già corretti lo dice, e non scrive nulla; altrimenti chiede conferma (`SI`), li corregge, mostra i valori dopo la correzione e li verifica;
3. scarica il registro, riprovando una seconda volta se serve;
4. se `thunderbolt-boot-on.vbs` è nella stessa cartella, controlla `ThunderboltBoot`. Se è spento chiede conferma e lo attiva (Fase 7);
5. alla fine elenca i passi successivi, gli stessi del punto 6.4.

Con `/check` fa solo i controlli, senza domande e senza scrivere nulla, ed esce con 0 se è tutto a posto, 2 se c'è qualcosa da correggere, 1 in caso di errore.

Lo script parla italiano se la lingua di sistema è l'italiano, altrimenti inglese; puoi forzare la lingua con `/it` oppure `/en`, per esempio `repair-usb4-boot.bat /en`. In inglese chiede `YES` invece di `SI`, e accetta entrambe le risposte. Se lo lanci da una chiavetta, indica la lettera dell'unità di Windows come argomento, per esempio `repair-usb4-boot.bat D:`. Uso completo: `repair-usb4-boot.bat [unità:] [/check] [/it oppure /en]`.

**Stato:** la versione precedente dello script, senza `/check` e senza il controllo di `ThunderboltBoot`, è stata verificata in WinRE il 30/10/2026. La versione attuale è stata provata il 30/10/2026 da Windows avviato con `/check`, e in WinRE con `/check`, con l'unità come argomento e in modalità normale, su un disco cifrato con i valori già corretti: ha controllato tutto senza scrivere nulla. Una correzione vera e propria, dei valori o di `ThunderboltBoot`, con la versione attuale non è ancora stata provata.

Senza script, gli stessi comandi a mano:

```
reg load HKLM\OFF D:\Windows\System32\config\SYSTEM
reg query HKLM\OFF\Select /v Current
reg query HKLM\OFF\ControlSet001\Services\Usb4HostRouter /v Start
reg query HKLM\OFF\ControlSet001\Services\Usb4DeviceRouter /v Start
reg add HKLM\OFF\ControlSet001\Services\Usb4HostRouter /v Start /t REG_DWORD /d 0 /f
reg add HKLM\OFF\ControlSet001\Services\Usb4DeviceRouter /v Start /t REG_DWORD /d 0 /f
reg query HKLM\OFF\ControlSet001\Control /v BootDriverFlags
reg unload HKLM\OFF
```

- `Current` deve valere `0x1`, cioè `ControlSet001`. Se vale `0x2`, sostituisci `ControlSet001` con `ControlSet002` in tutti i comandi.
- Se `BootDriverFlags` non è `0x14`, impostalo con `reg add HKLM\OFF\ControlSet001\Control /v BootDriverFlags /t REG_DWORD /d 0x14 /f`. Da solo non basta a far partire Windows, ma fa parte della configurazione verificata.
- **Non dimenticare `reg unload`:** senza, le modifiche potrebbero non essere salvate.

### 6.4 Riavvia e rimetti in ordine

1. Scrivi `exit` e scegli **Spegni il PC**. **Non scegliere *Continua***: avvia la voce predefinita del firmware, cioè il sistema interno, e il 30/10/2026 lo ha fatto davvero, con il box collegato e la protezione BitLocker dell'SSD sospesa.
2. Riaccendi, premi F12 e scegli la voce del Windows esterno. Se `ThunderboltBoot` è appena stato attivato (Fase 7), prima ricollega il box alla porta Thunderbolt con il cavo Thunderbolt.
3. Inserisci il PIN, oppure la chiave di ripristino se il BIOS è cambiato.
4. In Windows, nel *Prompt dei comandi come amministratore*:
   ```
   reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4HostRouter /v Start
   reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4DeviceRouter /v Start
   bcdedit /set {fwbootmgr} displayorder {bootmgr} /addlast
   manage-bde -status C:
   ```
   I primi due devono mostrare `0x0`. Il terzo rimette in fondo la voce del Windows esterno, così l'avvio predefinito torna al sistema interno. Se l'ultimo mostra la protezione disattivata, riattivala con `manage-bde -protectors -enable C:` (punto 5.6.6).

---

## Fase 7 — Se l'SSD sparisce dal menu F12 dopo un aggiornamento o un azzeramento del BIOS

**Sintomo**, osservato il 30/10/2026 dopo un aggiornamento del BIOS: nel menu F12 restano solo *Windows Boot Manager*, il disco interno e *HTTPs Boot*, e le voci dell'SSD sono sparite. Le impostazioni del BIOS sono tornate ai valori predefiniti, compreso il limite di carica della batteria. Nel Windows esterno, una volta ripartito, la protezione BitLocker risulta sospesa. Durante quell'aggiornamento sono comparsi anche *This boot will take longer than usual* e *Unrecoverable SPI Error* (codice 3,6), poi il BIOS è ripartito con la versione nuova.

**Causa:** `ThunderboltBoot` è tornato `Disabled`. Senza, il firmware non crea il tunnel Thunderbolt prima del boot, non vede l'SSD e ne elimina le voci di avvio. Non sappiamo se ogni aggiornamento del BIOS riporta le impostazioni ai valori predefiniti, o se è successo per l'errore SPI. Lo stesso vale per un azzeramento delle impostazioni del BIOS, e per un aggiornamento fatto dal sistema interno.

**Riparazione, senza Ubuntu:** con il box in modalità USB il firmware vede l'SSD anche senza `ThunderboltBoot`. Windows in quella modalità non parte, ma l'ambiente di ripristino sì, e da lì si riattiva `ThunderboltBoot` con l'interfaccia WMI del BIOS. Tutti i passi qui sotto sono stati verificati il 30/10/2026, salvo dove indicato.

**Cosa serve:**
- un **cavo USB-C → USB-A** e una porta USB-A del notebook;
- la **chiave di ripristino** dell'SSD esterno, con il suo ID (punto 5.6.4);
- gli script in `C:\Repair\` (punto 5.1). Se non ci sono, il punto 7.2 spiega come scrivere a mano il VBScript minimo.

### 7.1 Raggiungi l'ambiente di ripristino in modalità USB

1. A PC spento, collega il box con il **cavo USB-C → USB-A a una porta USB-A**. Così il box lavora in modalità USB, attraverso il suo chip Realtek, e il firmware vede l'SSD senza `ThunderboltBoot`. Con un cavo USB-C su una porta Thunderbolt il box negozia comunque il Thunderbolt, e il firmware non lo vede.
2. Accendi e premi F12. Deve comparire una voce del tipo *UEFI Realtek ACASIS …*: sceglila. Se non compare, il problema è il cavo o la porta.
3. Windows **non parte** in modalità USB: va in `INACCESSIBLE_BOOT_DEVICE`, ed è il comportamento atteso. Dopo i tentativi falliti compare il ripristino automatico, e l'ambiente di ripristino invece parte.
4. BitLocker chiede la chiave di ripristino: controlla l'ID e inseriscila. Dopo averla inserita, nel prompt il volume risulta già sbloccato.
5. Dalla schermata del ripristino automatico: **Opzioni avanzate → Risoluzione dei problemi → Opzioni avanzate → Prompt dei comandi**. Nel prompt l'unità di Windows era `D:`; `X:` è l'ambiente di ripristino stesso. Controlla con `dir D:\Windows`, e se il volume è bloccato sbloccalo come al punto 6.2.

### 7.2 Riattiva ThunderboltBoot

Tutti i comandi vanno lanciati nel *prompt di WinRE*.

**Con lo script di riparazione (strada principale).**

```
D:\Repair\repair-usb4-boot.bat
```

Lo script controlla prima il registro: il 30/10/2026 i valori erano già corretti, e in quel caso non scrive nulla. Poi legge `ThunderboltBoot` con `thunderbolt-boot-on.vbs`: se è `Disabled`, rispondi `SI` per attivarlo. La versione attuale dello script è stata provata in WinRE il 30/10/2026, ma solo con i valori già corretti e `ThunderboltBoot` già `Enabled`: l'attivazione da parte dello script non è ancora stata provata, mentre la scrittura con WMI dall'ambiente di ripristino è verificata (alternativa qui sotto).

**A mano, con `wmic` e lo script VBScript (alternativa).** Leggi il valore, in sola lettura:

```
wmic /namespace:\\root\dcim\sysman\biosattributes path EnumerationAttribute where "AttributeName='ThunderboltBoot'" get AttributeName,CurrentValue
```

Il 30/10/2026 il risultato era `Disabled`: `ThunderboltBoot` esiste anche dopo l'aggiornamento. Attivalo e rileggi:

```
cscript //nologo D:\Repair\thunderbolt-boot-on.vbs
```

Lo script deve rispondere `Status = 0`, e la rilettura deve dare `Enabled`. Il 30/10/2026 la rilettura con `wmic` ha dato `Enabled` subito.

**Se gli script non ci sono**, scrivi il VBScript minimo con `notepad`. Il comando `notepad D:\Repair\thunderbolt-boot-on.vbs` apre il file, e chiede di crearlo se non esiste (se manca la cartella, prima `mkdir D:\Repair`). Scrivi:

```vbscript
Set s = GetObject("winmgmts:\\.\root\dcim\sysman\biosattributes")
For Each o In s.ExecQuery("SELECT * FROM BiosAttributeInterface")
  Set p = o.Methods_("SetAttribute").InParameters.SpawnInstance_()
  p.SecType = 0
  p.SecHndCount = 0
  p.AttributeName = "ThunderboltBoot"
  p.AttributeValue = "Enabled"
  Set r = o.ExecMethod_("SetAttribute", p)
  WScript.Echo "Status = " & r.Status
Next
```

Salva, chiudi `notepad` e lancia `cscript //nologo D:\Repair\thunderbolt-boot-on.vbs`. Attenzione a `o.ExecMethod_`: è la lettera **o**, non lo zero. Scritto `0.ExecMethod_`, VBScript risponde con un errore. Poi rileggi con `wmic`.

Significato di `Status`: 0 riuscito, 1 non riuscito, 3 accesso negato perché è impostata una password di amministratore del BIOS. In quest'ultimo caso, senza la password non si può fare nulla: se il PC non è tuo, chiedi a chi lo gestisce.

### 7.3 Torna al Windows esterno

1. Scrivi `exit`, poi scegli **Spegni il PC**. Non scegliere *Continua*: avvia la voce predefinita del firmware, cioè il sistema interno.
2. Ricollega il box con il **cavo Thunderbolt alla porta Thunderbolt**.
3. Accendi e premi F12: deve ricomparire la voce dell'SSD, per esempio *UEFI WD_BLACK SN850X …*. Sceglila: Windows parte via Thunderbolt. Inserisci il PIN, oppure la chiave di ripristino se la richiede: il BIOS è cambiato (punto 5.6.6).
4. In Windows, nel *Prompt dei comandi come amministratore*:
   - riattiva la protezione BitLocker, che l'aggiornamento del BIOS ha sospeso: `manage-bde -status C:`, poi `manage-bde -protectors -enable C:`;
   - rimetti in ordine le voci di avvio come al punto 5.2. Windows ricrea la propria voce e la mette al primo posto.

Non verificato: il riavvio con il PIN dopo la riattivazione della protezione.

### 7.4 Lista di controllo dopo un aggiornamento o un azzeramento del BIOS

Vale anche quando il BIOS viene aggiornato dal sistema interno.

- [ ] `ThunderboltBoot` = `Enabled` (`C:\Repair\repair-usb4-boot.bat /check` da amministratore, oppure `wmic` come al punto 7.2).
- [ ] `PreBootDma` (*Pre-Boot DMA Support*) e Secure Boot attivi, nel BIOS (F2).
- [ ] Limite di carica della batteria: *Battery Charge Configuration* = *Custom*, con inizio 65 e fine 70. Dell richiede almeno 5 punti di differenza; la scelta dei test è il 70%. Non verificato che l'impostazione sia stata ripristinata.
- [ ] Ordine di avvio con `bcdedit` (punto 5.2).
- [ ] Protezione BitLocker attiva (`manage-bde -status C:`).

**Non usare *Save as Custom User Settings*** all'uscita dal BIOS: sovrascriverebbe un eventuale profilo personalizzato già salvato, e non è dimostrato che sopravviva a un aggiornamento.

### 7.5 Il menu F12: *Pre-Boot Tasks*

Il menu F12 ha una sezione *Pre-Boot Tasks*:
- **da usare:** *BIOS Setup*; *Diagnostics*, che fa test di sola lettura ed è utile dopo errori come *Unrecoverable SPI Error*;
- **da evitare:** *BIOS Update* e *BIOS Flash Update – Remote*, perché un aggiornamento del BIOS può spegnere `ThunderboltBoot`, come il 30/10/2026; se il PC è gestito da qualcun altro, la versione del BIOS la decide chi lo gestisce; *SupportAssist OS Recovery*, che ripristina il sistema del disco interno;
- ***Device Configuration***: non sappiamo cosa contenga. Va esplorata solo in sola lettura.

---

## Regole d'uso quotidiano

1. **Collega il box prima di accendere** il notebook, poi F12 → *Windows SSD esterno*. Come riserva c'è la voce del firmware *UEFI* seguita dal modello dell'SSD.
2. **Non scollegare mai il box con Windows acceso:** è il disco di sistema.
3. **Scollega il box prima di avviare il sistema interno.** Con `ThunderboltBoot` attivo, un box collegato all'accensione viene autorizzato in automatico, e il sistema interno vedrebbe l'SSD. Vale a maggior ragione se la protezione BitLocker dell'SSD è sospesa, per esempio dopo un aggiornamento del BIOS: in quel caso il sistema interno potrebbe leggerne i file.
4. **Dopo un aggiornamento di Windows**, se compare il ripristino automatico o la schermata di BitLocker che chiede la chiave, segui la Fase 6. Ricontrolla anche l'ordine di avvio (Fase 5.2). Se hai installato `Usb4BootGuard`, controlla i suoi eventi con `-Status` (Fase 5.9), anche quando Windows è ripartito senza problemi.
5. **Dopo un aggiornamento o un azzeramento del BIOS**, anche fatto dal sistema interno, segui la Fase 7: se l'SSD è sparito dal menu F12 riattiva `ThunderboltBoot`, poi passa la lista di controllo del punto 7.4.
6. **Niente aggiornamenti del BIOS dal Windows esterno**, né da Windows Update né dai programmi Dell (punti 5.1, 5.4 e 5.10). In WinRE, dopo `exit`, scegli sempre **Spegni il PC** e mai *Continua*.
7. **Prima di modifiche importanti**, come un nuovo driver o un programma di sistema, crea un punto di ripristino (Fase 5.8).

---

## Se ThunderboltBoot non è disponibile

- **Windows in modalità USB: non funziona.** Il box ACASIS ha anche un bridge Realtek USB. Se lo colleghi a una porta USB-A con un cavo USB-C → USB-A, il firmware lo vede come disco USB anche senza `ThunderboltBoot`, e nel menu F12 compare *UEFI Realtek ACASIS …*. Il 30/10/2026, però, in modalità USB l'ambiente di ripristino è partito e Windows no: si è fermato con `INACCESSIBLE_BOOT_DEVICE`. La causa non è chiarita. La modalità USB serve quindi solo a raggiungere l'ambiente di ripristino (Fase 7).
- **Linux.** Linux può avviarsi da un SSD Thunderbolt anche senza supporto del firmware: si mettono ESP e `/boot` su una chiavetta, e il kernel crea il tunnel da solo grazie al modulo `thunderbolt` nell'initramfs. Non verificato in questa guida.
