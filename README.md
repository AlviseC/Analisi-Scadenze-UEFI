[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0078D4?logo=windows)](https://www.microsoft.com/windows)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell)](https://microsoft.com/powershell)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.2.0-blue)](https://github.com/tuo-username/SecureBoot-Audit2026/releases)

# 🔐 SecureBoot-Audit2026

> **Strumento professionale per l'audit, il monitoraggio e il deploy sicuro dei certificati Secure Boot UEFI in vista della scadenza critica di giugno 2026.**

---

## ⚠️ Disclaimer
> [!WARNING]
> **Leggere attentamente prima di procedere.**
> Questo strumento è fornito "così com'è", senza garanzie. Un aggiornamento dei certificati Secure Boot applicato su firmware non compatibile può impedire l'avvio del sistema. Testare sempre su macchine pilota prima di una distribuzione su larga scala.
> L'autore e **Angolo di Windows** non si assumono responsabilità per danni derivanti dall'uso di questo script.

---

## 📖 Indice
- [Contesto](#-contesto)
- [Funzionalità](#-funzionalità)
- [Checkpoint di Sicurezza](#-checkpoint-di-sicurezza-step-4)
- [Avvio Rapido](#-avvio-rapido)
- [Dettagli Tecnici](#-dettagli-tecnici)
- [Uso Aziendale](#-uso-in-ambiente-aziendale)
- [Troubleshooting](#-event-id-monitorati)

---

## 📖 Contesto
I certificati Secure Boot emessi da Microsoft nel 2011 (incluso il *Microsoft Corporation KEK CA 2011*) scadranno a **giugno 2026**. I dispositivi senza i nuovi certificati **Windows UEFI CA 2023** potrebbero non avviarsi correttamente.

Questo strumento implementa i 5 step operativi del playbook ufficiale Microsoft per guidare admin e utenti avanzati nel processo di aggiornamento.

📄 **Articolo completo:** [Secure Boot Windows: guida alla gestione chiavi UEFI](https://angolodiwindows.com/2026/03/secure-boot-windows-guida-gestione-chiavi-uefi-2026/)

---

## ✨ Funzionalità

| Step | Nome | Descrizione |
| :--- | :--- | :--- |
| **1** | **Inventario** | Rileva tipo firmware (UEFI/BIOS), Secure Boot, TPM. Esporta CSV. |
| **2** | **Certificati** | Analisi `UEFICA2023Status` e scansione trust store Windows. |
| **3** | **Firmware OEM** | Verifica età firmware e fornisce link al supporto del produttore. |
| **4** | **Deploy** | Aggiornamento certificati con 4 checkpoint di sicurezza automatici. |
| **5** | **Troubleshooting** | Analisi Event ID (1795, 1796, 1803) con fix suggeriti. |

---

## 🛡️ Checkpoint di sicurezza (Step 4)
Prima di interagire con il firmware, lo Step 4 esegue verifiche bloccanti:

1. **Secure Boot attivo**: Obbligatorio per procedere.
2. **Firmware OEM aggiornato**: Blocco se il firmware è precedente al 2023.
3. **Rilevazione Dual Boot**: Avviso specifico per convivenza con Linux.
4. **Registry Backup**: Salvataggio automatico della chiave `Servicing` prima della scrittura.

> [!IMPORTANT]
> Per procedere al Deploy è necessario digitare esplicitamente la parola `CONFERMO`.

---

## 🚀 Avvio rapido

### Metodo consigliato (Doppio clic)
1. Scarica `SecureBoot-Audit2026.ps1` e `SecureBoot-Audit2026.bat` nella stessa cartella.
2. Esegui il file `.bat`.
3. Conferma il prompt UAC per ottenere i privilegi di Amministratore.

### Metodo manuale (PowerShell)
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\SecureBoot-Audit2026.ps1
