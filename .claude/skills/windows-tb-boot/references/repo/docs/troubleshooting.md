**🌐 Language:** **English** · [Italiano](troubleshooting.it.md)

# Troubleshooting

For each problem: the symptom, the most likely cause and the solution.

---

### The SSD appears neither in the F12 menu nor in the BIOS File Explorer

- **`ThunderboltBoot` is not enabled.** Check it in one of these ways:
  - from the live session, with `./scripts/check-bios.sh`;
  - from the external Windows, in Command Prompt as administrator, with `cscript //nologo C:\Repair\thunderbolt-boot-on.vbs /status`;
  - from the recovery environment prompt, with `cscript //nologo D:\Repair\thunderbolt-boot-on.vbs /status`, or with `wmic` (guide, step 7.2).

  `/status` exits with 0 if it is `Enabled`, 2 if it is not, 1 on error. If it is off after a BIOS update or reset, see the next entry.
- **The enclosure was connected after power-on.** Shut down, connect the enclosure and power on again.
- **The enclosure is running in USB mode.** With the ACASIS enclosure used in testing this happens only with a USB-C → USB-A cable on a USB-A port: F12 shows *UEFI Realtek ACASIS …* instead of the SSD's entry, and Windows does not start. Use the Thunderbolt cable and a Thunderbolt port. From the live session, `boltctl list` must show the enclosure with status `authorized` and a speed of 40 Gb/s.

---

### After a BIOS update the SSD has disappeared from the F12 menu

The menu only shows *Windows Boot Manager*, the internal drive and *HTTPs Boot*. The update, or a reset of the settings, set `ThunderboltBoot` back to `Disabled`. It can be repaired without Ubuntu, from the recovery environment reached in USB mode: Phase 7 of [guide.md](guide.md), or the short version in [quick-recovery.md](quick-recovery.md). Then go through the checklist in step 7.4.

---

### The *UEFI Realtek …* entry does not appear in the F12 menu

It is the cable. With a USB-C cable on a Thunderbolt port the enclosure negotiates Thunderbolt anyway, and without `ThunderboltBoot` the firmware does not see it. USB mode needs a **USB-C → USB-A** cable plugged into a **USB-A** port. Connect the enclosure with the PC off.

---

### Windows does not start in USB mode

This is the expected behaviour: in USB mode Windows stops with `INACCESSIBLE_BOOT_DEVICE`, while the recovery environment starts. The cause has not been established. USB mode is useful only to reach the recovery environment and turn `ThunderboltBoot` back on (Phase 7).

---

### The entry added with *Add Boot Option* does not appear in the list

A quirk of this BIOS. Uncheck and recheck one of the entries, press **Apply Changes**, exit the BIOS and enter it again.

---

### *ERROR: Invalid Parameters* when I add the entry

The file or the entry name is missing. You must select the file **and** type the name in *Boot Option Name*.

---

### I choose the SSD from the F12 menu, but the internal system starts

Almost always Windows started from the SSD, hit a blue screen and restarted on the default entry. To see it:
1. in the BIOS, uncheck all entries except the SSD one;
2. restart without pressing anything and watch what appears;
3. at the end, check the entries again, with the internal system entry in first place.

---

### Blue screen `INACCESSIBLE_BOOT_DEVICE` (0x7B)

- **The registry fix was not applied**, or it was applied to another installation. Repeat Phase 3 and check the output of the verification.
- **A Windows update set `Start` back to 3.** Repair from the Windows Recovery Environment (WinRE), as described in Phase 6 of [guide.md](guide.md): Ubuntu is not needed.

---

### After Setup the external Windows starts by itself, and the F12 menu has two *Windows Boot Manager* entries

At the end of Setup, Windows registered its own entry in the firmware and put it in first place. The two entries cannot be told apart from the BIOS: restore the order from Windows with `bcdedit`, as described in step 5.2 of [guide.md](guide.md).

---

### After a restart *Windows External SSD* disappears from the F12 menu, and the Windows entry is back in first place

This is the duplicate-entry cycle. The entry created by hand in Phase 4 and the Windows one point to the same file. The firmware deletes one of them at power-on, and Windows, when it boots, recreates its own and puts it back at the top. Delete the manual entry and put the Windows one in order, as described in step 5.2 of [guide.md](guide.md).

---

### `bcdedit` replies "The specified entry type is invalid.", or `/enum` prints nothing

This usually happens when pasting several commands at once: two lines get joined, or the outputs get mixed up. Type or paste one command at a time.

---

### `sc qc Usb4HostRouter | findstr START_TYPE` shows nothing

On Windows in Italian the output of `sc qc` is translated, and the line does not contain `START_TYPE`. Use a check that does not depend on the language:

```
reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4HostRouter /v Start
```

---

