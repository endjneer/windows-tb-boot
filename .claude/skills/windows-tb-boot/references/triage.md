# Triage: from the situation to the section of the guide

Find the row that matches where the user is and what they see, then open the section in `repo/docs/guide.md` (or `guide.it.md`). Sections are cited as `guide §N.N`; *quick-recovery* and *troubleshooting* sections are cited by title. The guide is written for the tested laptop: for any other laptop start from *Other hardware* at the end.

## Emergencies: Windows on the SSD no longer starts

| Where / what the user sees | Probable cause | Go to |
|---|---|---|
| After a **Windows update**: *Preparing Automatic Repair*, then BitLocker asks for the recovery key | The update set the USB4 drivers back to `Start = 3` | quick-recovery A; guide §6.2, §6.3, §6.4 |
| After a **BIOS update or reset**: the SSD is missing from the F12 menu | `ThunderboltBoot` is back to `Disabled` | quick-recovery B; guide §7.1, §7.2, §7.3, then the checklist in guide §7.4 |
| In USB mode (USB-C → USB-A cable): no *UEFI Realtek …* entry in F12 | Wrong cable or port | troubleshooting, "The *UEFI Realtek …* entry does not appear in the F12 menu" |
| In USB mode Windows stops with `INACCESSIBLE_BOOT_DEVICE` | Expected: in USB mode only WinRE starts | guide §7.1 (continue to WinRE) |
| The BIOS script answers `Status = 3` | BIOS administrator password | **Stop.** Explain, never help to bypass it; the person who manages the PC decides (guide §7.2) |
| After `exit` and *Continue* the internal system started | *Continue* boots the firmware default | troubleshooting, "After `exit` and *Continue* the internal system starts"; next time *Turn off your PC* |
| The user chooses the SSD in F12 but the internal system starts | Boot entry or order | troubleshooting, "I choose the SSD from the F12 menu, but the internal system starts" |

## New installation

| Situation | Go to |
|---|---|
| Nothing done yet | guide §0.1, then the phases in order; first the README warnings |
| Before enabling anything: does this laptop have `ThunderboltBoot`? | guide §1.4 (`scripts/check-bios.sh`, read only) |
| `check-bios.sh` says `ThunderboltBoot` does not exist | troubleshooting, "`check-bios.sh` says that `ThunderboltBoot` does not exist": the procedure does not apply |
| `check-bios.sh` reports a BIOS administrator password | **Stop**, as for `Status = 3` |
| SSD not in F12 before any change | guide §1.5, then §1.6 |
| In the installer, choosing the disk | guide §2.3. The user identifies the SSD by size and model. **Internal disk visible (AHCI/NVMe mode): never help choose a disk to erase** (see `safety.md`) |
| `INACCESSIBLE_BOOT_DEVICE` at the first restart of Setup | guide §3.3 (registry fix from the live session); without Linux, guide §3.4, not verified |
| Boot entry and completing Setup | guide §4.1, §4.4 |
| Windows started from the SSD for the first time | guide §5.1 **before going online**, then §5.2 and the rest of Phase 5 |

## Maintenance, external Windows running

| Situation | Go to |
|---|---|
| Check that everything is in place | `read-only-checks.md`, *External Windows* |
| Boot order: the external entry is first again | guide §5.2 |
| Hide the internal disk from the external Windows | guide §5.5.2 (policy block). Guide §5.5.1 uses `diskpart` on the internal disk: the user follows it alone, from the guide |
| BitLocker on the external SSD; recovery key | guide §5.6, §5.6.4 |
| BitLocker protection off after a BIOS update | guide §5.6.6 |
| Prevent Windows updates from breaking the boot | guide §5.9 (`Usb4BootGuard`, not verified with a real update) |
| Stop Dell software from updating the BIOS | guide §5.10 |
| Before a Windows or BIOS update | the everyday rules at the end of the guide; scripts in `C:\Repair\` and recovery key at hand |
| Black screen after sleep with the fans running, a blue screen shortly after a resume, or a hang while hibernating | troubleshooting, "After sleep the screen stays black and the fans keep running"; guide §5.7. Solutions not verified |
| Black screen with the fans running and no automatic restart, also without sleep; Win + Ctrl + Shift + B has no effect | troubleshooting, "The screen stays black, the fans spin and Windows does not restart by itself". Solution not verified |
| Hangs or blue screens with a Thunderbolt dock connected | troubleshooting, "With a Thunderbolt dock connected Windows hangs or shows a blue screen". Not verified |

## Other hardware

Everything in this section is **not verified**: say so at every step. Use the three questions in `SKILL.md`.

| Situation | What to do |
|---|---|
| Another Dell laptop | First `scripts/check-bios.sh` from the live session (guide §1.4). If `ThunderboltBoot` exists, follow the guide phase by phase. At the end, a *Compatibility report* without identifiers |
| Another brand: the SSD is **not** in the firmware boot menu | The Dell BIOS part (`ThunderboltBoot`, `thunderbolt-boot.sh`, `thunderbolt-boot-on.vbs`) does not apply: never run those scripts there. There may be a BIOS option for Thunderbolt or USB4 boot support: suggest the laptop's manual, without presenting any setting name as certain. Without firmware support, native boot from the SSD is not possible |
| Another brand: the SSD **is** in the boot menu, but Windows stops with `INACCESSIBLE_BOOT_DEVICE` (for example at the first restart of Setup) | Question 2: the USB4 drivers. The Windows fix of guide §3.3 (offline registry of the installation on the SSD) may apply. Before any write: the user identifies the Windows partition **on the external SSD** by model and size (`lsblk`); the internal disk is often visible on these laptops, so at the slightest doubt, stop. Recovery keys of both disks at hand |
| Any laptop, after a Windows update: *Preparing Automatic Repair* | Question 3: guide §6.2, §6.3, §6.4. In WinRE, check which drive is the external SSD's Windows before running anything |
| An enclosure other than the tested ACASIS | USB mode for recovery (guide §7.1) needs a dual-chip enclosure with a USB bridge: not verified on others |

Any other symptom: search the titles of `repo/docs/troubleshooting.md`.
