**🌐 Language:** **English** · [Italiano](quick-recovery.it.md)

# Quick recovery

One page for emergencies, readable on a phone too. It has only the minimal steps: details and reasons are in the [guide](guide.md).

## Always keep at hand

- **The external SSD's BitLocker recovery key:** the ID and the 48-digit key (guide, step 5.6.4). Not on the notebook.
- **A USB-C → USB-A cable.**
- **The scripts in `C:\Repair\`:** `repair-usb4-boot.bat` and `thunderbolt-boot-on.vbs` (guide, step 5.1). In the recovery environment the folder usually becomes `D:\Repair\`.

The prompt of the recovery environment (WinRE) is a `cmd` **without PowerShell**: use only the commands on this page.

---

## A. *Preparing Automatic Repair*, then BitLocker asks for the key

**Probable cause:** a Windows update set the USB4 drivers back to `Start = 3`. Details: [guide, Phase 6](guide.md#phase-6--if-windows-does-not-start-after-an-update).

1. Check that the ID matches, and enter the 48-digit key.
2. From the Automatic Repair screen: **Advanced options → Troubleshoot → Advanced options → Command Prompt**.
3. Find the Windows drive: `dir D:\Windows`. If it is not there, try the other letters; `X:` is WinRE.
4. Run the script and, if it asks, answer `YES`:
   ```
   D:\Repair\repair-usb4-boot.bat
   ```
5. `exit`, then **Turn off your PC**. Do **not** choose *Continue*: the internal system starts.
6. Power on, F12 → *Windows External SSD*, PIN.
7. In Windows, in Command Prompt as administrator:
   ```
   bcdedit /set {fwbootmgr} displayorder {bootmgr} /addlast
   manage-bde -status C:
   ```
   If protection is off: `manage-bde -protectors -enable C:`.

---

## B. The SSD does not appear in the F12 menu

**Probable cause:** a BIOS update or reset turned `ThunderboltBoot` off. Details: [guide, Phase 7](guide.md#phase-7--if-the-ssd-disappears-from-the-f12-menu-after-a-bios-update-or-reset).

1. With the PC off, connect the enclosure with the **USB-C → USB-A cable to a USB-A port**.
2. F12 → *UEFI Realtek ACASIS …*. If the entry is not there, the problem is the cable or the port.
3. Windows does not start, and that is normal: wait for Automatic Repair, then enter the recovery key.
4. **Advanced options → Troubleshoot → Advanced options → Command Prompt**.
5. Run the script and answer `YES` to enable `ThunderboltBoot`:
   ```
   D:\Repair\repair-usb4-boot.bat
   ```
   Without the script: guide, step 7.2 (`wmic` and the minimal VBScript to type with `notepad`).
6. `exit`, then **Turn off your PC**. Do **not** choose *Continue*.
7. Reconnect the enclosure with the **Thunderbolt cable to the Thunderbolt port**.
8. F12 → the SSD's entry, then the PIN or the recovery key.
9. In Windows, in Command Prompt as administrator: `manage-bde -protectors -enable C:`, then the boot order (guide, step 5.2) and the checklist (guide, step 7.4).
