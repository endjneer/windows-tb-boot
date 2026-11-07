**🌐 Language:** **English** · [Italiano](guide.it.md)

# Step-by-step guide

This guide describes the complete procedure, in the recommended order. Each phase also explains **why** you do what you do: if something goes wrong, understanding the reason helps you find the solution.

Before you start, read the [warnings in the README](../README.md#warnings).

**Conventions**
- F2 opens the BIOS, F12 the one-time boot menu.
- "Internal drive" is the notebook's original drive, which must never be touched. "External SSD" is the SSD in the Thunderbolt enclosure.
- Each block of commands states where to run it:
  - *Ubuntu live session*: the terminal of USB stick B. This applies unless stated otherwise;
  - *Command Prompt as administrator*: `cmd` on the external Windows, opened with *Run as administrator*;
  - *PowerShell as administrator*: PowerShell on the external Windows, opened the same way;
  - *WinRE prompt*: the Command Prompt of the Windows Recovery Environment, or the one that opens with Shift+F10 from the installation USB stick. It is a `cmd` **without PowerShell** and without `where`; it has `reg`, `wmic`, `cscript` (VBScript), `notepad`, `manage-bde` and `bcdedit`.
- **PowerShell commands do not work in Command Prompt.** This is the most frequent mistake: if `Get-PnpDevice`, `Get-Tpm` or `Select-String` are not recognized as internal or external commands, you are in Command Prompt. Open PowerShell as administrator; in WinRE, where there is no PowerShell, use the `cmd` alternative given in the text.

---

## Phase 0 — Preparation

### 0.1 The images

- **Windows 11:** download the official ISO from the Microsoft website.
- **Ubuntu Desktop:** download the latest LTS release (tested: 26.04.1, kernel 7.0) from ubuntu.com, and verify the SHA256 checksum published on the site.

### 0.2 USB stick A: Windows installation

In Rufus:
- **Device:** the USB stick.
- **Boot selection:** the Windows 11 ISO.
- **Image option:** *Standard Windows installation*. Do **not** use *Windows To Go*.
- **Partition scheme:** GPT. **Target system:** UEFI (non CSM).
- In the Windows options dialog that appears after START you can remove the TPM, Secure Boot and RAM requirements and the Microsoft account requirement. These are optional: the procedure does not depend on these choices.

**Why the standard installation and not Windows To Go:** the SSD will be booted via Thunderbolt, that is as an NVMe drive on PCIe, not as a USB drive.

**For the path without Ubuntu (not verified, Phase 1 and step 3.4):** once the stick is written, create a `Repair` folder on it and copy into it the contents of the repository's `windows\` folder. You need `repair-usb4-boot.bat` and `thunderbolt-boot-on.vbs`.

### 0.3 USB stick B: Ubuntu live session

In Rufus:
- **Boot selection:** the Ubuntu ISO.
- **Persistent partition:** 0.
- GPT scheme, UEFI target.
- When Rufus asks whether to write in ISO or DD mode, choose **DD**.

**Why DD:** it copies the image exactly as it is, and it is the most reliable way to boot Ubuntu with Secure Boot enabled.

### 0.4 Before you start

- Mount the SSD in the enclosure and connect it to a **Thunderbolt 5 port** of the notebook with the **Thunderbolt cable**. With the ACASIS enclosure used in testing, a USB-C cable plugged into a Thunderbolt port negotiates Thunderbolt anyway. USB mode is obtained only with a USB-C → USB-A cable on a USB-A port.
- Also keep a **USB-C → USB-A cable** aside. It is not needed for normal use, only for recovery: when `ThunderboltBoot` is off, it is the way to reach the Windows Recovery Environment (Phase 7).
- Connect the enclosure **before powering on** the notebook, in every phase.
- Keep the BitLocker recovery key of the internal drive at hand, or know where it is saved (for example in the Microsoft account used on that system).
- Disconnect any drives and USB sticks you don't need.

---

## Phase 1 — Checking and enabling ThunderboltBoot

**Goal:** make the external SSD visible to the firmware before boot. Without this step the firmware cannot boot anything from the SSD.

### 1.1 Start the live session with the internal drive hidden

1. Power on the notebook, press F12 and choose USB stick B.
2. In the GRUB menu highlight *Try or Install Ubuntu* and press `e`.
3. Go to the end of the line that starts with `linux`, add a space and type:
   ```
   modprobe.blacklist=vmd
   ```
4. Boot with **Ctrl+X**. When the Ubuntu installer opens, choose *Try Ubuntu* or close it.

**Why:** if the BIOS is in RAID/RST mode, the internal drive is attached through the Intel VMD controller. By preventing Linux from loading the `vmd` driver, the internal drive disappears from the live session: you cannot select it by mistake, and the external SSD gets a predictable name (`nvme0n1`). The parameter must be added again at every boot of the live session, because the session does not save anything.

**If your BIOS is in AHCI/NVMe mode**, the parameter does not hide the internal drive. In that case identify the drives with extreme care, by size and model.

### 1.2 Check the drives

```
lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL
```

Only the external SSD should appear, besides the USB stick (`sda`) and the live session's `loop` devices.

### 1.3 Download the repository

Connect to Wi-Fi. Then, in the terminal:

```
sudo apt update
sudo apt install -y git
git clone https://github.com/endjneer/windows-tb-boot.git
cd windows-tb-boot
chmod +x scripts/*.sh
```

If `git clone` does not work, open the repository page in Firefox, download the ZIP (**Code → Download ZIP**), extract it, enter the `windows-tb-boot-main` folder and run the same `chmod`.

### 1.4 Check the BIOS (read-only)

```
./scripts/check-bios.sh
```

The script shows:
- whether the `ThunderboltBoot` attribute exists and its current value;
- the state of `PreBootDma`, the pre-boot DMA protection, which must stay **Enabled**;
- whether a BIOS administrator password is set;
- the Thunderbolt controller and the connected enclosure.

**If `ThunderboltBoot` does not exist**, your firmware does not allow booting via Thunderbolt and this procedure does not apply. See the alternatives at the end of the guide.

**If an administrator password is set**, the script stops. If the PC is not yours, the change must be agreed with whoever manages it.

### 1.5 Enable ThunderboltBoot

```
./scripts/thunderbolt-boot.sh
```

The script shows the current value, asks for confirmation, writes `Enabled` and checks that the change is pending a reboot.

**Why from Linux:** the `dell-wmi-sysman` driver exposes the BIOS settings in `/sys/class/firmware-attributes/`, including some that the menu does not show. It is the same mechanism used by Dell's management tools. The same attributes can be reached from Windows and from its recovery environment, through the BIOS WMI interface: see the box below and Phase 7.

### 1.6 Verify

Shut down the notebook, leave the enclosure connected, power on again and press F12. An entry with the SSD model must appear in the menu, for example `UEFI WD_BLACK SN850X 1000GB`. If it does, the firmware sees the SSD via Thunderbolt.

For now **do not boot it**: the SSD is still empty, or contains an installation that has not been fixed yet.

> **Alternative without Ubuntu (not verified).** On 30/10/2026 `ThunderboltBoot` was read and enabled from the prompt of the Windows Recovery Environment, with `wmic` and with a VBScript (Phase 7). For a new installation, the equivalent environment is USB stick A opened with **Shift+F10**:
>
> 1. copy the scripts to the `Repair` folder of the stick (step 0.2);
> 2. boot USB stick A and press **Shift+F10**. Find the stick's letter, for example with `dir E:\Repair`; below it is `E:`;
> 3. test read-only, in the *WinRE prompt*:
>    ```
>    wmic /namespace:\\root\dcim\sysman\biosattributes path EnumerationAttribute where "AttributeName='ThunderboltBoot'" get AttributeName,CurrentValue
>    ```
> 4. enable the attribute:
>    ```
>    cscript //nologo E:\Repair\thunderbolt-boot-on.vbs
>    ```
>    The script shows the value, sets it to `Enabled` if needed and reads it back;
> 5. shut down and verify as in step 1.6.
>
> It remains to be seen whether the installation stick's environment contains `cscript` and the WMI interface like the recovery environment. The verified path is still the one with Ubuntu.

---

## Phase 2 — First part of the Windows installation

### 2.1 Start the installer

With the enclosure connected, press F12 and choose USB stick A.

### 2.2 Choose the edition

If you can, choose **Windows 11 Pro**: you need it to encrypt the external SSD with BitLocker (Phase 5).

### 2.3 Choose the drive

On the drive selection screen:
- **The internal drive may not appear.** If the BIOS is in RAID/RST mode, the Windows installer does not have the VMD driver and does not see the internal drive. This is normal, and actually an advantage: you cannot choose it by mistake.
- Identify the external SSD by its size.

If the SSD already contains partitions, delete them from diskpart. Press **Shift+F10** and type:

```
diskpart
list disk
select disk N
detail disk
clean
convert gpt
exit
```

`N` is the number of the external SSD. Before `clean`, check with `detail disk` that the model is the right one: `clean` erases the whole selected disk.

Go back to the installer, refresh the list, select the SSD's unallocated space and continue. Setup will create the partitions by itself (200 MB ESP, MSR and Windows partition).

**If the internal drive is visible** (BIOS in AHCI/NVMe mode), Setup may write the boot files to the internal drive's ESP, even if you install Windows on the SSD. Before continuing, consider whether you can make the internal drive invisible. After the installation, check that the `EFI\Microsoft\Boot` folder exists on the SSD's ESP.

### 2.4 At the reboot, go to Phase 3

After copying the files, Setup restarts the PC. **At the restart press F12 and choose USB stick B (Ubuntu).**

**Why:** if you booted the SSD now, you would get the `INACCESSIBLE_BOOT_DEVICE` blue screen. If you don't press anything, the internal drive's system starts with the enclosure connected. That is not harmful, but better avoided.

**Why the installation works and booting doesn't:** during the installation it is the WinPE system on the USB stick that creates the Thunderbolt tunnel, with its own USB4 drivers, after it has started. When booting from the SSD, instead, the Windows kernel must find the drive before those drivers are loaded. Details in [how-it-works.md](how-it-works.md).

---

## Phase 3 — Fixing the registry

**Goal:** make the installation on the SSD load the drivers that manage the Thunderbolt tunnel at boot.

### 3.1 Start the live session

As in step 1.1, with `modprobe.blacklist=vmd`. Connect to Wi-Fi and go back into the repository folder: if you rebooted, the live session has lost everything and the repository must be downloaded again as in step 1.3.

### 3.2 Find the Windows partition

```
lsblk -o NAME,SIZE,TYPE,FSTYPE,MODEL
```

It is the largest NTFS partition on the external SSD, usually `nvme0n1p3`.

### 3.3 Apply the fix

```
./scripts/patch-windows-hive.sh /dev/nvme0n1p3
```

The script:
1. shows the disk the partition belongs to and asks you to confirm by typing `SI` ("yes");
2. installs, if missing, the `libwin-hivex-perl` package, which provides `hivexregedit`;
3. mounts the partition;
4. creates a backup copy of the system registry (`SYSTEM.bak-<data>`, where `<data>` is the date), never overwriting earlier copies;
5. applies the two changes in the `registry/` folder:
   - `BootDriverFlags = 0x14` in `Control`, which asks Windows to load USB storage drivers at boot;
   - `Start = 0` for the `Usb4HostRouter` and `Usb4DeviceRouter` services, that is, the USB4 drivers loaded at boot instead of on demand;
6. checks that the values have been written, and unmounts the partition.

**Note on the first change:** in testing, `BootDriverFlags` alone was not enough, and the second change was the decisive one. The first one remained applied in the configuration that worked, and there is no reason to remove it, but it has not been shown to be necessary.

**Why `hivexregedit --merge`:** it adds or updates only the values listed in the `.reg` file. Do not use the `setval` command of `hivexsh`: it replaces all the values of the key you are in, and in the `Control` key it would delete dozens of system settings.

**If the mount fails** because the volume is "dirty", for example after a blue screen, you can retry with:
```
FORCE=1 ./scripts/patch-windows-hive.sh /dev/nvme0n1p3
```

### 3.4 Alternative without Linux (not verified)

The same changes can be made from USB stick A, with the script used for repairs from the recovery environment. Its offline mode was verified on 30/10/2026 in WinRE; it has not yet been tried from the installation stick.

1. At the restart in step 2.4 press F12 and choose **USB stick A** instead of B.
2. When the installer appears, press **Shift+F10**.
3. Find the two letters: the stick's, with the `Repair` folder (step 0.2), and that of the SSD's Windows partition:
   ```
   dir E:\Repair
   dir D:\Windows
   ```
   Try the letters one by one. From the stick the internal drive is usually not visible (step 2.3); if it were, check with particular care that you picked the SSD's partition.
4. Run the script with the SSD's letter, `D:` in the example:
   ```
   E:\Repair\repair-usb4-boot.bat D:
   ```
   The script shows the values, asks for confirmation with `YES` and writes the same changes as the `registry/` folder. At the end it also checks `ThunderboltBoot`, if `thunderbolt-boot-on.vbs` is in the same folder.
5. Close the prompt with `exit`, then close the installer and confirm the cancellation: the PC restarts. Press F12 and continue with Phase 4, booting the SSD.

Without the script, the manual commands are those of step 6.3, with the SSD's letter instead of `D:`.

---

## Phase 4 — Boot entry and completing Setup

### 4.1 Create a dedicated boot entry

The firmware creates an entry for the SSD by itself, for example `UEFI WD_BLACK SN850X 1000GB`, which boots the fallback file `\EFI\BOOT\BOOTX64.EFI`. In testing an explicit entry was used, pointing directly to the Windows boot manager:

1. Enter the BIOS (F2) → **Boot Configuration** → **Boot Sequence** → **Add Boot Option**.
2. Press **Browse for file**. The File Explorer lists the readable partitions of all drives.
3. Recognize the external SSD's ESP by its path:
   - the partitions of the **internal drive** have a label (ESP, OS, WINRETOOLS…) and a short path, with a single `Pci(...)` node before `NVMe(...)`;
   - those of the **external SSD** appear as *NO VOLUME LABEL* and have a long path, with many `Pci(...)` nodes. These are the PCIe bridges of the notebook's Thunderbolt controller and of the enclosure;
   - the ESP is the one with `HD(1,GPT,...,0x800,0x64000)`: first partition, `0x64000` sectors of 512 bytes, that is 200 MB.
4. Open `EFI` → `Microsoft` → `Boot` → `bootmgfw.efi` and press **Submit**.
5. In **Boot Option Name** type a name, for example `Windows SSD`. Both fields are required: without a name the BIOS replies *Invalid Parameters*.
6. Press **Add Boot Option**.

**If the new entry does not appear in the list**, uncheck and recheck one of the entries, press **Apply Changes**, exit the BIOS and enter it again.

**Leave `Windows Boot Manager` in first place**, so the default boot remains the internal system. You start the external Windows with F12.

**Do not check** *Save as Custom User Settings* on exit: it would overwrite any custom BIOS profile.

### 4.2 First boot from the SSD

Restart with the enclosure connected, press F12 and choose **Windows SSD**. The Windows Setup *Installing Windows* screen should appear. The manual entry is only needed until the end of Setup: in Phase 5.2 you delete it, because it becomes a duplicate.

### 4.3 During Setup

Setup restarts the PC a few times. In the first restarts the firmware starts from the default entry, that is the internal system: **press F12 and choose Windows SSD**. At some point Setup registers its own *Windows Boot Manager* entry in the firmware and puts it in first place, and from then on the restarts continue on the SSD by themselves. The original order is restored in Phase 5.2.

If the internal system starts by mistake, restart and choose Windows SSD: Setup resumes where it stopped. **Do not disconnect the enclosure during Setup.**

### 4.4 Out-of-box experience (OOBE), without internet

On the *Let's connect you to a network* screen choose **I don't have internet** and create a local account. The option appears if you removed the Microsoft account requirement in Rufus (Phase 0.2).

**Why offline:**
- it is the fastest path;
- Windows probably does not have the Wi-Fi card driver yet;
- above all, Windows Update must not run before the fix is protected (Phase 5.1). An update of the USB4 drivers could set them back to on-demand loading, and at the next restart the blue screen would come back.

---

## Phase 5 — After the installation

### 5.1 Before connecting to the internet

Open **Command Prompt as administrator** and check the values:

```
reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4HostRouter /v Start
reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4DeviceRouter /v Start
```

Both must show `Start    REG_DWORD    0x0`.

Use `reg query` and not `sc qc ... | findstr START_TYPE`: on an Italian-language Windows the output of `sc qc` is translated, and the filter finds nothing.

**Exclude drivers and firmware from Windows Update.** Windows Update can also deliver Dell BIOS updates, presented as "Firmware" driver updates and applied at restart. The BIOS is a single one, shared with the internal drive's system: an update launched from the external Windows can make the internal system ask for the BitLocker recovery key, and can reset `ThunderboltBoot` to its default value. It happened on 30/10/2026 (Phase 7), with an update very probably started by Dell SupportAssist: this policy does not prevent that, which is why step 5.10 is needed too. Still in the administrator prompt:

```
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate /t REG_DWORD /d 1 /f
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" /v ExcludeWUDriversInQualityUpdate
```

The second command must show `0x1`. From now on Windows Update no longer installs drivers or firmware, and you install drivers by hand (Phase 5.4). Microsoft documents this policy for the Pro, Enterprise and Education editions: on Home it may be ignored.

If you already connected to the internet before setting it, check in **Settings → Windows Update → Update history → Driver updates** that no *Dell Inc. – Firmware* entry appears. See also [troubleshooting.md](troubleshooting.md).

**Prepare the repair scripts.** Copy [`windows/repair-usb4-boot.bat`](../windows/repair-usb4-boot.bat) and [`windows/thunderbolt-boot-on.vbs`](../windows/thunderbolt-boot-on.vbs) to `C:\Repair\`, in the same folder. They let you repair from the recovery environment without retyping the commands:
- a Windows update can set the USB4 drivers back to `Start = 3`, and then Windows no longer starts (Phase 6). At the moment there is no verified preventive protection; one attempt, still to be verified, is the service in Phase 5.9;
- a BIOS update or reset can turn `ThunderboltBoot` off, and then the SSD disappears from the F12 menu (Phase 7).

To try them without changing anything, in *Command Prompt*:

```
C:\Repair\repair-usb4-boot.bat /check
```

`/check` is read-only: it shows the three registry values with the result and the state of `ThunderboltBoot`, and exits with 0 if everything is correct, 2 if something needs fixing, 1 on error. The registry part needs no administrator rights; reading `ThunderboltBoot` does, and without them the script reports it without treating it as an error. On 30/10/2026 `/check` and `/status` were tried from Windows, with and without administrator rights, and in WinRE (Phase 6).

### 5.2 Put the internal system back in first place

At the end of Setup, Windows registers its own *Windows Boot Manager* entry in the firmware and puts it in first place. The F12 menu therefore shows two *Windows Boot Manager* entries, one per drive and indistinguishable by name, and the default boot becomes the external Windows. From the BIOS you cannot tell which is which; from Windows you can.

In an administrator Command Prompt on the external Windows:

```
bcdedit /enum firmware
```

- `{bootmgr}` is the entry of the external Windows, the one you are in. It has `device partition=\Device\HarddiskVolume...`, that is the SSD's ESP.
- The internal system's entry is another *Windows Boot Manager*, with an identifier in curly braces and `device unknown`: the external Windows does not have the VMD driver and does not see the internal drive.

Move the external entry to the bottom and rename it, so you can recognize it in the F12 menu:

```
bcdedit /set {fwbootmgr} displayorder {bootmgr} /addlast
bcdedit /set {bootmgr} description "Windows External SSD"
```

Verify:

```
bcdedit /enum {fwbootmgr}
```

The first value of `displayorder` must be the identifier of the internal entry, and `{bootmgr}` must be the last.

There is no need to test by restarting with the enclosure connected: the internal system would start with the SSD visible. The check with `bcdedit` is enough. After a major Windows update, check the order again, because Windows may put itself back in first place.

**Delete the entry you created by hand in Phase 4 (*Windows SSD*).** At this point it is a duplicate: it points to the same file, on the same disk and the same partition, as the Windows entry. In testing, the firmware deleted one of the two duplicate entries at power-on. When starting, Windows did not find its own entry, recreated it and put it back in first place. With two identical entries this cycle repeats at every restart.

Find the identifier of the manual entry with `bcdedit /enum firmware`: it is the one with `description Windows SSD`. Then, **one command at a time**, because when you paste several together the lines can merge and cause errors:

```
bcdedit /delete {IDENTIFIER-OF-THE-MANUAL-ENTRY}
bcdedit /set {fwbootmgr} displayorder {bootmgr} /addlast
bcdedit /set {bootmgr} description "Windows External SSD"
bcdedit /enum {fwbootmgr}
```

Alternatively, the manual entry can be deleted from the BIOS, with DELETE.

A fallback entry remains anyway: the one the firmware creates by itself for the SSD (*UEFI* followed by the drive model), which boots the fallback file `\EFI\Boot\BootX64.efi`.

At the first opportunity, check that the cycle has stopped: the F12 menu must show *Windows External SSD*, and `bcdedit /enum {fwbootmgr}` must still show `{bootmgr}` at the bottom. If Windows kept putting itself back on top anyway, it would not be serious: with the enclosure disconnected the firmware skips the entry of the missing drive, and with the enclosure connected the external Windows starts, which is encrypted and asks for the PIN.

### 5.3 Network drivers without internet

If Windows does not have the Wi-Fi card driver, these are the options, in order of convenience:
1. **Ethernet cable:** Windows may already have the driver for the network port;
2. **Android phone connected via USB**, with USB tethering: it works without drivers. With an iPhone you need the Apple drivers;
3. **download the driver elsewhere and install it offline:** Dell driver packages (`.exe`) install without a connection.

To find out which driver you need, run this in the administrator prompt:

```
pnputil /enum-devices /problem
```

In the network controller's *Instance ID* you find the vendor: `VEN_8086` is Intel (also for Killer cards), `VEN_17CB` is Qualcomm, `VEN_14C3` is MediaTek. On the Dell support site, on the model's page, Networking category, choose the Wi-Fi driver from that vendor.

**To download it from the Ubuntu live session**, if you don't have another PC:
1. Shut Windows down completely with `shutdown /s /t 0`, so the NTFS partition is closed cleanly.
2. Start the live session with `modprobe.blacklist=vmd`, connect to Wi-Fi and download the driver with Firefox.
3. Copy it to the SSD:
   ```
   sudo mkdir -p /mnt/win
   sudo mount -t ntfs3 /dev/nvme0n1p3 /mnt/win
   sudo mkdir -p /mnt/win/Driver
   sudo cp ~/Scaricati/*.exe /mnt/win/Driver/ 2>/dev/null || sudo cp ~/Downloads/*.exe /mnt/win/Driver/
   sync && sudo umount /mnt/win
   ```
4. Start the external Windows and run the file from `C:\Driver`.

Once online, install the other drivers as described in step 5.4: with the policy set in Phase 5.1, Windows Update no longer installs them. After the first Windows updates, check the `Start` values again as in step 5.1.

### 5.4 Drivers: what to install and what to avoid

With drivers and firmware excluded from Windows Update (Phase 5.1), drivers are installed by hand. Download them from the model's Dell support page, choosing the model from the list: automatic detection requires SupportAssist.

**From Dell** (Windows 11), in this order:
1. **Network:** Wi-Fi, Bluetooth, Ethernet. You probably already installed them in Phase 5.3.
2. **Chipset:** Intel Chipset Device Software, Intel Serial IO and Intel Management Engine, **driver package only**, not the "Firmware Update".
3. **Thermal and power management:** Intel Dynamic Tuning Technology or Innovation Platform Framework, depending on what the page lists.
4. **Dell's control software for the model:** power profiles, fans, lighting. The selected profile determines the power available to the GPU.
5. **Audio** (Realtek) and **Intel integrated graphics**.
6. Optional: webcam and Windows Hello, NPU.

**From nvidia.com:** the GPU driver, *Studio* version for compute and AI workloads, *Game Ready* for games. The OEM version on the Dell site is usually older.

**To avoid:**
- **BIOS and firmware updates**: BIOS, Management Engine, Thunderbolt/USB4, internal SSD. The firmware is shared with the internal system;
- **Intel RST/VMD**: the external Windows does not need it, because it boots from Thunderbolt, and it would make the internal drive visible. To block its installation entirely, see step 5.5.2;
- **SupportAssist and Dell Command Update**: they automatically offer BIOS updates too. They can also arrive by themselves, without you installing them: it happened with SupportAssist. Check for them and block them as described in step 5.10.

**After each package, before restarting**, especially chipset, Serial IO and anything related to USB or Thunderbolt, check the `Start` values again as in step 5.1. If one has gone back to `0x3`, run `C:\Repair\repair-usb4-boot.bat` from a Command Prompt as administrator: it sets the values back to 0 before the restart.

At the end, `pnputil /enum-devices /problem` must not list anything anymore: all devices have their driver.

### 5.5 Hide the internal drive from the external Windows

Open **Disk Management**: only the external SSD should appear. Right after the installation this is the case, because the external Windows does not have the Intel RST/VMD driver and does not see the internal drive. But as soon as the driver arrives, from a Dell package, from a chipset installer or from Windows Update before the Phase 5.1 policy, the internal drive appears with its partitions. Unless the drive is encrypted in a way the external Windows cannot unlock, the files become readable too.

The goal is that nothing running on the external Windows can read or modify the internal drive: malware, a full antivirus scan, indexing, an automation or AI tool with access to the files.

#### 5.5.1 Immediate measure: drive offline

In an administrator Command Prompt:

```
diskpart
list disk
select disk N
offline disk
exit
```

`N` is the number of the internal drive, recognizable by its size. The setting is stored in the external Windows' registry and writes nothing to the internal drive. It is however a weak measure: any program with administrator rights can bring the drive back online.

#### 5.5.2 Robust measure: blocking the VMD driver

Without the VMD driver the internal drive disappears entirely, as during the installation. The external Windows does not need it, because it boots from Thunderbolt. First, though, you must be sure you block the right controller: blocking a bridge on the Thunderbolt path by mistake would make the external Windows unbootable.

**1. Identify the controller.** In PowerShell, even without administrator rights, run [`windows/show-disk-paths.ps1`](../windows/show-disk-paths.ps1), or paste its contents. For each drive it walks up the device tree to the root, and prints the name and ID of each step. In the test environment (an Italian-language Windows, so device names are shown here as they appear in English):

```
== (internal drive)
NVMe xxxx                       |  SCSI\DISK&VEN_NVME&PROD_xxxx\...
Intel RST VMD Controller xxxx   |  PCI\VEN_8086&DEV_xxxx&SUBSYS_xxxxxxxx&REV_xx\...
PCI Express Root Complex        |  ACPI\PNP0A08\0
...
== SN850X
WD_BLACK SN850X 1000GB          |  SCSI\DISK&VEN_NVME&PROD_WD_BLACK_SN850X\...
Standard NVM Express Controller |  PCI\VEN_15B7&DEV_5030&...
PCI Express ... Switch Port     |  PCI\VEN_8086&DEV_15EF&...   (enclosure, JHL7440)
PCI Express ... Switch Port     |  PCI\VEN_8086&DEV_xxxx&...   (notebook's Thunderbolt 5)
PCI Express Root Port           |  PCI\VEN_8086&DEV_xxxx&...
PCI Express Root Complex        |  ACPI\PNP0A08\0
...
```

The controller to block is the one with **VMD** in its name above the internal drive. Before continuing, check that it does **not** appear in the external SSD's path. Take its ID from your output, stopping at the `PCI\VEN_xxxx&DEV_xxxx` part: in the example `PCI\VEN_8086&DEV_xxxx`, with the four characters from your output in place of `xxxx`.

**2. Set the block.** In an administrator Command Prompt, replacing the ID with yours:

```
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /v DenyDeviceIDs /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /v DenyDeviceIDsRetroactive /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 1 /t REG_SZ /d "PCI\VEN_8086&DEV_xxxx" /f
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /s
```

This is the *Prevent installation of devices that match any of these device IDs* policy: no driver can attach to that controller anymore.

**3. Remove the current driver.** In **Device Manager → Storage controllers**, right-click the VMD controller → **Uninstall device**, check **Attempt to remove the driver for this device** and confirm.

**4. Restart and verify.**
- In Disk Management only the external SSD must appear.
- In Device Manager the VMD controller stays without a driver, with a notice that its installation is forbidden by system policy. This is the expected result.

The policy lives in the external Windows' registry and has no effect on the internal system. To undo it:

```
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /f
```

Then, in Device Manager, use **Action → Scan for hardware changes**.

#### 5.5.3 Limits

- Offline mode and the driver block can be undone by a program with administrator rights. They protect against mistakes, scans, indexing and common malware, not against a targeted attack. Use a **standard account** for everyday use, and run automation and AI tools without administrator rights.
- The real protection of the internal drive's data "at rest" is its encryption, which has to be enabled on the internal system itself. If the drive is readable from another operating system, it is also readable from any bootable USB stick.

### 5.6 Encrypt the external SSD with BitLocker (TPM + PIN)

**Why:** the SSD is external, so it gets carried around, lost, lent. Encryption protects it from anyone who boots it with a live USB stick, and from the internal system if one day you forget the enclosure connected at power-on.

**Requirements:** Windows **Pro**: check it in Settings → System → About. On Home BitLocker is not available, and VeraCrypt encrypts the system drive only with Secure Boot disabled, which is not recommended here.

**When:** after the Windows cumulative updates and the driver installation, and after checking that the `Start` values of the USB4 drivers stay at `0x0` even after a few restarts. The repair scripts can unlock an encrypted partition, but on an unencrypted partition the repair is simpler.

#### 5.6.1 Check the TPM

In PowerShell as administrator:

```
Get-Tpm
```

`TpmPresent` and `TpmReady` must be `True`.

**Never clear the TPM** (Windows Security → Security processor, or `tpm.msc`). It is a single one, shared between the two systems: clearing it would invalidate the BitLocker keys of the external Windows and, if the internal system uses the TPM, its keys too. Both would ask for the recovery key.

#### 5.6.2 Enable the startup PIN

By default BitLocker uses only the TPM. The PIN makes the key independent of the platform state, which here is shared with another system. In Command Prompt as administrator:

```
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v UseAdvancedStartup /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v EnableBDEWithNoTPM /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v UseTPM /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v UseTPMPIN /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v UseTPMKey /t REG_DWORD /d 2 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\FVE" /v UseTPMKeyPIN /t REG_DWORD /d 2 /f
```

These correspond to the *Require additional authentication at startup* policy, with the various allowed combinations.

#### 5.6.3 Turn on encryption

```
manage-bde -on C: -TPMAndPIN -RecoveryPassword -UsedSpaceOnly -EncryptionMethod xts_aes256
```

- **Choose a numeric PIN**, 6 digits or more. Before boot the keyboard may use the US layout, and a PIN with letters might not match the one you set.
- The command shows the protectors it created: **Numerical Password**, with an *ID* and a 48-digit *password*, and **TPM And PIN**.
- `-UsedSpaceOnly` encrypts only the used space. On a fresh installation it is the quickest choice.

#### 5.6.4 Save the recovery key

Save **both the ID and the numerical password**. The password is the actual key. The ID tells you which key to use: the BitLocker recovery screen shows its first digits, and on a PC with two systems it is how you avoid mixing them up.

- **Where to keep it:** a password manager (label *BitLocker – Windows External SSD*, user name = ID, password = 48 digits, date and drive in the notes), and a paper copy kept away from the notebook.
- **Where not to keep it:** the internal drive, cloud services shared with others, the SSD itself, a screenshot in the camera roll.
- Check the digits again group by group. You can read them again at any time with `manage-bde -protectors -get C:`. This command **prints the recovery key**: use it only to read the key again, never in a screenshot or in output you share. For checks, use the form with `-Type` from step 5.6.6.

#### 5.6.5 Restart and verify

1. Restart with F12 → *Windows External SSD* and enter the PIN. If you use the numeric keypad, make sure Num Lock is on. At the first restart BitLocker checks the TPM, and only then starts encrypting. If the internal system starts by mistake, the test simply waits for the next boot of the external Windows.
2. Check the status:
   ```
   manage-bde -status C:
   ```
   You should see encryption in progress, or completed, and the two protectors: *TPM And PIN* and *Numerical Password*. Encryption runs in the background and resumes by itself after a shutdown.

#### 5.6.6 Consequences

- **BIOS or firmware changes make the external Windows ask for the recovery key too.** In the test environment, BitLocker events 813, 881 and 893 say that BitLocker cannot use Secure Boot for integrity validation (PCR7), and therefore uses the PCR 0, 2, 4, 11 profile, which changes with every BIOS or firmware change. To check the profile in use, read-only, in *Command Prompt as administrator*:
  ```
  manage-bde -protectors -get C: -Type TPMAndPIN
  ```
  **Never use `-get` without `-Type`:** it also prints the recovery key.
- **BIOS updates suspend the protection.** After the one on 30/10/2026, `manage-bde -status C:` showed protection off. While it is suspended, the SSD is readable by any system: do not start the internal system with the enclosure connected. Turn it back on, in *Command Prompt as administrator*:
  ```
  manage-bde -protectors -enable C:
  ```
- **If the key is requested at every boot** even after turning protection back on, a possible fix, not verified, is to recreate the TPM and PIN protector: `manage-bde -protectors -delete C: -Type TPMAndPIN`, then `manage-bde -protectors -add C: -TPMAndPIN`, which asks for the new PIN.
- **Repair from the live session.** The partition shows up as type `BitLocker` instead of `ntfs`. The `patch-windows-hive.sh` and `restore-hive-backup.sh` scripts recognize it and ask for the recovery key to unlock it with `cryptsetup`. This part has not been verified yet. By hand:
  ```
  sudo cryptsetup open --type bitlk /dev/nvme0n1p3 winssd
  sudo mount -t ntfs3 /dev/mapper/winssd /mnt/win
  # ... operations ...
  sync && sudo umount /mnt/win && sudo cryptsetup close winssd
  ```
- **Repair from the Windows Recovery Environment (WinRE)** (Phase 6): it works with the encrypted drive too. You need the recovery key.
- **Performance:** the impact is negligible. Encryption uses the processor's AES instructions, much faster than the Thunderbolt link.

### 5.7 Sleep

It has not been verified yet whether the Thunderbolt link survives sleep and hibernation. Until you have tested it calmly, shut the PC down instead of putting it to sleep.

### 5.8 Restore points

**Goal:** be able to bring Windows, with its drivers and programs, back to an earlier working state using only official tools, without touching personal files. Those must be saved separately, with a file-level backup.

**System Restore** brings system files, registry, drivers and programs back to an earlier point in time. The restored registry also includes the `Start = 0` values of the USB4 drivers, provided the restore point was created after the Phase 3 fix. In Windows 11 it is **turned off by default**.

#### 5.8.1 Turning it on and the first restore point

In PowerShell as administrator:

```
Enable-ComputerRestore -Drive "C:\"
Checkpoint-Computer -Description "Configurazione completa" -RestorePointType MODIFY_SETTINGS
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=10%
```

- The first command turns on protection for drive C:.
- The second immediately creates a restore point with a recognizable name ("Configurazione completa", "Complete setup"). Create it when Windows, drivers and programs are configured the way you want.
- The third reserves up to 10% of the drive for restore points. If it replies that it cannot find any association, set the space from the user interface: `SystemPropertiesProtection` → **Configure** → *Max Usage* slider.

From here on Windows creates a restore point by itself before updates and driver installations.

**Note:** by default `Checkpoint-Computer` does not create more than one restore point every 24 hours. If it has already created one, it only shows a warning. If you want to be able to create manual restore points at any time, for example before installing a driver:

```
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v SystemRestorePointCreationFrequency /t REG_DWORD /d 0 /f
```

#### 5.8.2 Use

- **With Windows working:** Start → *Create a restore point* → **System Restore**, then choose the restore point.
- **If Windows does not start:** from the recovery environment, in **Troubleshoot → Advanced options → System Restore**. With BitLocker on, it may ask you for the recovery key to unlock C:.

#### 5.8.3 Checking the recovery environment

Check that the Windows Recovery Environment is enabled and that it is on the external SSD:

```
reagentc /info
```

The status must be *Enabled*. The location shows disk and partition, for example `harddisk0\partition4\Recovery\WindowsRE`. In the external Windows, with the internal drive hidden (Phase 5.5), `harddisk0` is the external SSD, and the partition is a recovery partition created by Windows. You can confirm it from `diskpart` with `list disk`, where a single disk must appear, then `select disk 0` and `list partition`.

The recovery environment, booted from the Thunderbolt SSD, sees the Windows partition: this was verified during the repair described in Phase 6. It runs from RAM like the installer, and rebuilds the Thunderbolt tunnel by itself.

**Recommended test, to do once:** check that the restore point appears. Restoring from a restore point has not been tested yet.
1. `reagentc /boottore`, then restart with F12 → *Windows External SSD*.
2. **Troubleshoot → Advanced options → System Restore**: the restore point created in step 5.8.1 must appear.
3. **Cancel without restoring**, then choose **Turn off your PC**. Power on again, press F12 and choose *Windows External SSD*. Do not choose **Continue**: it starts the firmware's default entry, that is the internal system, with the enclosure connected.

#### 5.8.4 Limits, and what not to use

- **Restore points live on the same drive.** They do not protect against failure, loss or theft of the SSD, nor against a damaged file system. For those cases you need a disk image, or to reinstall following this guide: with personal files saved separately, that is a legitimate alternative.
- **Do not use "Reset this PC".** It reinstalls Windows removing drivers and programs, and recreates the registry from scratch. The USB4 drivers would go back to `Start = 3`, and `INACCESSIBLE_BOOT_DEVICE` would appear at the very first restart of the procedure: you would have to redo Phase 3 halfway through the operation.

### 5.9 Protection against updates: the Usb4BootGuard service (not verified)

A Windows update can set the USB4 drivers back to `Start = 3`, and then Windows no longer starts (Phase 6). The reset happens while Windows installs the updates before shutting down, when services are still running: see [how-it-works.md](how-it-works.md), section 6. The `Usb4BootGuard` service takes advantage of that moment: Windows notifies it of every change to the two drivers' keys, and it immediately sets `Start = 0` again. It also checks the values at startup, every minute and at shutdown.

**Status:** tested with the automated tests in `windows/tests`, on a test registry, and with `-SelfTest` on the running system: `Start` set back to 3 returns to 0 within a few milliseconds. It has not yet been verified with a real update: keep the repair script and the recovery key at hand (Phase 6).

**Installation.** In PowerShell opened as administrator, from the repository folder:

```
powershell -ExecutionPolicy Bypass -File .\windows\usb4-boot-guard\usb4-boot-guard.ps1
```

The script compiles the service with the C# compiler included in Windows (.NET Framework 4), copies it to `C:\Program Files\Usb4BootGuard`, registers it with automatic startup and starts it. At the end it shows the status: permissions and values must be `OK`.

The service runs as `SYSTEM`, so only an administrator with elevated rights must be able to modify its program. Inheriting the permissions of `Program Files` is not enough: Windows gives full control to whoever creates the folder, that is, your account, even from a program started without elevated rights. The script therefore sets explicit permissions (`SYSTEM` and `Administrators` with full control, `Users` read-only) and makes the `Administrators` group the owner. `-Status` checks this too.

**Test.** Right after the installation:

```
powershell -ExecutionPolicy Bypass -File .\windows\usb4-boot-guard\usb4-boot-guard.ps1 -SelfTest
```

The script sets `Start` to 3 on each driver and measures how long the service takes to set it back to 0. In any case, before exiting, it sets `Start = 0` by itself: the test never leaves the system in a state that prevents booting.

**After every Windows update**, check what happened:

```
powershell -ExecutionPolicy Bypass -File .\windows\usb4-boot-guard\usb4-boot-guard.ps1 -Status
```

`-Status` is read-only and does not need administrator rights. It shows the service state, the program permissions, the values and the service's latest events in the Application log. An event with ID 2 (*Value restored*) means that the service fixed a value. Note the date and the reason (*change detected*, *periodic check*, *shutdown*): they show whether the protection holds.

**Removal:** `usb4-boot-guard.ps1 -Uninstall` removes the service and the program. The registry values stay as they are, and the event source stays registered, so past events remain readable.

**Language:** like the other Windows scripts, English or Italian depending on the system language, which can be forced with `/en` or `/it`.

**Limits.**
- If an update reset the values after the services have stopped, the service would not see it: Phase 6 is still the way out.
- An antivirus might flag a service that rewrites system keys.
- The service only fixes the values of the fix (`Start` of the two drivers and `BootDriverFlags`), and never creates missing keys.

### 5.10 Block the Dell software that updates the BIOS

**Why.** On 30/10/2026 a BIOS update started while the external Windows was running, and turned `ThunderboltBoot` off (Phase 7). The very probable cause, not a certain one, is Dell SupportAssist, which was installed on the external Windows without our choosing it, together with two other components:

| Program | Version | Installed on |
|---|---|---|
| Dell Connected Service Delivery + SubAgent | 1.1.2 | 05/10 |
| Dell Core Services | 1.15.18 | 07/10 |
| Dell SupportAssist | 5.2.5 | 24/10 |

Dell Connected Service Delivery is a software component (class *SoftwareComponent*) attached to a dedicated Dell ACPI device, `ACPI\DELL0033`, and brings the rest with it. How it arrived has not been established. Excluding drivers from Windows Update (step 5.1) was in effect, but it does not stop SupportAssist from updating the BIOS on its own. So, besides uninstalling the programs, you block the device the component attaches to, with the same policy used for the VMD driver.

All the commands in this section are run in **PowerShell as administrator**.

**1. Check.**

```
winget list Dell
```

**2. Uninstall**, in this order:

```
winget uninstall --name "Dell SupportAssist" --exact
winget uninstall --name "Dell Core Services" --exact
winget uninstall --name "Dell Connected Service Delivery SubAgent" --exact
winget uninstall --name "Dell Connected Service Delivery" --exact
```

Repeat `winget list Dell` until none of these programs is left. If another Dell *SubAgent* shows up, uninstall it the same way with the exact name shown by `winget` (to be verified: one may have been left on 30/10). It has not been verified that Dell's control software (step 5.4) works without Dell Core Services.

**3. Block the devices.** Two IDs are added to the `DenyDeviceIDs` policy of step 5.5.2, continuing the numbering after the VMD:

```
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 2 /t REG_SZ /d "SWC\VID001&PID0001&DCSDSoftware" /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 3 /t REG_SZ /d "ACPI\DELL0033" /f
```

The block works only with the `DenyDeviceIDs` and `DenyDeviceIDsRetroactive` values set to 1, as in step 5.5.2. If you did not block the VMD driver, first set those two values with the first two commands of step 5.5.2, and number the IDs from 1.

**4. Remove the devices and their drivers.** Find the Dell devices among the software components:

```
Get-PnpDevice -Class SoftwareComponent | Format-Table Status, FriendlyName, InstanceId -AutoSize -Wrap
```

Then find the `dcsdsoftware.inf` and `dcsddriver.inf` driver packages: with `pnputil /enum-drivers` look for the entries with these original names, and note the published name, of the form `oemNN.inf`. To see which devices use a package:

```
pnputil /enum-devices /drivers | Select-String -Context 10,2 -Pattern 'oemNN.inf'
```

Remove the two devices, one at a time, with the instance ID shown by the previous commands, and then the two packages:

```
pnputil /remove-device "<instance ID>"
pnputil /delete-driver oemNN.inf /uninstall /force
```

**5. Verify.**

```
winget list Dell
reg query "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /s
Get-PnpDevice -Class SoftwareComponent | Format-Table Status, FriendlyName, InstanceId -AutoSize -Wrap
```

`winget` must no longer list the four programs, and the policy must contain the three IDs: 1 = the VMD controller's ID (step 5.5.2), 2 = `SWC\VID001&PID0001&DCSDSoftware`, 3 = `ACPI\DELL0033`.

**Status:** applied on 30/10/2026, with all commands succeeding. Whether the block holds over time is still to be verified: after Windows updates, run `winget list Dell` again now and then.

**To undo:**

```
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 2 /f
reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 3 /f
```

---

## Phase 6 — If Windows does not start after an update

**Symptom**, observed after a Windows update: at restart *Preparing Automatic Repair* appears, and then the blue BitLocker screen asking for the recovery key. In the F12 menu *Windows External SSD* is back in first place.

**Cause:** the update reinstalled the USB4 drivers, setting them back to `Start = 3`, the default value. Windows hits `INACCESSIBLE_BOOT_DEVICE`, restarts by itself and starts Automatic Repair, which cannot fix the problem. The BitLocker screen belongs to the recovery environment: to access the drive you need the recovery key, the PIN does not work there.

**Repair:** from the Windows Recovery Environment, which boots from the SSD and sees it. You don't need the Ubuntu live session.

### 6.1 Preparation, once only

Copy [`windows/repair-usb4-boot.bat`](../windows/repair-usb4-boot.bat) and [`windows/thunderbolt-boot-on.vbs`](../windows/thunderbolt-boot-on.vbs) to `C:\Repair\` on the external Windows (Phase 5.1). In the recovery environment the same folder usually shows up as `D:\Repair\`. To try them without changing anything: `C:\Repair\repair-usb4-boot.bat /check`.

### 6.2 Get to the Command Prompt

1. On the BitLocker screen check that the **Recovery key ID** matches the one you saved (Phase 5.6.4). Enter the 48-digit key, numbers only (the dashes are added automatically), and press **Continue**: it is this screen's button, not the *Continue* menu option to avoid when leaving (step 6.4).
2. From the Automatic Repair screen choose **Advanced options → Troubleshoot → Advanced options → Command Prompt**. This is the verified order. If you are asked for the recovery key, enter it. If Automatic Repair restarts the PC and goes back to the BitLocker screen, choose **Skip this drive** and carry on from the same menu.
3. In the prompt, find the Windows drive. In the recovery environment the letter may differ from C: (in testing it was **D:**); `X:` is the recovery environment itself. This prompt is a `cmd` **without PowerShell** and without `where`: use only the commands given here.
   ```
   manage-bde -status
   dir D:\Windows
   ```
   If the volume shows as *Locked*, unlock it:
   ```
   manage-bde -unlock D: -RecoveryPassword RECOVERY-KEY-48-DIGITS
   ```

### 6.3 Fix the values

With the script:

```
D:\Repair\repair-usb4-boot.bat
```

The script fixes the installation on its own drive:
1. it loads the offline registry and shows the three values, each with its result;
2. if they are already correct it says so, and writes nothing; otherwise it asks for confirmation (`YES`), fixes them, shows the values after the fix and checks them;
3. it unloads the registry, trying a second time if needed;
4. if `thunderbolt-boot-on.vbs` is in the same folder, it checks `ThunderboltBoot`. If it is off, it asks for confirmation and enables it (Phase 7);
5. at the end it lists the next steps, the same as in step 6.4.

With `/check` it only runs the checks, without questions and without writing anything, and exits with 0 if everything is correct, 2 if something needs fixing, 1 on error.

If you run it from a USB stick, pass the Windows drive letter as an argument, for example `repair-usb4-boot.bat D:`. The script speaks Italian if the system language is Italian and English otherwise; you can force the language with `/en` or `/it`, for example `repair-usb4-boot.bat /en`. In Italian it asks for `SI` instead of `YES`, and both answers are accepted. Full usage: `repair-usb4-boot.bat [drive:] [/check] [/it or /en]`.

**Status:** the previous version of the script, without `/check` and without the `ThunderboltBoot` check, was verified in WinRE on 30/10/2026. The current version was tried on 30/10/2026 from running Windows with `/check`, and in WinRE with `/check`, with the drive as argument and in normal mode, on an encrypted drive with the values already correct: it checked everything and wrote nothing. An actual repair, of the values or of `ThunderboltBoot`, has not yet been tried with the current version.

Without the script, the same commands by hand:

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

- `Current` must be `0x1`, that is `ControlSet001`. If it is `0x2`, replace `ControlSet001` with `ControlSet002` in all the commands.
- If `BootDriverFlags` is not `0x14`, set it with `reg add HKLM\OFF\ControlSet001\Control /v BootDriverFlags /t REG_DWORD /d 0x14 /f`. On its own it is not enough to make Windows start, but it is part of the verified configuration.
- **Don't forget `reg unload`:** without it, the changes might not be saved.

### 6.4 Restart and tidy up

1. Type `exit` and choose **Turn off your PC**. **Do not choose *Continue***: it starts the firmware's default entry, that is the internal system, and on 30/10/2026 it really did, with the enclosure connected and the SSD's BitLocker protection suspended.
2. Power on, press F12 and choose the external Windows entry. If `ThunderboltBoot` has just been enabled (Phase 7), first reconnect the enclosure to the Thunderbolt port with the Thunderbolt cable.
3. Enter the PIN, or the recovery key if the BIOS has changed.
4. In Windows, in *Command Prompt as administrator*:
   ```
   reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4HostRouter /v Start
   reg query HKLM\SYSTEM\CurrentControlSet\Services\Usb4DeviceRouter /v Start
   bcdedit /set {fwbootmgr} displayorder {bootmgr} /addlast
   manage-bde -status C:
   ```
   The first two must show `0x0`. The third moves the external Windows entry back to the bottom, so the default boot goes back to the internal system. If the last one shows protection off, turn it back on with `manage-bde -protectors -enable C:` (step 5.6.6).

---

## Phase 7 — If the SSD disappears from the F12 menu after a BIOS update or reset

**Symptom**, observed on 30/10/2026 after a BIOS update: the F12 menu only shows *Windows Boot Manager*, the internal drive and *HTTPs Boot*, and the SSD's entries are gone. The BIOS settings are back to their defaults, including the battery charge limit. On the external Windows, once it is running again, BitLocker protection is suspended. During that update *This boot will take longer than usual* and *Unrecoverable SPI Error* (code 3,6) also appeared, then the BIOS restarted with the new version.

**Cause:** `ThunderboltBoot` is back to `Disabled`. Without it, the firmware does not create the Thunderbolt tunnel before boot, does not see the SSD and deletes its boot entries. We do not know whether every BIOS update resets the settings to their defaults, or whether it happened because of the SPI error. The same applies to a reset of the BIOS settings, and to an update done from the internal system.

**Repair, without Ubuntu:** with the enclosure in USB mode the firmware sees the SSD even without `ThunderboltBoot`. Windows does not start in that mode, but the recovery environment does, and from there you turn `ThunderboltBoot` back on through the BIOS WMI interface. All the steps below were verified on 30/10/2026, unless stated otherwise.

**What you need:**
- a **USB-C → USB-A cable** and a USB-A port on the notebook;
- the external SSD's **recovery key**, with its ID (step 5.6.4);
- the scripts in `C:\Repair\` (step 5.1). If they are not there, step 7.2 explains how to type the minimal VBScript by hand.

### 7.1 Reach the recovery environment in USB mode

1. With the PC off, connect the enclosure with the **USB-C → USB-A cable to a USB-A port**. This way the enclosure works in USB mode, through its Realtek chip, and the firmware sees the SSD without `ThunderboltBoot`. With a USB-C cable on a Thunderbolt port the enclosure negotiates Thunderbolt anyway, and the firmware does not see it.
2. Power on and press F12. An entry like *UEFI Realtek ACASIS …* must appear: choose it. If it does not appear, the problem is the cable or the port.
3. Windows **does not start** in USB mode: it hits `INACCESSIBLE_BOOT_DEVICE`, and this is the expected behaviour. After the failed attempts Automatic Repair appears, and the recovery environment does start.
4. BitLocker asks for the recovery key: check the ID and enter it. After that, in the prompt the volume is already unlocked.
5. From the Automatic Repair screen: **Advanced options → Troubleshoot → Advanced options → Command Prompt**. In the prompt the Windows drive was `D:`; `X:` is the recovery environment itself. Check with `dir D:\Windows`, and if the volume is locked unlock it as in step 6.2.

### 7.2 Turn ThunderboltBoot back on

All commands are run in the *WinRE prompt*.

**With the repair script (main route).**

```
D:\Repair\repair-usb4-boot.bat
```

The script checks the registry first: on 30/10/2026 the values were already correct, and in that case it writes nothing. Then it reads `ThunderboltBoot` with `thunderbolt-boot-on.vbs`: if it is `Disabled`, answer `YES` to enable it. The current version of the script was tried in WinRE on 30/10/2026, but only with the values already correct and `ThunderboltBoot` already `Enabled`: enabling it from the script has not been tried yet, while writing it with WMI from the Recovery Environment is verified (alternative below).

**By hand, with `wmic` and the VBScript (alternative).** Read the value, read-only:

```
wmic /namespace:\\root\dcim\sysman\biosattributes path EnumerationAttribute where "AttributeName='ThunderboltBoot'" get AttributeName,CurrentValue
```

On 30/10/2026 the result was `Disabled`: `ThunderboltBoot` still exists after the update. Enable it and read it back:

```
cscript //nologo D:\Repair\thunderbolt-boot-on.vbs
```

The script must answer `Status = 0`, and reading back must give `Enabled`. On 30/10/2026 reading back with `wmic` gave `Enabled` straight away.

**If the scripts are not there**, type the minimal VBScript with `notepad`. The command `notepad D:\Repair\thunderbolt-boot-on.vbs` opens the file, and offers to create it if it does not exist (if the folder is missing, first `mkdir D:\Repair`). Type:

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

Save, close `notepad` and run `cscript //nologo D:\Repair\thunderbolt-boot-on.vbs`. Watch out for `o.ExecMethod_`: it is the letter **o**, not zero. Typed as `0.ExecMethod_`, VBScript answers with an error. Then read the value back with `wmic`.

Meaning of `Status`: 0 success, 1 failed, 3 access denied because a BIOS administrator password is set. In the last case nothing can be done without the password: if the PC is not yours, ask whoever manages it.

### 7.3 Back to the external Windows

1. Type `exit`, then choose **Turn off your PC**. Do not choose *Continue*: it starts the firmware's default entry, that is the internal system.
2. Reconnect the enclosure with the **Thunderbolt cable to the Thunderbolt port**.
3. Power on and press F12: the SSD's entry must be back, for example *UEFI WD_BLACK SN850X …*. Choose it: Windows starts via Thunderbolt. Enter the PIN, or the recovery key if it asks for it: the BIOS has changed (step 5.6.6).
4. In Windows, in *Command Prompt as administrator*:
   - turn BitLocker protection back on, since the BIOS update suspended it: `manage-bde -status C:`, then `manage-bde -protectors -enable C:`;
   - put the boot entries back in order as in step 5.2. Windows recreates its own entry and puts it in first place.

Not verified: restarting with the PIN after protection is turned back on.

### 7.4 Checklist after a BIOS update or reset

It also applies when the BIOS is updated from the internal system.

- [ ] `ThunderboltBoot` = `Enabled` (`C:\Repair\repair-usb4-boot.bat /check` as administrator, or `wmic` as in step 7.2).
- [ ] `PreBootDma` (*Pre-Boot DMA Support*) and Secure Boot enabled, in the BIOS (F2).
- [ ] Battery charge limit: *Battery Charge Configuration* = *Custom*, with start 65 and stop 70. Dell requires at least 5 points of difference; the choice in testing is 70%. Not verified that the setting has been restored.
- [ ] Boot order with `bcdedit` (step 5.2).
- [ ] BitLocker protection on (`manage-bde -status C:`).

**Do not use *Save as Custom User Settings*** when leaving the BIOS: it would overwrite any custom profile already saved, and it has not been shown to survive an update.

### 7.5 The F12 menu: *Pre-Boot Tasks*

The F12 menu has a *Pre-Boot Tasks* section:
- **to use:** *BIOS Setup*; *Diagnostics*, which runs read-only tests and is useful after errors such as *Unrecoverable SPI Error*;
- **to avoid:** *BIOS Update* and *BIOS Flash Update – Remote*, because a BIOS update can turn `ThunderboltBoot` off, as on 30/10/2026; if someone else manages the PC, the BIOS version is their decision; *SupportAssist OS Recovery*, which restores the internal drive's system;
- ***Device Configuration***: we do not know what it contains. Explore it read-only only.

---

## Everyday rules

1. **Connect the enclosure before powering on** the notebook, then F12 → *Windows External SSD*. As a fallback there is the firmware entry *UEFI* followed by the SSD model.
2. **Never disconnect the enclosure while Windows is running:** it is the system drive.
3. **Disconnect the enclosure before starting the internal system.** With `ThunderboltBoot` enabled, an enclosure connected at power-on is authorized automatically, and the internal system would see the SSD. All the more so if the SSD's BitLocker protection is suspended, for example after a BIOS update: in that case the internal system could read its files.
4. **After a Windows update**, if Automatic Repair or the BitLocker screen asking for the key appears, follow Phase 6. Check the boot order again too (Phase 5.2). If you installed `Usb4BootGuard`, check its events with `-Status` (Phase 5.9), even when Windows restarted without problems.
5. **After a BIOS update or reset**, even one done from the internal system, follow Phase 7: if the SSD has disappeared from the F12 menu turn `ThunderboltBoot` back on, then go through the checklist in step 7.4.
6. **No BIOS updates from the external Windows**, neither from Windows Update nor from Dell programs (steps 5.1, 5.4 and 5.10). In WinRE, after `exit`, always choose **Turn off your PC** and never *Continue*.
7. **Before major changes**, such as a new driver or a system program, create a restore point (Phase 5.8).

---

## If ThunderboltBoot is not available

- **Windows in USB mode: it does not work.** The ACASIS enclosure also has a Realtek USB bridge. If you connect it to a USB-A port with a USB-C → USB-A cable, the firmware sees it as a USB drive even without `ThunderboltBoot`, and *UEFI Realtek ACASIS …* appears in the F12 menu. On 30/10/2026, however, in USB mode the recovery environment started and Windows did not: it stopped with `INACCESSIBLE_BOOT_DEVICE`. The cause has not been established. USB mode is therefore useful only to reach the recovery environment (Phase 7).
- **Linux.** Linux can boot from a Thunderbolt SSD even without firmware support: you put the ESP and `/boot` on a USB stick, and the kernel creates the tunnel by itself thanks to the `thunderbolt` module in the initramfs. Not verified in this guide.
