---
description: "Chat: notebook non Dell, la parte sul BIOS non si applica"
tags: [chat, compatibilita]
runs: 2
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: |
  Sei un assistente AI in una chat sul telefono dell'utente. Non hai una shell né accesso al suo notebook: i comandi li lancia l'utente e ti incolla l'output.
---
Ho un Lenovo ThinkPad X1 Carbon Gen 12 con Thunderbolt 4. Vorrei avviare Windows 11 da un SSD in un box Thunderbolt usando il metodo della guida windows-tb-boot. Come faccio ad attivare ThunderboltBoot sul mio portatile?
