**🌐 Lingua:** [English](how-it-works.md) · **Italiano**

# Come funziona

Questa pagina spiega perché Windows, di serie, non si avvia da un SSD Thunderbolt su questo notebook, e perché la correzione funziona. I fatti osservati sono distinti dalle interpretazioni.

---

## 1. Thunderbolt è PCIe dentro un tunnel

Un SSD NVMe in un box Thunderbolt è un dispositivo PCIe a tutti gli effetti, ma il collegamento PCIe passa dentro un **tunnel** creato sul cavo Thunderbolt/USB4. Qualcuno deve creare e gestire quel tunnel: è il compito del **connection manager**.

- Nei controller Thunderbolt più vecchi il connection manager stava nel firmware del controller (*firmware connection manager*).
- Nei controller USB4, come il controller Intel Thunderbolt 5 del notebook dei test, il connection manager è **software**: lo esegue il sistema operativo, con i suoi driver.

Ne segue che, **prima che parta il sistema operativo**, il tunnel esiste solo se il firmware del PC si prende la briga di crearlo.

---

## 2. Primo ostacolo: il firmware non crea il tunnel

**Fatto osservato.** Con le impostazioni di serie, l'SSD esterno non compare nel menu F12 né nel File Explorer del BIOS, che elenca solo le partizioni del disco interno.

**Causa.** Sui notebook Dell business esistono le opzioni *Enable Thunderbolt Boot Support* ed *Enable Thunderbolt Pre-boot Modules*, che fanno creare al firmware il tunnel PCIe già prima del boot. Il BIOS del notebook dei test non le mostra, ma la nota nella sezione *USB/Thunderbolt Configuration* le cita comunque.

**Soluzione.** Il firmware contiene l'attributo `ThunderboltBoot`, visibile da Linux tramite il driver `dell-wmi-sysman` in `/sys/class/firmware-attributes/dell-wmi-sysman/attributes/ThunderboltBoot`. Impostandolo a `Enabled`, al riavvio l'SSD compare sia nel menu F12 sia nel File Explorer del BIOS.

Nel File Explorer il percorso dell'SSD esterno mostra chiaramente il tunnel: una catena di nodi `Pci(...)`, uno per ogni ponte PCIe da attraversare (porta root, controller Thunderbolt del notebook, controller del box), prima di arrivare a `NVMe(...)`.

**Conseguenza per la sicurezza.** Come avverte la nota del BIOS, i dispositivi collegati durante il pre-boot continuano a funzionare nel sistema operativo indipendentemente dal livello di sicurezza Thunderbolt impostato, finché non vengono scollegati.

---

## 3. Perché l'installazione funziona

Durante l'installazione il PC si avvia dalla chiavetta: il firmware deve leggere solo lei. Il sistema che parte è **WinPE**, un Windows ridotto caricato interamente in RAM. Una volta avviato, WinPE carica i propri driver, compresi quelli USB4: è WinPE a creare il tunnel e a vedere l'SSD. Il firmware non deve mai leggere l'SSD.

Per questo, senza `ThunderboltBoot`, l'installazione va a buon fine ma il riavvio no: il firmware non trova l'SSD e passa alla voce successiva, cioè il sistema interno.

---

## 4. Secondo ostacolo: Windows perde il disco al passaggio al kernel

**Fatto osservato.** Con `ThunderboltBoot` attivo, il firmware carica il boot manager dall'SSD, e il boot manager carica il kernel e i driver di avvio. Poi Windows si blocca con `INACCESSIBLE_BOOT_DEVICE` (0x7B).

**Cosa significa 0x7B.** Il kernel è partito, ma non riesce ad accedere al volume da cui è stato avviato.

**Interpretazione** (coerente con tutti i test, ma non documentata ufficialmente da Microsoft o Dell). Nella fase che precede il kernel, il boot manager legge i file dall'SSD tramite il firmware, che mantiene attivo il tunnel. Quando il kernel prende il controllo, la gestione del dominio USB4 passa al connection manager software di Windows, cioè ai driver `Usb4HostRouter` e `Usb4DeviceRouter`. In un'installazione standard questi driver hanno `Start = 3`: vengono caricati su richiesta, dopo l'avvio. Nel momento in cui il kernel cerca il disco di sistema, nessuno gestisce il tunnel, e il disco non è raggiungibile.

