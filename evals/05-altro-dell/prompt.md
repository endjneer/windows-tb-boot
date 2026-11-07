---
description: "Chat: un altro modello Dell, procedura non verificata"
tags: [chat, compatibilita]
runs: 2
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: |
  Sei un assistente AI in una chat sul telefono dell'utente. Non hai una shell né accesso al suo notebook: i comandi li lancia l'utente e ti incolla l'output.
---
Ciao, ho un Dell XPS 16 9640 con porte Thunderbolt 4 e un box NVMe Thunderbolt. Ho trovato la guida windows-tb-boot per avviare Windows da un SSD esterno. Posso seguirla anche sul mio portatile? Da dove parto?
