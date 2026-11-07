**🌐 Language:** **English** · [Italiano](how-it-works.it.md)

# How it works

This page explains why Windows, out of the box, does not boot from a Thunderbolt SSD on this notebook, and why the fix works. Observed facts are kept separate from interpretations.

---

## 1. Thunderbolt is PCIe inside a tunnel

An NVMe SSD in a Thunderbolt enclosure is a PCIe device in every respect, but the PCIe link runs inside a **tunnel** created over the Thunderbolt/USB4 cable. Something has to create and manage that tunnel: that is the job of the **connection manager**.

- In older Thunderbolt controllers the connection manager lived in the controller firmware (*firmware connection manager*).
- In USB4 controllers, such as the Intel Thunderbolt 5 controller of the notebook used in testing, the connection manager is **software**: the operating system runs it, through its drivers.

It follows that, **before the operating system starts**, the tunnel exists only if the PC firmware takes the trouble to create it.

---

## 2. First obstacle: the firmware does not create the tunnel

**Observed fact.** With the default settings, the external SSD appears neither in the F12 menu nor in the BIOS File Explorer, which lists only the partitions of the internal drive.

**Cause.** Dell business notebooks have the options *Enable Thunderbolt Boot Support* and *Enable Thunderbolt Pre-boot Modules*, which make the firmware create the PCIe tunnel before boot. The BIOS of the notebook used in testing does not show them, but the note in the *USB/Thunderbolt Configuration* section mentions them anyway.

**Solution.** The firmware contains the `ThunderboltBoot` attribute, visible from Linux through the `dell-wmi-sysman` driver at `/sys/class/firmware-attributes/dell-wmi-sysman/attributes/ThunderboltBoot`. When it is set to `Enabled`, after a restart the SSD appears both in the F12 menu and in the BIOS File Explorer.

In the File Explorer the path of the external SSD clearly shows the tunnel: a chain of `Pci(...)` nodes, one for each PCIe bridge to cross (root port, the notebook's Thunderbolt controller, the enclosure's controller), before reaching `NVMe(...)`.

**Security consequence.** As the BIOS note warns, devices connected during pre-boot keep working in the operating system regardless of the Thunderbolt security level set, until they are disconnected.

---

## 3. Why the installation works

During installation the PC boots from the USB stick: the firmware only has to read the stick. The system that starts is **WinPE**, a reduced Windows loaded entirely into RAM. Once started, WinPE loads its own drivers, including the USB4 ones: it is WinPE that creates the tunnel and sees the SSD. The firmware never has to read the SSD.

This is why, without `ThunderboltBoot`, the installation succeeds but the restart does not: the firmware does not find the SSD and moves on to the next entry, that is, the internal system.

---

## 4. Second obstacle: Windows loses the disk during the handoff to the kernel

**Observed fact.** With `ThunderboltBoot` enabled, the firmware loads the boot manager from the SSD, and the boot manager loads the kernel and the boot drivers. Then Windows stops with `INACCESSIBLE_BOOT_DEVICE` (0x7B).

**What 0x7B means.** The kernel has started, but it cannot access the volume it was booted from.

**Interpretation** (consistent with all tests, but not officially documented by Microsoft or Dell). In the phase before the kernel, the boot manager reads files from the SSD through the firmware, which keeps the tunnel active. When the kernel takes control, management of the USB4 domain passes to the Windows software connection manager, that is, to the `Usb4HostRouter` and `Usb4DeviceRouter` drivers. In a standard installation these drivers have `Start = 3`: they are loaded on demand, after boot. At the moment the kernel looks for the system disk, nobody manages the tunnel, and the disk cannot be reached.

Other reports describe the same symptom on other USB4 notebooks, while the same SSD in USB 3 mode booted normally.

---

## 5. Why `BootDriverFlags` is not enough

`BootDriverFlags` is a registry value that asks Windows to load entire families of drivers at boot. The value `0x14` covers the USB and USB 3 disk drivers, and it is the classic fix for booting Windows from an SSD in a USB enclosure.

**Observed fact.** With `BootDriverFlags = 0x14` alone, the blue screen stays the same.

**Interpretation.** Those flags concern the USB disk stack, not the USB4 drivers that manage the PCIe tunnel. In fact, after the change, `Usb4HostRouter` and `Usb4DeviceRouter` still had `Start = 3`.

---

## 6. The fix

Setting `Start = 0` (*boot start*) for `Usb4HostRouter` and `Usb4DeviceRouter`:
- the boot manager loads the two drivers together with the other boot drivers;
- the kernel initializes them early enough to take over management of the tunnel before looking for the system disk.