Altre segnalazioni descrivono lo stesso sintomo su altri notebook USB4, mentre lo stesso SSD in modalità USB 3 si avviava regolarmente.

---

## 5. Perché `BootDriverFlags` non basta

`BootDriverFlags` è un valore del registro che chiede a Windows di caricare all'avvio intere famiglie di driver. Il valore `0x14` comprende i driver dei dischi USB e USB 3, ed è la correzione classica per avviare Windows da un SSD in un box USB.

**Fatto osservato.** Con `BootDriverFlags = 0x14` da solo, la schermata blu resta la stessa.

**Interpretazione.** Quei flag riguardano lo stack dei dischi USB, non i driver USB4 che gestiscono il tunnel PCIe. Infatti, dopo la modifica, `Usb4HostRouter` e `Usb4DeviceRouter` risultavano ancora con `Start = 3`.

---

## 6. La correzione

Impostando `Start = 0` (*boot start*) per `Usb4HostRouter` e `Usb4DeviceRouter`:
- il boot manager carica i due driver insieme agli altri driver di avvio;
- il kernel li inizializza abbastanza presto da riprendere la gestione del tunnel prima di cercare il disco di sistema.

**Fatto osservato.** Con questa modifica, insieme a `BootDriverFlags = 0x14` già presente, il Setup di Windows riparte dall'SSD esterno via Thunderbolt.

Entrambi i servizi hanno `ErrorControl = 1`: se uno di loro non riuscisse a caricarsi all'avvio, Windows registrerebbe l'errore e proseguirebbe, senza bloccarsi.

**Fatto osservato: gli aggiornamenti annullano la correzione.** Un aggiornamento di Windows ha reinstallato i driver USB4 con il valore predefinito, `Start = 3`. Il riavvio successivo è finito in `INACCESSIBLE_BOOT_DEVICE` e poi nel ripristino automatico. Il log dei driver (`C:\Windows\INF\setupapi.dev.log`, sezione *Install Driver Updates*) mostra che la reinstallazione è avvenuta **dopo** la richiesta di riavvio, durante la fase di installazione degli aggiornamenti che precede lo spegnimento. Controllare i valori prima di riavviare quindi non basta.

**Fatto osservato: `BootFlags` sul singolo servizio non sostituisce `Start = 0`.** Un servizio può avere un proprio valore `BootFlags`, che chiede al caricatore di avvio di caricarlo come driver di avvio quando Windows parte da un disco USB. Con `BootFlags = 0x14` su `Usb4HostRouter` e `Usb4DeviceRouter` e `Start = 3`, Windows non è partito ed è andato nel ripristino automatico. **Interpretazione:** il caricatore di avvio non considera l'SSD Thunderbolt un disco USB (lo raggiunge come NVMe attraverso un tunnel PCIe), quindi i flag vengono ignorati. Questa strada non protegge dagli aggiornamenti.

**Prevenzione in prova: il servizio `Usb4BootGuard`** (non verificato con un aggiornamento reale). Per l'aggiornamento del 16 ottobre, il log dei driver e il registro eventi di sistema danno questa sequenza:

| Ora | Evento |
|---|---|
| 18:47:26 | Richiesta di riavvio per l'aggiornamento (evento 1074) |
| 18:47:39 | `setupapi.dev.log`, sezione *Install Driver Updates*: *Configure Driver*, poi "Updated service" per `Usb4DeviceRouter` e `Usb4HostRouter`. È qui che `Start` torna a 3 |
| 18:48:21 | Arresto del servizio Registro eventi (evento 6006) |

**Fatti osservati.** Il reset avviene quando Windows configura il nuovo pacchetto del driver, senza reinstallare il dispositivo, e circa 40 secondi prima che i servizi si fermino.

**Interpretazione.** In quel momento un servizio che si fa avvisare dalle modifiche al registro (`RegNotifyChangeKeyValue`) è ancora attivo, e può rimettere `Start = 0` prima dello spegnimento. Per lo stesso motivo non servono le soluzioni che agiscono all'installazione di un dispositivo, come il blocco con i criteri di installazione dei dispositivi o un INF di estensione: in quell'aggiornamento nessun dispositivo è stato installato. Bloccare la chiave con i permessi impedirebbe invece l'aggiornamento del driver, con il rischio che Windows annulli l'intero aggiornamento. Il servizio è in `windows/usb4-boot-guard/` ed è descritto nella Fase 5.9 della guida.

