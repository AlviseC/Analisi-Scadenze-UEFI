# UEFI Secure Boot Audit Tool 🛡️

Questo strumento è stato progettato per fornire un'analisi rapida e profonda dello stato di sicurezza del firmware UEFI su sistemi Windows (aggiornato per gli standard del 2026). 

È il compagno ideale per la guida pubblicata su [Angolo di Windows](https://angolodiwindows.com/2026/03/secure-boot-windows-guida-gestione-chiavi-uefi-2026/).

## 📋 Funzionalità
Lo script esegue un controllo automatico e restituisce un verdetto immediato su:
- **Stato Secure Boot**: Verifica se la protezione attiva è configurata correttamente.
- **Firmware Mode**: Controlla se il PC è in *User Mode* (protetto) o *Setup Mode* (vulnerabile/aperto a modifiche).
- **Audit Certificati (Database db)**: Scansiona il database delle firme UEFI alla ricerca di certificati X.509, mostrandone il nome e i **giorni rimanenti alla scadenza**.
- **Supporto SHA-256**: Identifica se il sistema utilizza firme basate su hash (standard moderni).
- **Verdetto Finale**: Un indicatore visivo (Verde/Rosso) per capire se il PC è a posto o richiede attenzione.

## 🚀 Come usarlo
1. Scarica il file `Audit_UEFI_Final.bat`.
2. Fai doppio clic sul file.
3. Lo script richiederà automaticamente i privilegi di **Amministratore** tramite pop-up UAC (necessari per leggere le variabili protette del firmware).
4. Leggi il responso a video.

## ⚠️ Perché monitorare la scadenza dei certificati?
Nel 2026, molti certificati UEFI originali emessi dai produttori hardware stanno raggiungendo il termine del loro ciclo di vita. Un certificato scaduto nel database `db` può causare il fallimento dell'avvio del sistema dopo un aggiornamento o in caso di tentata reinstallazione. Questo tool ti aiuta a prevenire il problema.

## 🛠️ Requisiti
- Windows 10 o Windows 11.
- Sistema avviato in modalità **UEFI** (lo script rileva se sei in modalità Legacy/CSM).
- PowerShell 5.1 o superiore (incluso di serie in Windows).

---
##🤝 Supporto e Contatti
Community: Unisciti al nostro subreddit per consigli e assistenza - https://www.reddit.com/r/AngolodiWindowsITA/
Segnalazioni: Se riscontri bug nel codice, apri una Issue qui su GitHub.