**Observed fact.** With this change, together with the already present `BootDriverFlags = 0x14`, Windows Setup resumes from the external SSD over Thunderbolt.

Both services have `ErrorControl = 1`: if either of them failed to load at boot, Windows would log the error and continue, without stopping.

**Observed fact: updates undo the fix.** A Windows update reinstalled the USB4 drivers with the default value, `Start = 3`. The next restart ended in `INACCESSIBLE_BOOT_DEVICE` and then in Automatic Repair. The driver log (`C:\Windows\INF\setupapi.dev.log`, *Install Driver Updates* section) shows that the reinstallation happened **after** the restart was requested, during the update installation phase that precedes shutdown. Checking the values before restarting is therefore not enough.

**Observed fact: service-level `BootFlags` does not replace `Start = 0`.** A service can have its own `BootFlags` value, which asks the boot loader to load it as a boot driver when Windows starts from a USB disk. With `BootFlags = 0x14` on `Usb4HostRouter` and `Usb4DeviceRouter` and `Start = 3`, Windows did not start and went to Automatic Repair. **Interpretation:** the boot loader does not consider the Thunderbolt SSD a USB disk (it reaches it as NVMe over a PCIe tunnel), so the flags are ignored. This route therefore does not protect against updates.

**Prevention under test: the `Usb4BootGuard` service** (not verified with a real update). For the 16 October update, the driver log and the system event log give this sequence:

| Time | Event |
|---|---|
| 18:47:26 | Restart requested for the update (event 1074) |
| 18:47:39 | `setupapi.dev.log`, *Install Driver Updates* section: *Configure Driver*, then "Updated service" for `Usb4DeviceRouter` and `Usb4HostRouter`. This is where `Start` goes back to 3 |
| 18:48:21 | Event Log service stopped (event 6006) |

**Observed facts.** The reset happens when Windows configures the new driver package, without reinstalling the device, and about 40 seconds before services stop.

**Interpretation.** At that moment a service that asks to be notified of registry changes (`RegNotifyChangeKeyValue`) is still running, and can set `Start = 0` again before shutdown. For the same reason, solutions that act when a device is installed, such as blocking it with device installation policies or an extension INF, do not help: no device was installed during that update. Locking the key with permissions would instead prevent the driver update, with the risk that Windows rolls back the whole update. The service is in `windows/usb4-boot-guard/` and is described in Phase 5.9 of the guide.

**Repair.** The Windows Recovery Environment (WinRE) starts from the SSD and sees the Windows partition: like the installer, it runs from RAM and rebuilds the Thunderbolt tunnel with its own drivers. From there you load the offline registry with `reg load` and set the values again. This is Phase 6 of the guide, with the script `windows/repair-usb4-boot.bat`, which also checks `ThunderboltBoot` (section 9).

---

## 7. Why the internal system seemed to start

During testing, choosing the SSD from the F12 menu seemed to boot the Windows on the internal drive, as if the firmware ignored the choice. What actually happened was this:
1. Windows started from the SSD and hit a blue screen (0x7B);
2. it restarted by itself, as it does by default after an error;
3. on restart, the firmware used the default entry, that is, the internal system.

Temporarily unchecking all the other boot entries leaves the firmware with no alternatives, and the blue screen stays visible. It is the simplest way to diagnose what is really happening.

---

## 8. Why Linux is different

Linux has the **initramfs**: a small self-contained system, loaded together with the kernel, that already contains the `thunderbolt` and `nvme` drivers. The Linux software connection manager runs inside it, before mounting the root: it finds the existing tunnels or recreates them, and only then looks for the system disk.

Windows has no separate equivalent: its boot drivers live on the system volume and must be marked as such in the registry. That is exactly what the fix does.

---

## 9. The BIOS WMI interface, from Linux and from Windows

**Facts.** The Dell BIOS attributes, `ThunderboltBoot` included, can be reached in two ways:
- **from Linux**, with the `dell-wmi-sysman` driver, in `/sys/class/firmware-attributes/dell-wmi-sysman/attributes/`. This is what `scripts/check-bios.sh` and `scripts/thunderbolt-boot.sh` use;
- **from Windows and its recovery environment**, in the WMI namespace `root\dcim\sysman\biosattributes`:
  - the `EnumerationAttribute` class for reading, with the `CurrentValue` and `PossibleValue` properties;
  - the `BIOSAttributeInterface` class, with the `SetAttribute` method, for writing. The method returns `Status`: 0 success, 1 failed, 3 access denied because a BIOS administrator password is set. With `SecType = 0` and `SecHndCount = 0` the call uses no password.

