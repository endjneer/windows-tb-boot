---
description: "Chat: ripristino automatico e BitLocker dopo Windows Update (Fase 6)"
tags: [chat, emergenza, fase-6]
runs: 2
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
append_system_prompt: |
  Sei un assistente AI in una chat sul telefono dell'utente. Non hai una shell né accesso al suo notebook: i comandi li lancia l'utente e ti incolla l'output.
---
Uso Windows 11 su un SSD Thunderbolt esterno con il mio notebook Dell (lo stesso modello dei test), seguendo la guida windows-tb-boot. Ieri sera Windows Update ha installato degli aggiornamenti e ha chiesto di riavviare. Al riavvio è comparso «Preparazione del ripristino automatico» e poi una schermata blu di BitLocker che chiede la chiave di ripristino. Ho la chiave stampata, con il suo ID, e gli script della guida in C:\Repair. Cosa faccio adesso?
