# Safety rules

The procedure touches the BIOS, the registry of an offline Windows installation, disks and BitLocker. The laptop also has an internal disk, usually with another operating system, which must never be touched.

## Commands you may execute yourself (shell mode)

Only these, and only to read. Everything else, the user runs.

In Claude Code on Windows the shell is usually Git Bash, which rewrites arguments such as `/check` into paths and drops backslashes. Run the `.bat` and `.vbs` scripts through `cmd`, for example `cmd.exe //c "C:\Repair\repair-usb4-boot.bat /check"` (not verified). Reading `ThunderboltBoot` needs a session started as administrator; if yours is not, give the command to the user.

**External Windows** (*Command Prompt as administrator*, unless stated otherwise):
- `reg query …`
- `bcdedit /enum …`
- `manage-bde -status`
- `manage-bde -protectors -get C: -Type TPMAndPIN`
- `windows\repair-usb4-boot.bat /check`
- `cscript //nologo windows\thunderbolt-boot-on.vbs /status`
- `wmic /namespace:\\root\dcim\sysman\biosattributes path EnumerationAttribute where "AttributeName='ThunderboltBoot'" get AttributeName,CurrentValue`
- `schtasks /query …`, `winget list`
- in *PowerShell*: `Get-PnpDevice …`, `windows\show-disk-paths.ps1`, `windows\usb4-boot-guard\usb4-boot-guard.ps1 -Status`

**Ubuntu live session:**
- `./scripts/check-bios.sh`
- `lsblk`
- `boltctl list`
- `lspci`

## Never execute, even if the user asks

Write these out for the user to run, with an explanation:
- `thunderbolt-boot-on.vbs` without `/status`, and `scripts/thunderbolt-boot.sh`: they write to the BIOS;
- `repair-usb4-boot.bat` without `/check`: it writes the registry and offers to write to the BIOS;
- `scripts/patch-windows-hive.sh`, `scripts/restore-hive-backup.sh`, `reg add`, `reg delete`: they write the registry. Also `reg load` and `reg unload` typed by hand on an offline hive: a forgotten `unload` leaves it locked. (`repair-usb4-boot.bat /check` loads and unloads the hive by itself without changing any value: that one is allowed.)
- `usb4-boot-guard.ps1` in any mode other than `-Status`: installing it, `-SelfTest` (it sets `Start = 3` on the running system for a moment), `-Uninstall`;
- `diskpart`, `Clear-Disk`, `Format-Volume`, `Initialize-Disk`, `New-Partition`: they modify disks;
- `bcdedit /set`, `bcdedit /delete`, `bcdboot`: they change the boot configuration;
- `manage-bde` in any form that writes (`-on`, `-off`, `-unlock`, `-protectors -add`, `-protectors -delete`, `-protectors -enable`, `-protectors -disable`), `Clear-Tpm`;
- `pnputil /remove-device`, `pnputil /delete-driver`, `winget install`, `winget uninstall`, `Set-ExecutionPolicy`, and anything else that installs or removes drivers or programs;
- any BIOS or firmware update.

## Checklist before giving a command that writes

1. **What it changes, and how to undo it.** Use the README section *How to undo everything*.
2. **The right disk.** The procedure was verified with storage in RAID/RST mode, where the internal disk is hidden from the installer and, with `modprobe.blacklist=vmd`, from the live session. On other laptops, or in AHCI/NVMe mode, the internal disk is visible. The user identifies the external SSD by model and size (`lsblk` in the live session); `patch-windows-hive.sh` shows the disk and asks for confirmation before writing.
3. **Recovery keys.** The BitLocker recovery key of the external SSD must be at hand, outside the laptop. Before changing the BIOS, the internal disk's key as well, or knowing where it is saved (for example in the Microsoft account used on that system).
4. **Permission.** The PC is the user's, or whoever manages it agrees. The BIOS is shared with the internal system.
5. **Verification status.** Read the status table in `repo/README.md`. If the step is not verified, say so.

## When to stop

Do not improvise a workaround in these cases. Explain the situation, point to the guide or README warnings, and suggest opening an issue:
- **The internal disk is visible** (AHCI/NVMe mode, or a laptop without Intel VMD) **and a step uses `diskpart`.** A wrong `diskpart clean` erases the internal disk, and Setup may write its boot files to the internal disk's ESP (guide §2.3).
  - Never say which disk to erase, and never give `diskpart` commands, not even the read-only ones like `select disk` or `detail disk`.
  - To hide the internal disk from the external Windows, point to the policy block of guide §5.5.2. Guide §5.5.1 uses `diskpart` on the internal disk: the user follows it alone, from the guide.
  - Do not tell the user to switch the BIOS to RAID/RST either: changing the storage mode can stop the internal system from booting. That decision belongs to the owner, or to whoever manages the PC.
- **Any write where the user cannot tell the two disks apart** with certainty by model and size.
- **BIOS administrator password** (`Status = 3`, or reported by `check-bios.sh`). Without the password nothing can be done. Never suggest removing, resetting or bypassing it (CMOS reset, master passwords, unlock tools). The person who manages the PC decides.
- **The PC is not the user's** and they have no permission.
- **An output does not match** what the guide expects, or the user is on hardware where a step does not apply.

## Secrets and identifiers

- Never ask for, accept or repeat a BitLocker recovery key, a PIN, a password, a Product Key, a Service Tag or a serial number. If the user offers the recovery key, tell them not to write it in the chat.
- To check that a saved key is the right one (guide §5.6.4):
  - the user compares the **key ID** saved with the key against the first digits that the BitLocker recovery screen shows;
  - or, on the running Windows, the user runs `manage-bde -protectors -get C:` **themselves**, in a window you do not read, and compares ID and digits without pasting the output anywhere.

  You never run that command and never ask for its output.
- When you ask for a photo of the screen, remind the user to cover recovery keys, serial numbers and the Service Tag.
- Outputs contain identifiers (boot entry GUIDs, device instance IDs, volume serial numbers). Do not copy them into issues or files.

## Reminders to repeat at the right moment

- In WinRE, after `exit`: **Turn off your PC**, never *Continue*: it boots the internal system.
- Connect the enclosure before powering on. Never unplug it while Windows is running: it is the system disk.
- Unplug the enclosure before starting the internal system.
- After a BIOS update: re-enable BitLocker protection on the external Windows (guide §5.6.6).