### After an update *Preparing Automatic Repair* appears and then BitLocker asks for the recovery key

The update set the USB4 drivers back to `Start = 3`, and Windows can no longer reach the disk. Enter the recovery key, open Command Prompt from the Windows Recovery Environment (WinRE) (**Advanced options → Troubleshoot → Advanced options → Command Prompt**) and run `D:\Repair\repair-usb4-boot.bat`, or the manual commands: Phase 6 of [guide.md](guide.md), or the short version in [quick-recovery.md](quick-recovery.md).

---

### After `exit` and *Continue* the internal system starts

*Continue* starts the firmware's default entry, that is the internal system, not the external Windows. It happened in testing, with the enclosure connected and the SSD's BitLocker protection suspended. Always leave with `exit`, then **Turn off your PC**, and power on again with F12 on the external Windows entry.

---

### In the recovery environment prompt `powershell` and `where` are not recognized

This is normal: the recovery environment (build 26100) has neither PowerShell nor `where`. It has `reg`, `wmic`, `cscript` (VBScript), `notepad`, `manage-bde` and `bcdedit`. The scripts in this repository used in WinRE (`repair-usb4-boot.bat` and `thunderbolt-boot-on.vbs`) use only these tools.

---

### A command is not recognized as an internal or external command

If the command is a PowerShell one, for example `Get-PnpDevice`, `Get-Tpm` or a filter with `Select-String`, you ran it in Command Prompt. This was the most frequent mistake in testing. Open **PowerShell as administrator**. The guide states for each block of commands where to run it (*Conventions* section).

---

### `repair-usb4-boot.bat /check` says that with Windows running it only repairs the running system

