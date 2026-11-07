**🌐 Lingua:** [English](quick-recovery.md) · **Italiano**

# Ripristino rapido

Una pagina per le emergenze, leggibile anche dal telefono. Qui ci sono solo i passi minimi: i dettagli e i motivi sono nella [guida](guide.it.md).

## Da tenere sempre a portata di mano

- **La chiave di ripristino BitLocker dell'SSD esterno:** l'ID e la chiave di 48 cifre (guida, punto 5.6.4). Non sul notebook.
- **Un cavo USB-C → USB-A.**
- **Gli script in `C:\Repair\`:** `repair-usb4-boot.bat` e `thunderbolt-boot-on.vbs` (guida, punto 5.1). Nell'ambiente di ripristino la cartella diventa di solito `D:\Repair\`.

Il prompt dell'ambiente di ripristino (WinRE) è un `cmd` **senza PowerShell**: usa solo i comandi di questa pagina.

---

## A. *Preparazione del ripristino automatico*, poi BitLocker chiede la chiave

**Causa probabile:** un aggiornamento di Windows ha riportato i driver USB4 a `Start = 3`. Dettagli: [guida, Fase 6](guide.it.md#fase-6--se-windows-non-parte-dopo-un-aggiornamento).

1. Controlla che l'ID corrisponda, e inserisci la chiave di 48 cifre.
2. Dalla schermata del ripristino automatico: **Opzioni avanzate → Risoluzione dei problemi → Opzioni avanzate → Prompt dei comandi**.
3. Trova l'unità di Windows: `dir D:\Windows`. Se non c'è, prova le altre lettere; `X:` è WinRE.
4. Lancia lo script e, se lo chiede, rispondi `SI`:
   ```
   D:\Repair\repair-usb4-boot.bat
   ```
5. `exit`, poi **Spegni il PC**. **Non** scegliere *Continua*: parte il sistema interno.
6. Riaccendi, F12 → *Windows SSD esterno*, PIN.
7. In Windows, nel Prompt dei comandi come amministratore:
   ```
   bcdedit /set {fwbootmgr} displayorder {bootmgr} /addlast
   manage-bde -status C:
   ```
   Se la protezione risulta disattivata: `manage-bde -protectors -enable C:`.

---

## B. L'SSD non compare nel menu F12

**Causa probabile:** un aggiornamento o un azzeramento del BIOS ha spento `ThunderboltBoot`. Dettagli: [guida, Fase 7](guide.it.md#fase-7--se-lssd-sparisce-dal-menu-f12-dopo-un-aggiornamento-o-un-azzeramento-del-bios).

1. A PC spento, collega il box con il **cavo USB-C → USB-A a una porta USB-A**.
2. F12 → *UEFI Realtek ACASIS …*. Se la voce non c'è, il problema è il cavo o la porta.
3. Windows non parte, ed è normale: aspetta il ripristino automatico, poi inserisci la chiave di ripristino.
4. **Opzioni avanzate → Risoluzione dei problemi → Opzioni avanzate → Prompt dei comandi**.
5. Lancia lo script e rispondi `SI` per attivare `ThunderboltBoot`:
   ```
   D:\Repair\repair-usb4-boot.bat
   ```
   Senza script: guida, punto 7.2 (`wmic` e VBScript minimo da scrivere con `notepad`).
6. `exit`, poi **Spegni il PC**. **Non** scegliere *Continua*.
7. Ricollega il box con il **cavo Thunderbolt alla porta Thunderbolt**.
8. F12 → voce dell'SSD, poi il PIN o la chiave di ripristino.
9. In Windows, nel Prompt dei comandi come amministratore: `manage-bde -protectors -enable C:`, poi l'ordine di avvio (guida, punto 5.2) e la lista di controllo (guida, punto 7.4).
