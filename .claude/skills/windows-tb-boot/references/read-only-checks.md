# Read-only checks and how to read their output

The commands below only read. In shell mode you may run them yourself; in chat mode give them to the user, one block at a time, saying where to run them. Outputs contain identifiers (GUIDs, volume serial numbers): do not copy them anywhere.

## External Windows, running

*Command Prompt as administrator*, from the folder with the scripts (usually `C:\Repair\`, or the clone). In shell mode from Claude Code on Windows, see `safety.md` for running them through `cmd`.

| Command | Expected | If not |
|---|---|---|
| `repair-usb4-boot.bat /check` | exit code 0, `Result: everything is correct.` (`Esito: tutto a posto.`) | exit code 2: something to fix (lines marked `TO FIX, expected …` / `DA CORREGGERE, atteso …`). With Windows running, **before restarting** the user runs the script without `/check`, as administrator (guide §5.4); the actual repair by the current script version is not verified yet. Exit code 1: error |
| `cscript //nologo thunderbolt-boot-on.vbs /status` | `ThunderboltBoot = Enabled`, exit code 0 | `Disabled`, exit code 2: the SSD will not be found at the next boot. Enabling it from the running Windows is **not verified**; the verified way is from WinRE, guide §7.2. *access denied*: the prompt is not elevated |
| `reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4HostRouter /v Start` | `0x0` | `0x3`: an update or a driver package reset it, and the next boot will fail. **Before restarting**, the user runs `C:\Repair\repair-usb4-boot.bat` as administrator (guide §5.4). If Windows has already failed to start: guide §6.2 |
| `reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4DeviceRouter /v Start` | `0x0` | as above |
| `reg query HKLM\SYSTEM\CurrentControlSet\Control /v BootDriverFlags` | `0x14` | part of the verified configuration (guide §6.3) |
| `bcdedit /enum {fwbootmgr}` | the first value of `displayorder` is the internal system's entry, `{bootmgr}` (the external Windows) is last | guide §5.2 |
| `manage-bde -status C:` | protection on (`Protection On` / `Protezione attivata`) | protection off after a BIOS update: guide §5.6.6 (the user re-enables it) |
| `manage-bde -protectors -get C: -Type TPMAndPIN` | a *TPM And PIN* protector exists | guide §5.6.2, §5.6.3 |

*PowerShell as administrator*:
- `windows\usb4-boot-guard\usb4-boot-guard.ps1 -Status`: state of the `Usb4BootGuard` service and its latest events; exit code 1 if something is wrong (guide §5.9).
- `windows\show-disk-paths.ps1`: which controller each disk depends on. In the external Windows only the SSD should appear (guide §5.5).

## WinRE prompt

A `cmd` **without PowerShell and without `where`**. Available: `reg`, `find`, `wmic`, `cscript`, `notepad`, `manage-bde`, `bcdedit`.

- **Find the Windows drive.** `X:` is WinRE itself, and in testing Windows was `D:`. Run `manage-bde -status`, then `dir D:\Windows`. If the volume is *Locked*, the user unlocks it with the recovery key: guide §6.2. They type the key in the prompt, never in the chat.
- `D:\Repair\repair-usb4-boot.bat /check`: same output as above, read from the offline registry. It loads and unloads the hive by itself, but changes no value.
- `cscript //nologo D:\Repair\thunderbolt-boot-on.vbs /status`, or the `wmic … get AttributeName,CurrentValue` command in guide §7.2.
- If the user runs the script **without** `/status`, it writes. `Status = 0` means success; `Status = 1` means failure; `Status = 3` means a BIOS administrator password is set: **stop** (`safety.md`).

## Ubuntu live session

- `./scripts/check-bios.sh` (read only; it calls `sudo` by itself). Read:
  - whether `ThunderboltBoot` is present and its current value;
  - whether a BIOS administrator password is set: if so, **stop**;
  - the value of `PreBootDma`, which must stay enabled;
  - the Thunderbolt controller (`lspci`), the connected devices (`boltctl`), and the disks.

  It ends with `ThunderboltBoot e' presente` (go on, guide §1.5) or `non e' presente` (the procedure does not apply).
- `lsblk -o NAME,SIZE,MODEL,TRAN`: with `modprobe.blacklist=vmd` (guide §1.1) and the BIOS in RAID/RST mode, only the external SSD should appear, usually as `nvme0n1`. Two NVMe disks mean the internal one is visible: before any write the user tells them apart by model and size, and nothing gets erased (`safety.md`).
- `boltctl list`: the enclosure is authorized, with the link speed.

## BIOS and F12 menu

- **On the tested laptop. F12 menu, normal use:** *Windows External SSD* (the entry renamed in guide §5.2), or *UEFI* followed by the SSD model.
- **USB mode** (USB-C → USB-A cable on a USB-A port): *UEFI Realtek ACASIS …*. With this entry only WinRE starts.
- **After a BIOS update:** only *Windows Boot Manager*, the internal disk and *HTTPs Boot* are left: `ThunderboltBoot` is off (guide §7.1).
- **F2 BIOS:** storage mode (RAID/RST in the verified configuration), Secure Boot on, `Pre-Boot DMA Support` on. Do not use *Save as Custom User Settings* (guide §7.4).

## Typical mistakes

- **PowerShell commands typed in the Command Prompt** ("not recognized as an internal or external command"): open PowerShell as administrator. In WinRE there is no PowerShell, so use the `cmd` alternative from the guide.
- **`C:` used in WinRE:** there the Windows drive is usually `D:`.
- **`/status` without administrator rights:** *access denied*. This is not a fault of the BIOS.
- **`0.ExecMethod_` instead of `o.ExecMethod_`** in the VBScript typed by hand (guide §7.2).
- **Several `bcdedit` commands pasted together:** the lines can merge. One command at a time (guide §5.2).