`C:\Repair\` still holds the version of the script from before 30/10/2026: it does not know `/check`, takes it for a drive letter and stops with an error, without reading or writing anything. It happened during the tests of 30/10/2026. Copy both scripts again from the repository's `windows\` folder to `C:\Repair\` and, before running them, check in *PowerShell* that the copies are identical to the originals, from the repository folder:

```
Get-FileHash C:\Repair\repair-usb4-boot.bat, .\windows\repair-usb4-boot.bat, C:\Repair\thunderbolt-boot-on.vbs, .\windows\thunderbolt-boot-on.vbs
```

The hashes must match in pairs.

---

### `thunderbolt-boot-on.vbs` says the BIOS WMI interface is not available, or that access is denied

- **Access denied** (`0x80041003`): in Windows you need a Command Prompt opened as administrator. With `repair-usb4-boot.bat /check` without administrator rights this is normal: the script reports it and does not treat it as an error.
- **Interface not available**: the PC may not be a compatible Dell, that is, without the WMI namespace `root\dcim\sysman\biosattributes`.

---

### The BIOS script answers `Status = 3`

Access denied: a BIOS administrator password is set, and without it the attribute cannot be changed. Neither the scripts nor the guide handle the password. If the PC is not yours, ask whoever manages it: do not try to bypass it.

---

### The VBScript typed by hand gives an error on the line with `ExecMethod_`

You probably typed `0.ExecMethod_`, with a zero, instead of `o.ExecMethod_`, with the letter **o**. It happened in testing. Fix the line with `notepad` and run the script again. The full script is in the guide, step 7.2.

---

### After a BIOS update BitLocker shows protection off

BIOS updates suspend BitLocker protection, and `manage-bde -status C:` shows it as off. While it is suspended, the SSD is readable by any system: do not start the internal system with the enclosure connected. Turn it back on in Command Prompt as administrator:

```
manage-bde -protectors -enable C:
```

---

### BitLocker asks for the recovery key at every boot

After a BIOS change it is normal for it to ask once: BitLocker uses the PCR 0, 2, 4, 11 profile, which changes with the firmware (step 5.6.6 of [guide.md](guide.md)). To check the profile, read-only: `manage-bde -protectors -get C: -Type TPMAndPIN`. **Never `-get` without `-Type`:** it prints the recovery key.

If it keeps asking at every boot, a possible fix, **not verified**, is to recreate the TPM and PIN protector, in Command Prompt as administrator:

```
manage-bde -protectors -delete C: -Type TPMAndPIN
manage-bde -protectors -add C: -TPMAndPIN
```

The second command asks for the new PIN.

---

### `reg load` or `reg query` reply "ERROR: Invalid syntax.", or `req` is not recognized

Typing errors. The command is `reg`, and the key path must be written all in one piece, with backslashes: `HKLM\OFF\Select`, not `HKLM\OFF Select`.

---

### No network is available during the initial setup (OOBE)

Windows does not have the driver for the Wi-Fi card. Choose **I don't have internet** and complete the setup with a local account: it is the recommended path anyway. For the drivers see step 5.3 of [guide.md](guide.md).

---

### Windows Update installed a *Dell Inc. – Firmware* update

Firmware updates are applied at the next restart, and the BIOS is shared with the system on the internal drive. If the PC is not yours, tell whoever manages it **before restarting**: a BIOS update can make the internal system ask for the BitLocker recovery key, and it can set `ThunderboltBoot` back to its default value (Phase 7 of [guide.md](guide.md)). To avoid this in the future, exclude drivers and firmware from Windows Update (step 5.1) and block the Dell software that updates the BIOS (step 5.10).

---

### The Dell software has come back

`winget list Dell` lists SupportAssist, Dell Core Services or Dell Connected Service Delivery again. Check that the block policy still contains the IDs `SWC\VID001&PID0001&DCSDSoftware` and `ACPI\DELL0033`, with `reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /s`, then repeat the uninstallation and removal as in step 5.10 of [guide.md](guide.md). Whether the block holds over time has not been verified yet: note when and how it came back.

---

### The battery charges to 100% again

A BIOS update or reset also set the charge limit back to its default. In the BIOS (F2) set *Battery Charge Configuration* = *Custom*, with start 65 and stop 70: Dell requires at least 5 points of difference. It is one of the items in the checklist in step 7.4 of [guide.md](guide.md).

---

### *Unrecoverable SPI Error* appears during a BIOS update

It happened on 30/10/2026 (code 3,6), together with *This boot will take longer than usual*, and then the BIOS restarted with the new version. **Do not turn off the PC during the update.** If the BIOS restarts, run *Diagnostics* from the F12 menu (*Pre-Boot Tasks*), which runs read-only tests, then follow Phase 7 of [guide.md](guide.md).

---

### From the live session the Windows partition shows up as `BitLocker` and does not mount

After encryption (step 5.6 of [guide.md](guide.md)) the partition must be unlocked before mounting. The scripts `patch-windows-hive.sh` and `restore-hive-backup.sh` do this by themselves and ask for the recovery key (48 digits, with the dashes). By hand:

```
sudo cryptsetup open --type bitlk /dev/nvme0n1p3 winssd
sudo mount -t ntfs3 /dev/mapper/winssd /mnt/win
```

At the end: `sync && sudo umount /mnt/win && sudo cryptsetup close winssd`. This procedure has not yet been verified on this configuration.

---

### The internal drive has appeared in the external Windows

The external Windows received the Intel RST/VMD driver, from a Dell package, a chipset installer or Windows Update. As an immediate measure, set it offline with `diskpart`. Then block the VMD driver, as described in step 5.5 of [guide.md](guide.md): the drive disappears completely and the driver can no longer be reinstalled.

---

### After "Reset this PC" `INACCESSIBLE_BOOT_DEVICE` appears

"Reset this PC" recreates the registry from scratch, so the USB4 drivers go back to `Start = 3`. Reapply the fix from the Windows Recovery Environment (WinRE) (Phase 6), then resume the procedure. In this configuration, to roll back drivers and programs, use restore points (step 5.8 of [guide.md](guide.md)).

---

### `hivexregedit: command not found`

`hivexregedit` is in the `libwin-hivex-perl` package, not in `libhivex-bin`. Install it with `sudo apt install -y libwin-hivex-perl`. The script `patch-windows-hive.sh` does this automatically.

---

### `\HardwareConfig: path not found in this hive`

This is normal on an installation that has never completed a boot: Windows creates that key at the first successful boot. The scripts in this repository do not use it.

---

### Mounting the NTFS partition fails

If the volume is marked "dirty", for example after a blue screen, retry with `FORCE=1 ./scripts/patch-windows-hive.sh /dev/nvme0n1p3`. If Windows was hibernated, do not force the mount: boot Windows, shut it down completely and try again.

---

### The internal drive appears in the live session

You did not add `modprobe.blacklist=vmd` to the GRUB `linux` line: the parameter must be added at every boot. If the BIOS is in AHCI/NVMe mode, the parameter has no effect: identify the drives by size and model with `lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL`.

---

### The internal Windows asks for the BitLocker recovery key

The BIOS change altered the measurements that BitLocker checks at boot. Enter the recovery key: if the PC is not yours, ask whoever manages it. After the first successful boot the problem does not come back, until the BIOS changes again.

---

### `check-bios.sh` says that `ThunderboltBoot` does not exist

The same applies if `thunderbolt-boot-on.vbs` says so. Your model's firmware does not have the option, or the BIOS version is different: on the notebook used in testing the attribute exists both before and after the BIOS update of 30/10/2026. This procedure does not apply: see the alternatives at the end of [guide.md](guide.md).

---

### `check-bios.sh` says that a BIOS administrator password is set

Without that password the attributes cannot be changed. If you do not know it, ask whoever manages the PC: do not try to bypass it.
