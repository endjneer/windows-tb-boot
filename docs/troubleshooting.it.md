**🌐 Lingua:** [English](troubleshooting.md) · **Italiano**

# Problemi frequenti

Per ogni problema: il sintomo, la causa più probabile e la soluzione.

---

### L'SSD non compare nel menu F12 né nel File Explorer del BIOS

- **`ThunderboltBoot` non è attivo.** Verificalo in uno di questi modi:
  - dalla sessione live, con `./scripts/check-bios.sh`;
  - dal Windows esterno, nel Prompt dei comandi come amministratore, con `cscript //nologo C:\Repair\thunderbolt-boot-on.vbs /status`;
  - dal prompt dell'ambiente di ripristino, con `cscript //nologo D:\Repair\thunderbolt-boot-on.vbs /status`, oppure con `wmic` (guida, punto 7.2).

  `/status` esce con 0 se è `Enabled`, 2 se non lo è, 1 in caso di errore. Se è spento dopo un aggiornamento o un azzeramento del BIOS, vedi la voce successiva.
- **Il box è stato collegato dopo l'accensione.** Spegni, collega il box e riaccendi.
- **Il box sta funzionando in modalità USB.** Con il box ACASIS dei test succede solo con un cavo USB-C → USB-A su una porta USB-A: in F12 compare *UEFI Realtek ACASIS …* invece della voce dell'SSD, e Windows non parte. Usa il cavo Thunderbolt e una porta Thunderbolt. Dalla sessione live, `boltctl list` deve mostrare il box con lo stato `authorized` e una velocità di 40 Gb/s.

---

### Dopo un aggiornamento del BIOS l'SSD è sparito dal menu F12

Nel menu restano solo *Windows Boot Manager*, il disco interno e *HTTPs Boot*. L'aggiornamento, o un azzeramento delle impostazioni, ha riportato `ThunderboltBoot` a `Disabled`. Si ripara senza Ubuntu, dall'ambiente di ripristino raggiunto in modalità USB: Fase 7 di [guide.it.md](guide.it.md), oppure la versione breve in [quick-recovery.it.md](quick-recovery.it.md). Poi passa la lista di controllo del punto 7.4.

---

### La voce *UEFI Realtek …* non compare nel menu F12

È il cavo. Con un cavo USB-C su una porta Thunderbolt il box negozia comunque il Thunderbolt, e senza `ThunderboltBoot` il firmware non lo vede. Per la modalità USB serve un cavo **USB-C → USB-A** collegato a una porta **USB-A**. Collega il box a PC spento.

---

### In modalità USB Windows non parte

È il comportamento atteso: in modalità USB Windows si ferma con `INACCESSIBLE_BOOT_DEVICE`, mentre l'ambiente di ripristino parte. La causa non è chiarita. La modalità USB serve solo a raggiungere l'ambiente di ripristino per riattivare `ThunderboltBoot` (Fase 7).

---

### La voce aggiunta con *Add Boot Option* non compare nell'elenco

Particolarità di questo BIOS. Togli e rimetti la spunta a una delle voci, premi **Apply Changes**, esci dal BIOS e rientra.

---

### *ERROR: Invalid Parameters* quando aggiungo la voce

Mancano il file o il nome della voce. Devi selezionare il file **e** scrivere il nome in *Boot Option Name*.

---

### Scelgo l'SSD dal menu F12, ma parte il sistema interno

Quasi sempre Windows è partito dall'SSD, è andato in schermata blu e si è riavviato sulla voce predefinita. Per vederlo:
1. nel BIOS togli la spunta a tutte le voci tranne quella dell'SSD;
2. riavvia senza premere nulla e guarda cosa compare;
3. alla fine rimetti le spunte, con la voce del sistema interno al primo posto.

---

### Schermata blu `INACCESSIBLE_BOOT_DEVICE` (0x7B)

- **La correzione del registro non è stata applicata**, oppure è stata applicata a un'altra installazione. Ripeti la Fase 3 e controlla l'output della verifica.
- **Un aggiornamento di Windows ha riportato `Start` a 3.** Ripara dall'ambiente di ripristino di Windows, come descritto nella Fase 6 di [guide.it.md](guide.it.md): non serve Ubuntu.

---

### Dopo il Setup parte da solo il Windows esterno, e nel menu F12 ci sono due *Windows Boot Manager*

