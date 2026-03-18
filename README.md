# UEFI Secure Boot Audit Tool 🛡️

A lightweight diagnostic tool designed to provide a quick and deep analysis of the UEFI firmware security status on Windows systems (Updated for 2026 standards).

This tool is the official companion for the technical guide published on [Angolo di Windows](https://angolodiwindows.com/2026/03/secure-boot-windows-guida-gestione-chiavi-uefi-2026/).

## 📋 Features
The script automatically performs a series of security checks and returns an immediate verdict on:
- **Secure Boot Status**: Verifies if the active protection is correctly configured.
- **Firmware Mode**: Detects if the PC is in *User Mode* (Protected) or *Setup Mode* (Vulnerable/Open to modifications).
- **Certificate Audit (db Database)**: Scans the UEFI signature database for X.509 certificates, displaying the name and **days remaining until expiration**.
- **SHA-256 Hash Support**: Identifies if the system uses modern hash-based signatures (standard for many modern OEMs).
- **Final Verdict**: A color-coded visual indicator (Green/Red/Yellow) to instantly understand if the system is secure or requires maintenance.

## 🚀 How to Use
1. Download the `Check_SecureBoot_2026.bat` file.
2. Double-click the file.
3. The script will automatically request **Administrator** privileges via UAC popup (required to read protected firmware variables).
4. Review the results in the terminal window.

## ⚠️ Why Monitor Certificate Expiration?
In 2026, many original UEFI certificates issued by hardware manufacturers (OEMs) are reaching the end of their 10-15 year lifecycle. An expired certificate in the `db` database can lead to boot failures after a system update or during OS reinstallation. This tool helps you proactively identify these risks.

## 🛠️ Requirements
- Windows 10 or Windows 11.
- System booted in **UEFI Mode** (the script detects if you are in Legacy/CSM mode).
- PowerShell 5.1 or higher (pre-installed on Windows).

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.

---
##🤝 Contact and Support
Community: https://www.reddit.com/r/AngolodiWindowsITA/
Reports: If you find bugs in the code, please open an Issue here on GitHub.