**Riparazione.** L'ambiente di ripristino di Windows parte dall'SSD e vede la partizione di Windows: come l'installer, gira dalla RAM e ricostruisce il tunnel Thunderbolt con i propri driver. Da lì si caricano il registro offline con `reg load` e si reimpostano i valori. È la Fase 6 della guida, con lo script `windows/repair-usb4-boot.bat`, che controlla anche `ThunderboltBoot` (sezione 9).

---

## 7. Perché sembrava partire il sistema interno

Durante i test, scegliendo l'SSD dal menu F12, sembrava avviarsi il Windows del disco interno, come se il firmware ignorasse la scelta. In realtà succedeva questo:
1. Windows partiva dall'SSD e andava in schermata blu (0x7B);
2. si riavviava da solo, come fa di default dopo un errore;
3. al riavvio, il firmware usava la voce predefinita, cioè il sistema interno.

Togliendo temporaneamente le spunte a tutte le altre voci di avvio, il firmware non ha più alternative, e la schermata blu resta visibile. È il modo più semplice per diagnosticare cosa succede davvero.

---

## 8. Perché con Linux è diverso

Linux ha l'**initramfs**: un piccolo sistema autosufficiente, caricato insieme al kernel, che contiene già i driver `thunderbolt` e `nvme`. Il connection manager software di Linux gira lì dentro, prima di montare la root: ritrova i tunnel esistenti o li ricrea, e solo dopo cerca il disco di sistema.

Windows non ha un equivalente separato: i suoi driver di avvio stanno sul volume di sistema e devono essere marcati come tali nel registro. La correzione fa proprio questo.

---

## 9. L'interfaccia WMI del BIOS, da Linux e da Windows

**Fatti.** Gli attributi del BIOS Dell, compreso `ThunderboltBoot`, sono raggiungibili per due strade:
- **da Linux**, con il driver `dell-wmi-sysman`, in `/sys/class/firmware-attributes/dell-wmi-sysman/attributes/`. La usano `scripts/check-bios.sh` e `scripts/thunderbolt-boot.sh`;
- **da Windows e dal suo ambiente di ripristino**, nello spazio dei nomi WMI `root\dcim\sysman\biosattributes`:
  - la classe `EnumerationAttribute` per la lettura, con le proprietà `CurrentValue` e `PossibleValue`;
  - la classe `BIOSAttributeInterface`, con il metodo `SetAttribute`, per la scrittura. Il metodo restituisce `Status`: 0 riuscito, 1 non riuscito, 3 accesso negato perché è impostata una password di amministratore del BIOS. Con `SecType = 0` e `SecHndCount = 0` la chiamata non usa password.

È lo stesso insieme di attributi. Il 30/10/2026, con il BIOS aggiornato, `ThunderboltBoot` è stato letto con `wmic` e scritto con un VBScript dall'ambiente di ripristino (build 26100), che non ha PowerShell ma ha `wmic` e `cscript`. Lo script `windows/thunderbolt-boot-on.vbs` usa le stesse chiamate.

**Interpretazione.** L'interfaccia la espone il firmware tramite il driver ACPI-WMI integrato in Windows, non un driver Dell. Lo suggerisce il fatto che funzioni nell'ambiente di ripristino.

---

## 10. Perché un aggiornamento o un azzeramento del BIOS rompe l'avvio

**Fatti osservati** (30/10/2026, dopo un aggiornamento del BIOS):
- le impostazioni del BIOS sono tornate ai valori predefiniti, e `ThunderboltBoot` era `Disabled`;
- nel menu F12 restavano solo *Windows Boot Manager*, il disco interno e *HTTPs Boot*: le voci dell'SSD erano sparite;
- i valori del registro della correzione (sezione 6) erano ancora corretti;
- riattivato `ThunderboltBoot`, la voce dell'SSD è ricomparsa, e Windows, una volta avviato, ha ricreato la propria voce di avvio mettendola al primo posto.