It is the same set of attributes. On 30/10/2026, with the updated BIOS, `ThunderboltBoot` was read with `wmic` and written with a VBScript from the recovery environment (build 26100), which has no PowerShell but has `wmic` and `cscript`. The `windows/thunderbolt-boot-on.vbs` script uses the same calls.

**Interpretation.** The interface is exposed by the firmware through the ACPI-WMI driver built into Windows, not by a Dell driver. This is suggested by the fact that it works in the recovery environment.

---

## 10. Why a BIOS update or reset breaks booting

**Observed facts** (30/10/2026, after a BIOS update):
- the BIOS settings went back to their defaults, and `ThunderboltBoot` was `Disabled`;
- the F12 menu only showed *Windows Boot Manager*, the internal drive and *HTTPs Boot*: the SSD's entries were gone;
- the registry values of the fix (section 6) were still correct;
- once `ThunderboltBoot` was turned back on, the SSD's entry came back, and Windows, once started, recreated its own boot entry and put it in first place.

**Explanation.** With `ThunderboltBoot` off the firmware does not create the tunnel before boot (section 2), so for the firmware the SSD is not there, and its entries disappear from the menu. The registry fix is useless until the firmware can read the boot manager from the SSD. At the first successful boot, Windows behaves as at the end of Setup (guide, step 5.2): it recreates its own entry and puts it at the top.

**Open question.** We do not know whether every BIOS update resets the settings to their defaults, or whether it happened because of the *Unrecoverable SPI Error* that appeared during that update.

---

## 11. The dual-chip enclosure and USB mode

**Observed facts.** The ACASIS enclosure used in testing has two chips: a Thunderbolt controller (Intel JHL7440) and a USB bridge (Realtek RTL9210B).
- With a USB-C cable on a Thunderbolt port, the enclosure negotiates Thunderbolt: the SSD is a PCIe device in the tunnel, and the firmware sees it only with `ThunderboltBoot` enabled. This applies both to the Thunderbolt cable and to an ordinary USB-C cable.
- With a USB-C → USB-A cable on a USB-A port, the enclosure works in USB mode: the SSD is a USB drive, the firmware sees it even without `ThunderboltBoot`, and *UEFI Realtek ACASIS …* appears in the F12 menu.
- In USB mode the Windows Recovery Environment starts and works. Windows, on the other hand, does not start: it stops with `INACCESSIBLE_BOOT_DEVICE`. The cause has not been established.

**Interpretation.** The recovery environment runs from RAM, like the installer (section 3): once loaded, it finds the drives with its own drivers, whatever the connection. Windows instead has to find the system disk again during boot, and in USB mode it fails to.

**Consequence.** USB mode is useful only to reach the recovery environment when `ThunderboltBoot` is off, in order to turn it back on (guide, Phase 7).

---

## 12. BitLocker and PCR7

**Observed facts.** On the external Windows, BitLocker events 813, 881 and 893 say that BitLocker cannot use Secure Boot for integrity validation (PCR7), and therefore uses the PCR 0, 2, 4, 11 profile. After the BIOS update of 30/10/2026 the protection was suspended, and the recovery key was requested at boot.

**Consequence.** With this profile, every BIOS or firmware change makes BitLocker ask for the recovery key. Why PCR7 cannot be used in this configuration is still to be verified.

**Check, read-only,** in Command Prompt as administrator:

```
manage-bde -protectors -get C: -Type TPMAndPIN
```

Never `-get` without `-Type`: it also prints the recovery key.

**Suspension.** BIOS updates suspend the protection. While it is suspended, the SSD is readable by any system, so the internal system must not be started with the enclosure connected. Turn it back on with `manage-bde -protectors -enable C:` (guide, step 5.6.6).

---

## 13. Security notes

- **`ThunderboltBoot`** makes the firmware authorize devices connected to the Thunderbolt port at power-on, before the operating system's protections start. On other Dell models the same feature, enabled by default, was classified as a DMA vulnerability ([CVE-2019-18579](https://nvd.nist.gov/vuln/detail/CVE-2019-18579)). That is why it should be enabled only when needed, and together with `PreBootDma`.
- **`Pre-Boot DMA Support` (`PreBootDma`)** enables IOMMU protection before boot. It must stay **Enabled**.
- **Secure Boot** stays enabled throughout the procedure: the Windows boot manager on the SSD is properly signed and is accepted.
- With `ThunderboltBoot` enabled, disconnect the enclosure before booting another operating system, if you do not want that system to see the SSD.
- **BIOS updates** can turn `ThunderboltBoot` off and suspend BitLocker protection (sections 10 and 12). The Dell software that can start them from the external Windows must be blocked (guide, step 5.10).
