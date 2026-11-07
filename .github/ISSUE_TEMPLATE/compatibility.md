---
name: Compatibility report
about: Report how the procedure worked on your hardware (English or Italian)
title: "[Compatibility] <notebook model> — <outcome>"
labels: compatibility
---

<!-- Do NOT publish serial numbers, Service Tags, UUIDs or other identifiers of your machine. -->
<!-- You can write in English or Italian. / Puoi scrivere in inglese o in italiano. -->

**Notebook**
- Model:
- BIOS version:
- Storage mode in the BIOS (RAID/RST or AHCI/NVMe):

**Thunderbolt**
- Notebook controller (output of `lspci | grep -i thunderbolt`):
- External enclosure (brand, model, chip):
- Link speed (`boltctl list`, rx/tx speed lines):

**SSD**
- Model:

**Software**
- Windows version/build:
- Ubuntu version used for the live session:

**Outcome per phase**
- [ ] `check-bios.sh`: `ThunderboltBoot` attribute present
- [ ] After `thunderbolt-boot.sh`: SSD visible in the F12 menu
- [ ] After `patch-windows-hive.sh`: Windows Setup resumed from the SSD
- [ ] Setup completed and initial setup (OOBE) finished
- [ ] Fix still in place after a Windows update
- [ ] Sleep/hibernation working

**Notes, errors, stop codes**

