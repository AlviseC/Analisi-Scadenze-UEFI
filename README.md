[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Windows Support](https://img.shields.io/badge/Windows-10%2F11-blue)
![Category](https://img.shields.io/badge/Category-System%20Repair-orange)
![Community](https://img.shields.io/badge/Community-AngoloDiWindows-0078d4)


⚠️ Disclaimer

Leggere attentamente prima di procedere.

Questo strumento è fornito "così com'è", senza garanzie di alcun tipo, esplicite o implicite.

Testare sempre in ambiente di sviluppo o su un numero limitato di macchine pilota prima di qualsiasi distribuzione su larga scala. Un aggiornamento dei certificati Secure Boot applicato su firmware non compatibile può impedire l'avvio del sistema.
Le operazioni di Step 4 (Deploy) modificano chiavi di registro di sistema e interagiscono con il firmware UEFI. Eseguire un backup completo del sistema e verificare la disponibilità di un aggiornamento firmware OEM prima di procedere.
L'autore e Angolo di Windows non si assumono alcuna responsabilità per danni diretti o indiretti derivanti dall'uso di questo script, inclusi — a titolo esemplificativo — perdita di dati, sistemi non avviabili o interruzioni operative.
Le informazioni contenute nello script si basano sulla documentazione ufficiale Microsoft disponibile al momento della pubblicazione. Verificare sempre la documentazione aggiornata su Microsoft Learn prima dell'uso in produzione.

# 🔐 SecureBoot-Audit2026

> Strumento PowerShell per l'audit, il monitoraggio e il deploy dei certificati Secure Boot UEFI in vista della scadenza critica di giugno 2026.

---

## 📖 Contesto

I certificati Secure Boot emessi da Microsoft nel 2011 — tra cui il **Microsoft Corporation KEK CA 2011** — iniziano a scadere a partire da **giugno 2026**. I dispositivi che non ricevono i nuovi certificati **Windows UEFI CA 2023** prima di tale data potrebbero non avviarsi correttamente.

Questo strumento implementa i **5 step operativi del playbook ufficiale Microsoft** per guidare OEM, IT manager e utenti avanzati nel processo di verifica e aggiornamento.

📄 Articolo di riferimento: [Secure Boot Windows: guida alla creazione e gestione delle chiavi UEFI](https://angolodiwindows.com/2026/03/secure-boot-windows-guida-gestione-chiavi-uefi-2026/)

---

## ✨ Funzionalità

| Step | Descrizione |
|------|-------------|
| **1 – Inventario** | Rileva tipo firmware (UEFI/BIOS), stato Secure Boot, TPM, hardware. Esporta CSV per fleet aziendali. |
| **2 – Certificati** | Legge `UEFICA2023Status` e `AvailableUpdates` dalla registry, scansiona il trust store Windows con scadenze. |
| **3 – Firmware OEM** | Verifica l'anno del firmware, avvisa se obsoleto e genera il link diretto al supporto del produttore. |
| **4 – Deploy** | Imposta `AvailableUpdates` con tre modalità (completo, solo KEK, solo DB/DBX) e gestisce il riavvio. |
| **5 – Troubleshooting** | Individua Event ID 1795, 1796, 1803 nel log di sistema e fornisce causa + fix per ognuno. |

---

## 🚀 Avvio rapido

### Metodo consigliato — doppio clic sul `.bat`

1. Scaricare entrambi i file nella stessa cartella:
   - `SecureBoot-Audit2026.ps1`
   - `SecureBoot-Audit2026.bat`
2. Fare **doppio clic** su `SecureBoot-Audit2026.bat`
3. Confermare il prompt UAC → lo script si apre automaticamente come Amministratore

### Metodo alternativo — PowerShell manuale

```powershell
# Aprire PowerShell come Amministratore, poi:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\SecureBoot-Audit2026.ps1
```

---

## 📋 Requisiti

- Windows 10 o Windows 11
- PowerShell 5.1 o superiore (incluso in Windows)
- Privilegi Administrator (richiesti automaticamente tramite UAC)
- Secure Boot abilitato nel firmware UEFI (per i comandi di deploy)

---

## 📂 Struttura del progetto

```
SecureBoot-Audit2026/
├── SecureBoot-Audit2026.ps1   # Script principale PowerShell
├── SecureBoot-Audit2026.bat   # Launcher con auto-elevazione UAC
└── README.md
```

### Output generati automaticamente

```
C:\ProgramData\SecureBootAudit\
├── SecureBootAudit_YYYYMMDD_HHMMSS.log   # Log testuale di ogni esecuzione
└── SecureBootReport_YYYYMMDD.csv         # Report CSV per inventario fleet
```

---

## 🖥️ Screenshot menù

```
  ============================================================
   Secure Boot Audit & Remediation 2026  v1.1.0
   angolodiwindows.com
  ============================================================
  [1]  Step 1 - Inventario e stato Secure Boot
  [2]  Step 2 - Stato certificati UEFI CA 2023
  [3]  Step 3 - Verifica firmware OEM
  [4]  Step 4 - Deploy certificati
  [5]  Step 5 - Troubleshooting e remediation
  [A]  Esegui tutti gli step (solo audit, no deploy)
  [Q]  Esci
  ============================================================
```

---

## ⚙️ Dettagli tecnici

### Registry keys monitorate

| Chiave | Descrizione |
|--------|-------------|
| `HKLM:\...\SecureBoot\State\UEFISecureBootEnabled` | Stato attivo/disattivo Secure Boot |
| `HKLM:\...\SecureBoot\Servicing\UEFICA2023Status` | Avanzamento deploy certificati 2023 (0–3) |
| `HKLM:\...\SecureBoot\Servicing\AvailableUpdates` | Bitmask aggiornamenti pendenti |

### Valori `AvailableUpdates`

| Valore (hex) | Significato |
|-------------|-------------|
| `0x0004` | KEK 2023 disponibile |
| `0x1000` | DB disponibile |
| `0x4000` | Boot Manager 2023 disponibile |
| `0x0140` | DBX disponibile |
| `0x5144` | Deploy completo (tutti i certificati) |

### Event ID monitorati

| Event ID | Causa | Fix |
|----------|-------|-----|
| 1795 | Firma non valida — Boot Manager non aggiornato | Aggiornare Windows Update, poi ripetere deploy |
| 1796 | KEK deploy fallita — firmware non compatibile | Aggiornare firmware OEM, poi ripetere |
| 1803 | Firmware OEM non pronto per i nuovi certificati | Contattare OEM e attendere aggiornamento firmware |

---

## 🏢 Uso in ambiente aziendale

Lo Step 1 esporta automaticamente un file CSV in `C:\ProgramData\SecureBootAudit\` con le informazioni di ogni macchina. Per raccogliere l'inventario su più PC si può distribuire lo script tramite:

- **Intune** (modalità consigliata da Microsoft)
- **Group Policy** — Computer Configuration > Administrative Templates > Windows Components > Secure Boot
- **Script di login** o task schedulato con `powershell.exe -NonInteractive -File .\SecureBoot-Audit2026.ps1`

---

## 🔗 Riferimenti ufficiali

- [Microsoft Learn — Secure Boot Key Creation and Management](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/windows-secure-boot-key-creation-and-management-guidance)
- [Playbook Microsoft — Certificati in scadenza nel 2026](https://techcommunity.microsoft.com/blog/windows-itpro-blog/secure-boot-playbook-for-certificates-expiring-in-2026/4469235)
- [aka.ms/GetSecureBoot](https://aka.ms/GetSecureBoot)
- KB WI1250978 / WI1250979 — Windows Health Dashboard

---

## 📝 Licenza

Distribuito sotto licenza **MIT**. Utilizzo libero per scopi personali, aziendali e di ricerca.

---

*Sviluppato da [Angolo di Windows](https://angolodiwindows.com) — punto di riferimento per il mondo Windows.*
