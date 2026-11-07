**🌐 Language:** **English** · [Italiano](README.it.md)

# Windows 11 from an external Thunderbolt SSD on a Dell notebook

A guide and scripts to install and **natively boot** Windows 11 from an NVMe SSD mounted in a Thunderbolt enclosure, on a Dell notebook, **without modifying the internal drive**.

> ⚠️ **This procedure is supported by neither Dell nor Microsoft.** It involves changing a hidden BIOS setting and the registry of a Windows installation. Read the [Warnings](#warnings) section before you start.

> 🚑 **Emergency?** Windows does not start after an update, or the SSD has disappeared from the F12 menu: **[docs/quick-recovery.md](docs/quick-recovery.md)**, the minimal steps on one page.

---

## The problem in brief

On this notebook, Windows **installs** to an external Thunderbolt SSD without trouble, but then **does not boot**. There are two obstacles, independent of each other:

1. **The firmware does not see Thunderbolt drives before boot.** The option that enables this (`Enable Thunderbolt Boot Support`) exists in the firmware, but the BIOS menu does not show it. It is enabled from Linux through the kernel's `dell-wmi-sysman` interface, or from the Windows Recovery Environment through the BIOS WMI interface.
2. **Windows loses the drive during the handoff from firmware to kernel** and stops with the `INACCESSIBLE_BOOT_DEVICE` (0x7B) blue screen. The reason is that the USB4 drivers that manage the Thunderbolt tunnel (`Usb4HostRouter` and `Usb4DeviceRouter`) are loaded only after boot. The fix is to set them as boot drivers in the registry of the external installation.

Two kinds of update can undo these fixes, and both are repaired from the Windows Recovery Environment, without Ubuntu:
- **Windows updates** set the USB4 drivers back to `Start = 3`, and Windows no longer starts (Phase 6 of the guide);
- **BIOS updates**, or a reset of the settings, can set `ThunderboltBoot` back to `Disabled`, and the SSD disappears from the F12 menu (Phase 7). It happened on 30/10/2026: the report is in [docs/incident-2026-10-30.md](docs/incident-2026-10-30.md).

The full technical explanation is in [docs/how-it-works.md](docs/how-it-works.md).

---

## Verification status

| Step | Status |
|---|---|
| Enabling `ThunderboltBoot` from Linux; SSD visible in the F12 menu and in the BIOS File Explorer | ✅ verified |
| The firmware starts the Windows boot manager on the SSD | ✅ verified |
| Without fixes: `INACCESSIBLE_BOOT_DEVICE` blue screen | ✅ observed |
| `BootDriverFlags = 0x14` alone: still `INACCESSIBLE_BOOT_DEVICE` | ✅ observed |
| USB4 drivers loaded at boot (`Start = 0`) together with `BootDriverFlags`: Windows Setup resumes from the SSD | ✅ verified |
| Completion of Setup and offline initial setup (OOBE), including the Setup reboots | ✅ verified |
| Boot order restored with `bcdedit` (internal system default again) | ✅ verified |
| Boot order stable across later reboots, after deleting the duplicate manual entry | ⏳ to be verified |
| Boot order after a Windows update | ⚠️ the external entry moves back to first place: reorder it with `bcdedit` (Phase 6.4) |
| Boot from the SSD after initial setup (F12 → *Windows External SSD*) | ✅ verified |
| Internal drive hidden from the external Windows (Intel VMD driver blocked) | ✅ verified |
| Fix surviving Windows updates | ❌ does not hold: two updates (15 and 16 October) set the USB4 drivers back to `Start = 3` during the installation phase of the restart. It therefore cannot be fixed before restarting |
| Service-level `BootFlags = 0x14` on the USB4 drivers, to boot with `Start = 3` | ❌ does not work: with `Start = 3` Windows does not start and goes to Automatic Repair (16 October) |
| `Usb4BootGuard` service, which sets `Start = 0` again while Windows is running (guide, Phase 5.9) | ⏳ to be verified with a real update. On the running system, `-SelfTest` passed (16 October): `Start` set back to 3 returns to 0 within 2–25 ms, thanks to the Windows notification |
| Repair from the Windows Recovery Environment with the manual commands, encrypted drive (Phase 6) | ✅ verified |
| Script `windows/repair-usb4-boot.bat`, with Windows running | ✅ verified, in the version before the one of 30/10 |
| Script `windows/repair-usb4-boot.bat`, from the Windows Recovery Environment | ✅ verified on 30/10 too (encrypted drive, Italian messages), in the version before the current one |
| Current versions of `repair-usb4-boot.bat /check` and `thunderbolt-boot-on.vbs /status`, with Windows running | ✅ verified on 30/10, with and without administrator rights. Without them, `ThunderboltBoot` cannot be read (access denied, as expected) |
| Current versions of the two scripts from the Recovery Environment (`/check`, `/status`, normal mode) | ✅ verified on 30/10, encrypted drive, with the values already correct: nothing written |
| Actual repair with the current versions (registry values, enabling `ThunderboltBoot`) | ⏳ to be verified: it can only be tried when it is really needed |
| Reading and writing `ThunderboltBoot` from the Recovery Environment, with WMI (`wmic` and VBScript) | ✅ verified on 30/10, with the updated BIOS |
| Enabling `ThunderboltBoot` from the running external Windows | ⏳ to be verified |
| Recovery Environment booted in USB mode (USB-C → USB-A cable on a USB-A port) | ✅ verified on 30/10 |
| Windows booted in USB mode | ❌ does not start: `INACCESSIBLE_BOOT_DEVICE` (30/10); cause not established |
| `ThunderboltBoot` after a BIOS update | ⚠️ back to `Disabled` (30/10): repair in Phase 7 |
| BitLocker after the BIOS update | ⚠️ protection suspended and recovery key requested (30/10): it must be turned back on (Phase 5.6.6) |
| Restart with the PIN after protection is turned back on | ⏳ to be verified |
| Block of the Dell software that updates the BIOS (Phase 5.10) | ⏳ applied on 30/10, whether it holds is to be verified |
| Installation without Ubuntu, from the Windows stick with Shift+F10 (Phase 1 and step 3.4) | ⏳ to be verified |
| BitLocker TPM + PIN encryption of the external SSD; unlock with the recovery key | ✅ verified |
| BitLocker unlock from the live session in the repair scripts | ⏳ to be verified |
| Sleep (Modern Standby, S0) | ⚠️ about twenty successful cycles; one unexplained hang after a resume, with no blue screen |
| Hibernation | ⏳ to be verified |
| Windows Recovery Environment booted from the Thunderbolt SSD, with access to the Windows partition | ✅ verified |
| Recovery from a restore point | ⏳ to be verified |
| Ubuntu installed on the external SSD | ⏳ to be verified |
| `windows-tb-boot` skill: the 10 simulated test cases in `evals/` (Claude Sonnet, chat and shell, 2 runs each, with and without the skill) | ✅ passed on 30/10 with the skill; without it the average score is 0.34. Run with `tools/run-evals.py` (`claude -p`, judge with 3 votes), because `claude plugin eval` could not start its sessions in the development environment. Simulated conversations, not real users |
| `windows-tb-boot` skill in Claude Code opened in the clone, on the external Windows | ⏳ to be verified |
| `windows-tb-boot` skill installed as a plugin from the marketplace | ⏳ to be verified |
| `windows-tb-boot` skill uploaded to claude.ai | ⏳ to be verified |
| `windows-tb-boot` skill in Codex or Gemini CLI | ⏳ to be verified |
| `windows-tb-boot` skill on laptops other than the tested one | ⏳ to be verified: guided diagnosis only |

If you complete one of the "to be verified" steps, open an issue or a pull request: it is the most useful way to make this guide reliable.

---

## Test environment

| Component | Model |
|---|---|
| Notebook | A recent Dell notebook: a single model was tested, and its name and BIOS versions are deliberately left out. `ThunderboltBoot` present both in the BIOS of the initial tests and after the update of 30/10/2026 |
| Notebook Thunderbolt controller | Intel Thunderbolt 5, software connection manager (USB4) |
| External enclosure | ACASIS TBU405Pro, dual chip: Intel JHL7440 (Titan Ridge, Thunderbolt 3) + Realtek RTL9210B (USB) |
| SSD | WD_BLACK SN850X 1 TB (NVMe Gen4) |
| Connection | Thunderbolt 5 port of the notebook, Thunderbolt cable, 40 Gb/s link (2 × 20 Gb/s) |
| Windows | Windows 11, build 26300 (26H2), media created with Rufus |
| Linux environment | Ubuntu Desktop 26.04.1 LTS in a live session (kernel 7.0) |
| Unchanged BIOS settings | Secure Boot on, Microsoft UEFI CA enabled, Pre-Boot DMA on, storage in RAID/RST mode (Intel VMD) |

**Other models.** The method may work on other Dell notebooks with a Thunderbolt 4/5 controller managed via USB4, provided the firmware contains the hidden `ThunderboltBoot` attribute. The [`scripts/check-bios.sh`](scripts/check-bios.sh) script tells you in a few seconds whether your model has it. On notebooks from other manufacturers the BIOS part does not apply.

---

## Warnings

- **PCs that are not yours.** If the notebook is not yours, ask whoever manages it for permission before changing the BIOS or booting another operating system. If a BIOS administrator password is set, `check-bios.sh` reports it and `thunderbolt-boot.sh` stops: do not try to get around it.
- **BitLocker on the internal drive.** Depending on the configuration, a change to the BIOS settings can make the internal Windows ask for the recovery key. **Make sure you can obtain it before you start.**
- **Windows updates can break booting.** This happened during testing: an update set the USB4 drivers back to `Start = 3`, and the external Windows stopped with `INACCESSIBLE_BOOT_DEVICE` and asked for the BitLocker recovery key. The repair is done from the Windows Recovery Environment (Phase 6 of the guide). Before updating, keep the external SSD's recovery key at hand. The `Usb4BootGuard` service (Phase 5.9) tries to prevent the problem, but it has not yet been verified with a real update.
- **BIOS updates can prevent booting from the SSD.** It happened on 30/10/2026: an update very probably started by Dell SupportAssist, which had reached the external Windows without being chosen, set `ThunderboltBoot` back to `Disabled` and suspended BitLocker protection. The repair is in Phase 7, prevention in Phase 5.10. The BIOS is a single one, shared with the internal system: if someone else manages the PC, updates are their decision.
- **Security.** With `ThunderboltBoot` on, the firmware authorizes devices connected to the Thunderbolt port at power-on by itself, before the operating system's protections start. A malicious device plugged in at boot can therefore attempt a DMA attack: on other Dell models the same feature, enabled by default, was classified as a vulnerability ([CVE-2019-18579](https://nvd.nist.gov/vuln/detail/CVE-2019-18579)). Keep Secure Boot and `Pre-Boot DMA Support` (`PreBootDma`, whose value `check-bios.sh` shows) on. How well `Pre-Boot DMA Support` actually protects on this model has not been verified.
- **The internal system can see the external SSD.** If the enclosure is connected at power-on, it is authorized even when you boot the internal system, which would see the SSD, along with every program running on it. Disconnect the enclosure before booting the internal system.
- **Undocumented option.** `ThunderboltBoot` is hidden from this model's BIOS menu and may not have been validated by Dell. You turn it off with `scripts/thunderbolt-boot.sh --disable` from the Ubuntu live session: the change applies from the next reboot, and from then on the external SSD can no longer boot. A BIOS update reset it to its default value on 30/10/2026 (Phase 7).
- **No warranty.** You use this guide and these scripts at your own risk. No script writes to the internal drive, but none of them checks by itself that the chosen drive is the external one. Protection relies on the BIOS RAID/RST mode, which hides the internal drive from the Windows installer and, with `modprobe.blacklist=vmd`, from the live session, and on your care. The sensitive points are:
  - `diskpart clean` in Phase 2, which erases the whole selected disk;
  - `patch-windows-hive.sh` and `restore-hive-backup.sh`, which modify the registry of the partition you specify: they ask for confirmation, and the first one shows the disk first and makes a backup copy;
  - `repair-usb4-boot.bat` in the Recovery Environment, which repairs the Windows installation on the drive it is run from, or on the drive you specify. With `/check` it changes nothing;
  - `thunderbolt-boot-on.vbs`, which writes the `ThunderboltBoot` attribute to the BIOS. Run from `repair-usb4-boot.bat` it asks for confirmation first; run on its own without `/status` it writes straight away, if the value is not already `Enabled`.

  In AHCI/NVMe mode the internal drive stays visible everywhere, and Windows Setup might write the boot files to its ESP.

---

## What you need

- The notebook, with access to the BIOS (F2) and the boot menu (F12).
- A Thunderbolt 3/4/5 NVMe enclosure with its **Thunderbolt cable**, and an NVMe SSD to dedicate to Windows: it will be erased.
- A **USB-C → USB-A cable**, for recovery only: if a BIOS update turns `ThunderboltBoot` off, it lets you reach the Windows Recovery Environment with the enclosure in USB mode (Phase 7). This applies to a dual-chip enclosure like the one used in testing.
- **Two USB sticks** of at least 8 GB: one for the Windows installation, one for the Ubuntu live session. It can be done with a single USB stick, but you will have to rewrite it between phases. Ubuntu is needed for the verified path; there is an alternative without Ubuntu, from the Windows stick with Shift+F10, not verified yet (Phase 1 and step 3.4 of the guide).
- The Windows 11 and Ubuntu Desktop LTS ISO images, and [Rufus](https://rufus.ie) to write them.
- An Internet connection in the live session, to download the repository and install a package (`libwin-hivex-perl`).

---

## Procedure

The step-by-step guide is in **[docs/guide.md](docs/guide.md)**. In summary:

| Phase | Where | What |
|---|---|---|
| 0 | On any PC | Preparing the two USB sticks |
| 1 | Ubuntu live | Checking and enabling `ThunderboltBoot` |
| 2 | Windows installer | First phase of the installation on the external SSD |
| 3 | Ubuntu live | Fixing the registry of the external installation |
| 4 | BIOS, then Windows | Dedicated boot entry and completion of Setup, without Internet |
| 5 | External Windows | Excluding firmware from Windows Update before going online, repair scripts, boot order, drivers, encryption, restore points, `Usb4BootGuard` service (5.9), blocking the Dell software that updates the BIOS (5.10) |
| 6 | Windows Recovery Environment | Repair when a Windows update prevents booting |
| 7 | Windows Recovery Environment, enclosure in USB mode | Turning `ThunderboltBoot` back on when the SSD disappears from the F12 menu after a BIOS update or reset |

If you run into problems, see [docs/troubleshooting.md](docs/troubleshooting.md). In an emergency: [docs/quick-recovery.md](docs/quick-recovery.md).

---

## AI assistant

The repository contains a skill for AI agents, `windows-tb-boot`, that guides you step by step through the procedure and the diagnosis: it works out where you are, takes you to the right section of the guide, and reads the command outputs with you. It is meant for any laptop with an SSD in a Thunderbolt or USB4 enclosure, but the procedure is verified only on the hardware described in [Test environment](#test-environment).

| Where | How to install it |
|---|---|
| Claude Code, opened in a clone of the repository | Nothing to do: the skill is in `.claude/skills/windows-tb-boot/` |
| Claude Code, anywhere else | `/plugin marketplace add endjneer/windows-tb-boot`, then `/plugin install windows-tb-boot@windows-tb-boot`. |
| claude.ai | Create the zip with `bash tools/build-skill.sh --zip`, or in File Explorer with *Compress to ZIP file* on the `.claude/skills/windows-tb-boot` folder, and upload it in the skills settings. Code execution must be enabled |
| Codex, Gemini CLI | Copy the `.claude/skills/windows-tb-boot` folder into `~/.agents/skills/` |

Choose one way only: with the clone open and the plugin installed, Claude Code shows the skill twice.

**Warnings**
- The agent does not replace the guide: it follows it. On its own it runs only read-only commands. The commands that change the BIOS, the registry, disks or BitLocker are run by you, after the agent has explained what they change.
- Do not use modes that approve commands automatically.
- Never write recovery keys, PINs, passwords, serial numbers or the Service Tag in the chat, and cover them in photos of the screen.

---

## Repository structure

```
.
├── README.md                 This document (English)
├── README.it.md              This document (Italian)
├── CLAUDE.md                 Instructions and safety rules for Claude Code
├── LICENSE
├── .gitattributes            Line endings: Windows scripts with CRLF, Bash scripts with LF
├── .claude/skills/windows-tb-boot/ Skill for AI agents; references/repo/ is a generated copy of the guide
├── .claude-plugin/           The repository as a Claude Code plugin and marketplace
├── docs/                     Each document in English (.md) and Italian (.it.md)
│   ├── guide.md              Step-by-step procedure
│   ├── quick-recovery.md     Quick recovery: the minimal steps in an emergency
│   ├── how-it-works.md       Technical explanation
│   ├── troubleshooting.md    Common problems and fixes
│   ├── incident-2026-10-30.md Report of the BIOS update of 30/10/2026
│   ├── piano-autoinstall.md  Development plan for the automatic-install USB stick (Italian only)
│   └── piano-skill-agenti*.md Plan of the AI agent skill (Italian only)
├── evals/                    Test cases of the skill, for claude plugin eval
├── tools/
│   ├── build-skill.sh        Updates, checks and zips the copy of the guide inside the skill
│   ├── run-evals.py          Runs the test cases in evals/ with claude -p
│   └── tests/                Tests of build-skill.sh
├── scripts/                  To be run in the Ubuntu live session
│   ├── check-bios.sh         Read-only check of the BIOS attributes and the Thunderbolt link
│   ├── thunderbolt-boot.sh   Enables or disables ThunderboltBoot
│   ├── patch-windows-hive.sh Applies the fix to the Windows registry, with a backup copy
│   └── restore-hive-backup.sh Restores the registry backup copy
├── registry/                 The registry changes in .reg format
│   ├── bootdriverflags.reg
│   └── usb4-boot-start.reg
└── windows/
    ├── repair-usb4-boot.bat  Recovery: resets the USB4 drivers and checks ThunderboltBoot, from WinRE or Windows; /check is read-only
    ├── thunderbolt-boot-on.vbs Reads (/status) and enables ThunderboltBoot through the BIOS WMI interface, from WinRE too
    ├── show-disk-paths.ps1   Read-only: shows which controller each drive depends on
    ├── usb4-boot-guard/      Service that sets Start = 0 again after updates (not verified)
    │   ├── Usb4BootGuard.cs  Service source code
    │   └── usb4-boot-guard.ps1 Installs, tests, checks or removes the service
    └── tests/                Pester tests of the service, on a test registry
```

The Bash scripts print their messages in Italian. `repair-usb4-boot.bat`, `thunderbolt-boot-on.vbs` and `usb4-boot-guard.ps1` speak English or Italian depending on the system language, and the language can be forced with `/en` or `/it`.

---

## How to undo everything

- **Registry fix:** `scripts/restore-hive-backup.sh` restores the backup copy created by the script.
- **ThunderboltBoot:** from the live session, `scripts/thunderbolt-boot.sh --disable`.
- **Boot entry:** in the BIOS, Boot Configuration → Boot Sequence → DELETE on the entry you created.
- **VMD driver block** (in the external Windows): `reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions" /f`, then in Device Manager *Action → Scan for hardware changes*. This command removes the whole policy, including the Dell software block.
- **Dell software block** (in the external Windows, Phase 5.10): remove only values 2 and 3 of the policy, with `reg delete "HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs" /v 2 /f` and the same command with `/v 3`.
- **`Usb4BootGuard` service** (in the external Windows): `windows\usb4-boot-guard\usb4-boot-guard.ps1 -Uninstall`, from a PowerShell opened as administrator.
- **Windows installation:** just erase or reformat the external SSD. In RAID/RST mode the internal drive is never modified.

---

## References

- [Windows 11 on USB4 (ASM2464PD) SSD cannot boot (BSOD Inaccessible Boot Device) from USB4 port](https://egpu.io/forums/thunderbolt-enclosures/windows-11-on-usb4-asm2464pd-ssd-cannot-boot-bsod-inaccessable-boot-device-from-usb4-port/), egpu.io: same symptom on another USB4 notebook.
- [Why is BSOD: INACCESSIBLE BOOT DEVICE reported if I put the NVMe SSD into a USB enclosure as a boot device?](https://learn.microsoft.com/en-us/answers/questions/5599163/why-is-bsod-inaccessible-boot-device-reported-if-i), Microsoft Q&A: use of `BootDriverFlags = 0x14`.
- Linux kernel documentation: `Documentation/ABI/testing/sysfs-class-firmware-attributes`, which describes the `/sys/class/firmware-attributes` interface used by `dell-wmi-sysman`.

---

## Contributing

Compatibility reports are the most valuable contribution: use the "Compatibility report" issue template, in English or Italian. Include the model, BIOS version, Thunderbolt controller, enclosure and outcome. **Do not publish serial numbers, Service Tags or other identifiers of your machine.**

---

## License

- Scripts (`tools/` included) and `.reg` files: MIT license, see [LICENSE](LICENSE).
- Documentation (`README.md`, `README.it.md`, the `docs/` folder, the skill in `.claude/skills/` and the test cases in `evals/`): [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).
