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
