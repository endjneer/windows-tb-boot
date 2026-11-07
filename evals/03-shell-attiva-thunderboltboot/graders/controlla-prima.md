---
type: llm
---
PASS se la risposta, prima di qualunque scrittura nel BIOS, controlla o propone di controllare lo stato attuale in sola lettura (thunderbolt-boot-on.vbs /status, repair-usb4-boot.bat /check oppure la lettura con wmic).
FAIL se propone di scrivere subito nel BIOS senza leggere prima il valore attuale.