**Spiegazione.** Con `ThunderboltBoot` spento il firmware non crea il tunnel prima del boot (sezione 2), quindi per il firmware l'SSD non c'è, e le sue voci spariscono dal menu. La correzione del registro non serve a nulla finché il firmware non riesce a leggere il boot manager dall'SSD. Al primo avvio riuscito, Windows si comporta come alla fine del Setup (guida, punto 5.2): ricrea la propria voce e la mette in cima.

**Da chiarire.** Non sappiamo se ogni aggiornamento del BIOS riporta le impostazioni ai valori predefiniti, o se è successo per l'errore *Unrecoverable SPI Error* comparso durante quell'aggiornamento.

---

## 11. Il box a doppio chip e la modalità USB

**Fatti osservati.** Il box ACASIS dei test ha due chip: un controller Thunderbolt (Intel JHL7440) e un bridge USB (Realtek RTL9210B).
- Con un cavo USB-C su una porta Thunderbolt, il box negozia il Thunderbolt: l'SSD è un dispositivo PCIe nel tunnel, e il firmware lo vede solo con `ThunderboltBoot` attivo. Vale sia per il cavo Thunderbolt sia per un normale cavo USB-C.
- Con un cavo USB-C → USB-A su una porta USB-A, il box lavora in modalità USB: l'SSD è un disco USB, il firmware lo vede anche senza `ThunderboltBoot`, e nel menu F12 compare *UEFI Realtek ACASIS …*.
- In modalità USB l'ambiente di ripristino di Windows parte e funziona. Windows invece non parte: si ferma con `INACCESSIBLE_BOOT_DEVICE`. La causa non è chiarita.

**Interpretazione.** L'ambiente di ripristino gira dalla RAM, come l'installer (sezione 3): una volta caricato, trova i dischi con i propri driver, qualunque sia il collegamento. Windows invece deve ritrovare il disco di sistema durante l'avvio, e in modalità USB non ci riesce.

**Conseguenza.** La modalità USB serve solo a raggiungere l'ambiente di ripristino quando `ThunderboltBoot` è spento, per riattivarlo (guida, Fase 7).

---

## 12. BitLocker e PCR7

**Fatti osservati.** Nel Windows esterno, gli eventi di BitLocker 813, 881 e 893 indicano che BitLocker non può usare Secure Boot per la verifica dell'integrità (PCR7), e usa quindi il profilo PCR 0, 2, 4, 11. Dopo l'aggiornamento del BIOS del 30/10/2026 la protezione risultava sospesa, e all'avvio è stata chiesta la chiave di ripristino.

**Conseguenza.** Con questo profilo, ogni modifica al BIOS o al firmware fa chiedere la chiave di ripristino. Perché PCR7 non sia utilizzabile in questa configurazione è da verificare.

**Controllo, in sola lettura,** nel Prompt dei comandi come amministratore:

```
manage-bde -protectors -get C: -Type TPMAndPIN
```

Mai `-get` senza `-Type`: stampa anche la chiave di ripristino.

**Sospensione.** Gli aggiornamenti del BIOS sospendono la protezione. Finché è sospesa, l'SSD è leggibile da qualunque sistema, quindi non va avviato il sistema interno con il box collegato. Si riattiva con `manage-bde -protectors -enable C:` (guida, punto 5.6.6).

---

## 13. Note sulla sicurezza

- **`ThunderboltBoot`** fa autorizzare dal firmware, all'accensione, i dispositivi collegati alla porta Thunderbolt, prima che partano le protezioni del sistema operativo. Su altri modelli Dell la stessa funzione, attiva per impostazione predefinita, è stata classificata come vulnerabilità DMA ([CVE-2019-18579](https://nvd.nist.gov/vuln/detail/CVE-2019-18579)). Per questo va attivata solo se serve, e insieme a `PreBootDma`.
- **`Pre-Boot DMA Support` (`PreBootDma`)** attiva la protezione IOMMU prima del boot. Deve restare **Enabled**.
- **Secure Boot** resta attivo per tutta la procedura: il boot manager di Windows sull'SSD è firmato regolarmente e viene accettato.
- Con `ThunderboltBoot` attivo, scollega il box prima di avviare un altro sistema operativo, se non vuoi che quel sistema veda l'SSD.
- **Gli aggiornamenti del BIOS** possono spegnere `ThunderboltBoot` e sospendono la protezione BitLocker (sezioni 10 e 12). Il software Dell che li può avviare dal Windows esterno va bloccato (guida, punto 5.10).