Alla fine del Setup, Windows ha registrato nel firmware la propria voce e l'ha messa al primo posto. Dal BIOS le due voci non si distinguono: rimetti l'ordine da Windows con `bcdedit`, come descritto al punto 5.2 di [guide.it.md](guide.it.md).

---

### Dopo un riavvio *Windows SSD esterno* sparisce dal menu F12, e la voce di Windows torna al primo posto

È il ciclo delle voci doppie. La voce creata a mano alla Fase 4 e quella di Windows puntano allo stesso file. Il firmware ne elimina una all'accensione, e Windows, avviandosi, ricrea la propria e la rimette in cima. Elimina la voce manuale e rimetti in ordine quella di Windows, come descritto al punto 5.2 di [guide.it.md](guide.it.md).

---

### `bcdedit` risponde "Il tipo di voce specificato non è valido", oppure `/enum` non stampa nulla

Succede di solito incollando più comandi insieme: due righe finiscono attaccate, oppure gli output si mescolano. Scrivi o incolla un comando per volta.

---

### `sc qc Usb4HostRouter | findstr START_TYPE` non mostra nulla

Su Windows in italiano l'output di `sc qc` è tradotto, e la riga non contiene `START_TYPE`. Usa un controllo che non dipende dalla lingua:

```
reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4HostRouter /v Start
```

---

### Dopo un aggiornamento compare *Preparazione del ripristino automatico* e poi BitLocker chiede la chiave di ripristino

L'aggiornamento ha riportato i driver USB4 a `Start = 3`, e Windows non raggiunge più il disco. Inserisci la chiave di ripristino, apri il Prompt dei comandi dall'ambiente di ripristino (**Opzioni avanzate → Risoluzione dei problemi → Opzioni avanzate → Prompt dei comandi**) e lancia `D:\Repair\repair-usb4-boot.bat`, oppure i comandi manuali: Fase 6 di [guide.it.md](guide.it.md), o la versione breve in [quick-recovery.it.md](quick-recovery.it.md).

---

### Dopo `exit` e *Continua* parte il sistema interno

*Continua* avvia la voce predefinita del firmware, cioè il sistema interno, non il Windows esterno. È successo nei test, con il box collegato e la protezione BitLocker dell'SSD sospesa. Esci sempre con `exit`, poi **Spegni il PC**, e riaccendi con F12 sulla voce del Windows esterno.

---

### Nel prompt dell'ambiente di ripristino `powershell` e `where` non vengono riconosciuti

È normale: l'ambiente di ripristino (build 26100) non ha PowerShell né `where`. Ha `reg`, `wmic`, `cscript` (VBScript), `notepad`, `manage-bde` e `bcdedit`. Gli script di questo repository usati in WinRE (`repair-usb4-boot.bat` e `thunderbolt-boot-on.vbs`) usano solo questi strumenti.

---

### Un comando risponde che non è riconosciuto come comando interno o esterno

Se il comando è PowerShell, per esempio `Get-PnpDevice`, `Get-Tpm` o un filtro con `Select-String`, l'hai lanciato nel Prompt dei comandi. È stato l'errore più frequente nei test. Apri **PowerShell come amministratore**. La guida indica per ogni blocco di comandi dove va lanciato (sezione *Convenzioni*).

---

### `repair-usb4-boot.bat /check` risponde che con Windows avviato corregge solo il sistema in uso

