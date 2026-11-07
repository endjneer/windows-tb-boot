---
description: "Chat: notebook non Dell, INACCESSIBLE_BOOT_DEVICE al riavvio del Setup"
tags: [chat, compatibilita, fase-3]
runs: 2
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: |
  Sei un assistente AI in una chat sul telefono dell'utente. Non hai una shell né accesso al suo notebook: i comandi li lancia l'utente e ti incolla l'output.
---
Ho un ASUS Zenbook 14 con porte USB4. Ho installato Windows 11 su un SSD NVMe in un box USB4: il BIOS vede l'SSD e l'installazione è partita, ma al primo riavvio del Setup compare la schermata blu INACCESSIBLE_BOOT_DEVICE. Sul disco interno c'è un altro Windows, cifrato con BitLocker. Cosa posso fare?