In `C:\Repair\` c'è ancora la versione dello script precedente al 30/10/2026: non conosce `/check`, lo prende per una lettera di unità e si ferma con un errore, senza leggere né scrivere nulla. È successo durante le prove del 30/10/2026. Copia di nuovo in `C:\Repair\` entrambi gli script dalla cartella `windows\` del repository e, prima di lanciarli, controlla in *PowerShell* che le copie siano identiche agli originali, dalla cartella del repository:

```
Get-FileHash C:\Repair\repair-usb4-boot.bat, .\windows\repair-usb4-boot.bat, C:\Repair\thunderbolt-boot-on.vbs, .\windows\thunderbolt-boot-on.vbs
```

Gli hash devono coincidere a coppie.

---

### `thunderbolt-boot-on.vbs` dice che l'interfaccia WMI del BIOS non è disponibile, o che l'accesso è negato

- **Accesso negato** (`0x80041003`): in Windows serve un Prompt dei comandi aperto come amministratore. Con `repair-usb4-boot.bat /check` senza diritti di amministratore è normale: lo script lo segnala e non lo considera un errore.
- **Interfaccia non disponibile**: il PC potrebbe non essere un Dell compatibile, cioè senza lo spazio dei nomi WMI `root\dcim\sysman\biosattributes`.

---

### Lo script del BIOS risponde `Status = 3`

Accesso negato: è impostata una password di amministratore del BIOS, e senza di essa l'attributo non si può modificare. Né gli script né la guida gestiscono la password. Se il PC non è tuo, chiedi a chi lo gestisce: non tentare di aggirarla.

---

### Il VBScript scritto a mano dà un errore sulla riga con `ExecMethod_`

Probabilmente hai scritto `0.ExecMethod_`, con lo zero, invece di `o.ExecMethod_`, con la lettera **o**. È successo nei test. Correggi la riga con `notepad` e rilancia lo script. Lo script completo è nella guida, punto 7.2.

---

### Dopo un aggiornamento del BIOS BitLocker risulta con la protezione disattivata

Gli aggiornamenti del BIOS sospendono la protezione BitLocker, e `manage-bde -status C:` la mostra disattivata. Finché è sospesa, l'SSD è leggibile da qualunque sistema: non avviare il sistema interno con il box collegato. Riattivala nel Prompt dei comandi come amministratore:

```
manage-bde -protectors -enable C:
```

---

### BitLocker chiede la chiave di ripristino a ogni avvio

Dopo una modifica al BIOS è normale che la chieda una volta: BitLocker usa il profilo PCR 0, 2, 4, 11, che cambia con il firmware (punto 5.6.6 di [guide.it.md](guide.it.md)). Per controllare il profilo, in sola lettura: `manage-bde -protectors -get C: -Type TPMAndPIN`. **Mai `-get` senza `-Type`:** stampa la chiave di ripristino.

Se continua a chiederla a ogni avvio, una possibile soluzione, **non verificata**, è ricreare la protezione TPM e PIN, nel Prompt dei comandi come amministratore:

```
manage-bde -protectors -delete C: -Type TPMAndPIN
manage-bde -protectors -add C: -TPMAndPIN
```

Il secondo comando chiede il nuovo PIN.

---

### `reg load` o `reg query` rispondono "sintassi non valida", oppure `req` non è riconosciuto

Errori di battitura. Il comando è `reg`, e il percorso della chiave va scritto tutto attaccato, con le barre rovesciate: `HKLM\OFF\Select`, non `HKLM\OFF Select`.

---

### Nella configurazione iniziale non c'è nessuna rete disponibile

Windows non ha il driver della scheda Wi-Fi. Scegli **Non ho Internet** e completa la configurazione con un account locale: è comunque il percorso consigliato. Per i driver vedi il punto 5.3 di [guide.it.md](guide.it.md).

---

### Windows Update ha installato un aggiornamento *Dell Inc. – Firmware*

Gli aggiornamenti del firmware vengono applicati al riavvio successivo, e il BIOS è condiviso con il sistema del disco interno. Se il PC non è tuo, avvisa chi lo gestisce **prima di riavviare**: un aggiornamento del BIOS può far chiedere la recovery key di BitLocker al sistema interno, e può riportare `ThunderboltBoot` al valore predefinito (Fase 7 di [guide.it.md](guide.it.md)). In futuro, per evitarlo, escludi driver e firmware da Windows Update (punto 5.1) e blocca il software Dell che aggiorna il BIOS (punto 5.10).

---

### Il software Dell è ricomparso

`winget list Dell` elenca di nuovo SupportAssist, Dell Core Services o Dell Connected Service Delivery. Controlla che la regola di blocco contenga ancora gli ID `SWC\VID001&PID0001&DCSDSoftware` e `ACPI\DELL0033`, con `reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /s`, poi ripeti disinstallazione e rimozione come al punto 5.10 di [guide.it.md](guide.it.md). La tenuta del blocco nel tempo non è ancora verificata: annota quando e come è ricomparso.

---

### La batteria torna a caricarsi al 100%

Un aggiornamento o un azzeramento del BIOS ha riportato al valore predefinito anche il limite di carica. Nel BIOS (F2) imposta *Battery Charge Configuration* = *Custom*, con inizio 65 e fine 70: Dell richiede almeno 5 punti di differenza. È una delle voci della lista di controllo del punto 7.4 di [guide.it.md](guide.it.md).

---

### Durante un aggiornamento del BIOS compare *Unrecoverable SPI Error*

È successo il 30/10/2026 (codice 3,6), insieme a *This boot will take longer than usual*, e poi il BIOS è ripartito con la versione nuova. **Non spegnere il PC durante l'aggiornamento.** Se il BIOS riparte, lancia *Diagnostics* dal menu F12 (*Pre-Boot Tasks*), che fa test di sola lettura, poi segui la Fase 7 di [guide.it.md](guide.it.md).

---

### Dalla sessione live la partizione di Windows risulta `BitLocker` e non si monta

Dopo la cifratura (punto 5.6 di [guide.it.md](guide.it.md)) la partizione va sbloccata prima del mount. Gli script `patch-windows-hive.sh` e `restore-hive-backup.sh` lo fanno da soli e chiedono la chiave di ripristino (48 cifre, con i trattini). A mano:

```
sudo cryptsetup open --type bitlk /dev/nvme0n1p3 winssd
sudo mount -t ntfs3 /dev/mapper/winssd /mnt/win
```

Alla fine: `sync && sudo umount /mnt/win && sudo cryptsetup close winssd`. Questa procedura non è ancora stata verificata su questa configurazione.

---

### Il disco interno è comparso nel Windows esterno

Il Windows esterno ha ricevuto il driver Intel RST/VMD, da un pacchetto Dell, da un installer del chipset o da Windows Update. Come misura immediata mettilo offline con `diskpart`. Poi blocca il driver VMD, come descritto al punto 5.5 di [guide.it.md](guide.it.md): il disco sparisce del tutto e il driver non può più essere reinstallato.

---

### Dopo "Reimposta il PC" compare `INACCESSIBLE_BOOT_DEVICE`

"Reimposta il PC" ricrea il registro da zero, quindi i driver USB4 tornano a `Start = 3`. Riapplica la correzione dall'ambiente di ripristino (Fase 6), poi riprendi la procedura. In questa configurazione, per tornare indietro con driver e programmi, usa i punti di ripristino (punto 5.8 di [guide.it.md](guide.it.md)).

---

### `hivexregedit: command not found`

`hivexregedit` è nel pacchetto `libwin-hivex-perl`, non in `libhivex-bin`. Installalo con `sudo apt install -y libwin-hivex-perl`. Lo script `patch-windows-hive.sh` lo fa in automatico.

---

### `\HardwareConfig: path not found in this hive`

È normale su un'installazione che non ha mai completato un avvio: Windows crea quella chiave al primo avvio riuscito. Gli script di questo repository non la usano.

---

### Il mount della partizione NTFS fallisce

Se il volume risulta "dirty", per esempio dopo una schermata blu, riprova con `FORCE=1 ./scripts/patch-windows-hive.sh /dev/nvme0n1p3`. Se Windows è stato ibernato, non forzare il mount: avvia Windows, spegnilo completamente e riprova.

---

### Il disco interno compare nella sessione live

Non hai aggiunto `modprobe.blacklist=vmd` alla riga `linux` di GRUB: il parametro va aggiunto a ogni avvio. Se il BIOS è in modalità AHCI/NVMe, il parametro non ha effetto: identifica i dischi da dimensione e modello con `lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL`.

---

### Il Windows interno chiede la recovery key di BitLocker

La modifica al BIOS ha cambiato le misure che BitLocker controlla all'avvio. Inserisci la recovery key: se il PC non è tuo, chiedila a chi lo gestisce. Dopo il primo avvio riuscito il problema non si ripresenta, finché il BIOS non cambia di nuovo.

---

### `check-bios.sh` dice che `ThunderboltBoot` non esiste

Lo stesso vale se lo dice `thunderbolt-boot-on.vbs`. Il firmware del tuo modello non ha l'opzione, oppure la versione del BIOS è diversa: sul notebook dei test l'attributo c'è sia prima sia dopo l'aggiornamento del BIOS del 30/10/2026. Questa procedura non è applicabile: vedi le alternative in fondo a [guide.it.md](guide.it.md).

---

### `check-bios.sh` dice che è attiva una password di amministratore del BIOS

Senza quella password non si possono modificare gli attributi. Se non la conosci, chiedila a chi gestisce il PC: non tentare di aggirarla.

---

### Dopo la sospensione lo schermo resta nero e le ventole girano

Il notebook non esce dalla sospensione: le ventole girano, lo schermo resta nero, e si spegne solo tenendo premuto il pulsante di accensione. In altri casi Windows riparte, ma poco dopo va in schermata blu `CRITICAL_PROCESS_DIED` (0xEF) o `UNEXPECTED_STORE_EXCEPTION` (0x154).

**Cosa è stato osservato** sul notebook dei test, dal 5/10 al 10/11/2026, nei registri di Windows:
- il firmware supporta solo lo standby moderno (S0). Lo standby classico (S3) non c'è, quindi non è un'alternativa;
- 187 cicli di standby moderno, con tre schermate blu tra pochi minuti e mezz'ora dopo una ripresa (0xEF il 15/10, 0x154 il 23/10 e il 26/10);
- ibernazione **bloccata in due tentativi su due** (16/10 e 6/11). Entrambe le volte Windows è uscito dallo standby per passare all'ibernazione (motivo *Sleep, Hibernate, or Shutdown* dell'evento 507) e si è fermato lì, con lo schermo nero e le ventole accese, fino allo spegnimento forzato. L'evento 41 successivo riporta `SleepInProgress = 5`, cioè un passaggio all'ibernazione in corso. Il 6/11 il notebook era a batteria, e il passaggio è partito da solo perché lo standby consumava troppo (*Austerity Battery Drain Budget Exceeded*);
- circa 2.500 errori PCIe corretti in 30 giorni (evento 17 di WHEA-Logger), quasi tutti sulla porta del chip Thunderbolt del box a cui è collegato l'SSD. Sono soprattutto *Bad TLP*, cioè pacchetti arrivati corrotti e ritrasmessi: riguardano il collegamento PCIe dentro il box, tra il chip e l'SSD, non il cavo;
- tutto questo c'era già prima del primo collegamento di una dock Thunderbolt, il 28/10. Per i problemi con la dock vedi la voce successiva.

**Causa probabile, non verificata.** Windows gira dall'SSD del box, e lì ci sono anche il file di paging e quello di ibernazione. In standby Windows mette a riposo i collegamenti PCIe e Thunderbolt. Se alla ripresa il collegamento con l'SSD non torna subito affidabile, Windows non riesce a rileggere la memoria che aveva spostato sul disco e si ferma: schermo nero, oppure schermata blu. Per le schermate blu 0xEF non è mai stato scritto un file di dump, come succede quando il disco di sistema non risponde. L'ibernazione è il caso più delicato: Windows deve scrivere tutta la memoria sull'SSD esterno.

**Controlli in sola lettura**, in *PowerShell* (non servono i diritti di amministratore).

Stati di sospensione supportati dal firmware:

```
powercfg /a
```

Riavvii senza un regolare arresto (evento 41). `BugcheckCode` è il codice della schermata blu, `0x0` se il notebook è stato spento con il pulsante; `SleepInProgress = 5` indica un passaggio all'ibernazione in corso:

```
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'; Id=41} | ForEach-Object { $d = @{}; ([xml]$_.ToXml()).Event.EventData.Data | ForEach-Object { $d[$_.Name] = $_.'#text' }; [pscustomobject]@{ Ora = $_.TimeCreated; BugcheckCode = '0x{0:X}' -f [int64]$d.BugcheckCode; SleepInProgress = $d.SleepInProgress } }
```

Le ultime 40 entrate e uscite dallo standby moderno, con il motivo (eventi 506 e 507):

```
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'; Id=506,507} -MaxEvents 40 | Format-Table TimeCreated, Id, Message -Wrap
```

Errori PCIe corretti degli ultimi 30 giorni, per dispositivo. Se non stampa nulla, non ce ne sono:

```
Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'; Id=17; StartTime=(Get-Date).AddDays(-30)} -ErrorAction SilentlyContinue | ForEach-Object { $d = @{}; ([xml]$_.ToXml()).Event.EventData.Data | ForEach-Object { $d[$_.Name] = $_.'#text' }; $d['PrimaryDeviceName'] } | Group-Object | Sort-Object Count -Descending | Format-Table Count, Name -AutoSize
```

Confronta i nomi con l'output di `windows\show-disk-paths.ps1`: se il dispositivo con più errori compare sul percorso dell'SSD, gli errori riguardano il collegamento con il disco di sistema. Gli output contengono gli ID del tuo hardware: in una issue riporta i conteggi, non gli ID.

**Cosa provare, non verificato.** Una modifica per volta, annotando per qualche giorno i blocchi e il numero di errori PCIe:
1. **Quando lo schermo resta nero**, prima di spegnere prova **Win + Ctrl + Maiusc + B**, che riavvia il driver video. Se lo schermo torna, il blocco era solo grafico. Se non succede nulla, Windows è fermo: tieni premuto il pulsante di accensione.
2. **Disattiva l'ibernazione**, nel *Prompt dei comandi come amministratore*:

   ```
   powercfg /hibernate off
   ```

   Windows non passa più dallo standby all'ibernazione, cioè il passaggio che nei test si è bloccato. Con la batteria quasi scarica il notebook dovrebbe spegnersi invece di ibernarsi: salva il lavoro prima di lasciarlo a batteria. Per tornare indietro: `powercfg /hibernate on`.
3. **Disattiva il risparmio energetico dei collegamenti PCIe** (*Risparmio energia stato collegamento*, nel gruppo *PCI Express* delle opzioni risparmio energia), nel *Prompt dei comandi come amministratore*:

   ```
   powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0
   powercfg /setdcvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0
   powercfg /setactive SCHEME_CURRENT
   ```

   Sul notebook dei test era su *Risparmio energia massimo* (valore 2), sia a corrente sia a batteria. Per un collegamento con errori, i passaggi da e verso il risparmio energetico sono il momento più delicato. In standby il consumo potrebbe aumentare. Il valore attuale si legge con `powercfg /q SCHEME_CURRENT SUB_PCIEXPRESS ASPM`. Per tornare indietro ripeti i primi due comandi con `2` al posto di `0`, poi il terzo.
4. **Controlla l'SSD nel box**, a PC spento e box scollegato: che sia inserito bene nello slot M.2 e raffreddato come previsto dal box. Gli errori *Bad TLP* sul collegamento tra il chip e l'SSD possono dipendere anche da un contatto o dalla temperatura.
5. Finché non trovi una configurazione stabile, **spegni invece di sospendere** (guida, punto 5.7). Nelle opzioni risparmio energia puoi impostare la chiusura del coperchio su *Arresta il sistema*.

---

### Con una dock Thunderbolt collegata Windows si blocca o va in schermata blu

Sul notebook dei test una dock Thunderbolt 3 è stata collegata per la prima volta il 28/10/2026, su una porta Thunderbolt diversa da quella del box. Da allora, nei registri di Windows:
- 2/11: blocco nel momento in cui Windows ha riconosciuto il monitor collegato alla dock, con un dump automatico del driver USB (`BUGCODE_USB3_DRIVER`, 0x144);
- 3/11: tre schermate blu in un'ora (0x1000007E e due 0xEF), due delle quali a pochi secondi dall'avvio. Almeno alla prima la dock era collegata;
- 10/11: una schermata blu 0xEF durante il normale uso, con la dock collegata.

Secondo chi ha fatto i test, senza la dock questi blocchi all'avvio non si presentano.

**Causa non chiarita.** Sul notebook dei test dock e box dipendono dallo stesso controller Thunderbolt del notebook. Con la correzione di questa guida i driver USB4 partono con Windows (`Start = 0`), quindi la dock viene gestita fin dalle prime fasi dell'avvio, insieme al disco di sistema. Un problema della dock potrebbe così coinvolgere anche il collegamento con l'SSD: è un'ipotesi, non verificata.

**Cosa provare, non verificato:**
1. **Collega il box direttamente al notebook**, mai alla dock: è il disco di sistema.
2. **Accendi senza la dock** e collegala solo dopo l'accesso a Windows. Annota se i blocchi all'avvio spariscono.
3. **Aggiorna il firmware della dock** con lo strumento del produttore. Non riguarda il BIOS del notebook, ma in questa configurazione non è stato provato.
4. Se i problemi restano, una dock USB-C **senza Thunderbolt** (solo USB e DisplayPort, senza tunnel PCIe) potrebbe evitarli.
