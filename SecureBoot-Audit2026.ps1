<#
.SYNOPSIS
    Secure Boot Audit & Remediation 2026
    Strumento di inventario, verifica e deploy certificati Secure Boot UEFI
    Fonte: https://angolodiwindows.com/2026/03/secure-boot-windows-guida-gestione-chiavi-uefi-2026/

.DESCRIPTION
    Esegue i 5 step operativi del playbook Microsoft per la scadenza certificati 2026:
      Step 1 - Inventario e stato Secure Boot
      Step 2 - Monitoraggio stato certificati UEFI CA 2023
      Step 3 - Verifica firmware OEM
      Step 4 - Deploy certificati (registry key AvailableUpdates)
      Step 5 - Troubleshooting (Event ID 1795, 1796, 1803)

.NOTES
    Richiede: Windows 10/11, PowerShell 5.1+, privilegi Administrator
    Riferimenti: aka.ms/GetSecureBoot | KB WI1250978/79
#>

# =============================================================================
# SELF-ELEVATION — richiesta automatica privilegi Administrator
# =============================================================================

$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "  Lo script non e' in esecuzione come Amministratore." -ForegroundColor Yellow
    Write-Host "  Tentativo di rielevazione automatica in corso..." -ForegroundColor DarkGray
    Write-Host ""

    try {
        $scriptPath = $MyInvocation.MyCommand.Path

        if (-not $scriptPath) {
            Write-Host "  Impossibile determinare il percorso dello script." -ForegroundColor Red
            Write-Host "  Avviare manualmente PowerShell come Amministratore e rieseguire." -ForegroundColor Yellow
            pause
            exit 1
        }

        Start-Process powershell.exe `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
            -Verb RunAs

    } catch {
        Write-Host "  Rielevazione annullata o non riuscita." -ForegroundColor Red
        Write-Host "  Avviare manualmente PowerShell come Amministratore e rieseguire." -ForegroundColor Yellow
        Write-Host ""
        pause
    }

    exit
}

# =============================================================================
# CONFIGURAZIONE
# =============================================================================
$Script:Version    = "1.1.0"
$Script:LogDir     = "$env:ProgramData\SecureBootAudit"
$Script:LogFile    = "$Script:LogDir\SecureBootAudit_$(Get-Date -f 'yyyyMMdd_HHmmss').log"
$Script:ReportFile = "$Script:LogDir\SecureBootReport_$(Get-Date -f 'yyyyMMdd').csv"

$REG_SERVICING = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing"
$REG_STATE     = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State"

# =============================================================================
# FUNZIONI DI UTILITA'
# =============================================================================

function Initialize-Environment {
    if (-not (Test-Path $Script:LogDir)) {
        New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null
    }
    Write-Log "=== Secure Boot Audit & Remediation 2026 v$($Script:Version) ===" -Color Cyan
    Write-Log "Host    : $env:COMPUTERNAME"
    Write-Log "Utente  : $env:USERNAME"
    Write-Log "Data    : $(Get-Date -f 'dd/MM/yyyy HH:mm:ss')"
    Write-Log "Log     : $Script:LogFile"
    Write-Log ("=" * 65)
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    $ts   = Get-Date -f "HH:mm:ss"
    $line = "[$ts] $Message"
    try { Add-Content -Path $Script:LogFile -Value $line -Encoding UTF8 } catch {}
    Write-Host $line -ForegroundColor $Color
}

function Write-Section {
    param([string]$Title)
    Write-Log ""
    Write-Log ("-" * 65) -Color DarkGray
    Write-Log "  $Title" -Color Yellow
    Write-Log ("-" * 65) -Color DarkGray
}

function Write-Result {
    param(
        [string]$Label,
        [string]$Value,
        [string]$Stato = "INFO"
    )
    $colMap = @{ OK="Green"; WARN="Yellow"; ERROR="Red"; INFO="Cyan" }
    $col    = if ($colMap.ContainsKey($Stato)) { $colMap[$Stato] } else { "White" }
    $padded = $Label.PadRight(42)
    Write-Host "  $padded" -NoNewline -ForegroundColor Gray
    Write-Host "$Value" -ForegroundColor $col
    try { Add-Content -Path $Script:LogFile -Value "  $padded$Value" -Encoding UTF8 } catch {}
}

# =============================================================================
# STEP 1 - INVENTARIO E STATO SECURE BOOT
# =============================================================================

function Invoke-Step1-Inventory {
    Write-Section "STEP 1 - Inventario e stato Secure Boot"

    # Sistema operativo
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        Write-Result "Sistema Operativo"  "$($os.Caption) (Build $($os.BuildNumber))" "INFO"
        Write-Result "Architettura"       $os.OSArchitecture "INFO"
    } catch {
        Write-Result "Sistema Operativo"  "Errore: $($_.Exception.Message)" "ERROR"
    }

    # Tipo Firmware
    $isUefi = $false
    try {
        $fwType = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control" `
                    -Name "PEFirmwareType" -ErrorAction Stop).PEFirmwareType
        if ($fwType -eq 2) {
            Write-Result "Tipo Firmware" "UEFI" "OK"
            $isUefi = $true
        } else {
            Write-Result "Tipo Firmware" "BIOS Legacy (Secure Boot non supportato)" "ERROR"
        }
    } catch {
        Write-Result "Tipo Firmware" "Impossibile determinare" "WARN"
    }

    # Secure Boot via cmdlet
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        if ($sb) {
            Write-Result "Secure Boot" "ATTIVO" "OK"
        } else {
            Write-Result "Secure Boot" "NON ATTIVO - abilitare nel firmware UEFI" "ERROR"
        }
    } catch {
        Write-Result "Secure Boot (cmdlet)" "Non disponibile su questo sistema" "WARN"
    }

    # Secure Boot via Registry
    try {
        $sbReg = (Get-ItemProperty $REG_STATE `
                    -Name "UEFISecureBootEnabled" -ErrorAction Stop).UEFISecureBootEnabled
        Write-Result "Registry SecureBootEnabled" "$sbReg  (1=attivo, 0=disabilitato)" "INFO"
    } catch {
        Write-Result "Registry SecureBootEnabled" "Chiave non trovata" "WARN"
    }

    # TPM
    try {
        $tpm = Get-Tpm -ErrorAction Stop
        Write-Result "TPM Presente"  $(if ($tpm.TpmPresent)   { "Si" } else { "No" }) `
                     $(if ($tpm.TpmPresent)   { "OK" } else { "WARN" })
        Write-Result "TPM Abilitato" $(if ($tpm.TpmEnabled)   { "Si" } else { "No" }) `
                     $(if ($tpm.TpmEnabled)   { "OK" } else { "WARN" })
        Write-Result "TPM Attivato"  $(if ($tpm.TpmActivated) { "Si" } else { "No" }) `
                     $(if ($tpm.TpmActivated) { "OK" } else { "WARN" })
    } catch {
        Write-Result "TPM" "Impossibile interrogare il TPM: $($_.Exception.Message)" "WARN"
    }

    try {
        $tpmVer = (Get-CimInstance -Namespace "root\cimv2\security\microsofttpm" `
                    -ClassName Win32_Tpm -ErrorAction Stop).SpecVersion
        Write-Result "Versione TPM" "$tpmVer" "INFO"
    } catch {
        Write-Result "Versione TPM" "Non disponibile" "WARN"
    }

    # Hardware
    try {
        $cs   = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
        $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
        Write-Result "Produttore"        $cs.Manufacturer "INFO"
        Write-Result "Modello"           $cs.Model "INFO"
        Write-Result "Versione Firmware" $bios.SMBIOSBIOSVersion "INFO"
        Write-Result "Data Firmware"     $bios.ReleaseDate.ToString("dd/MM/yyyy") "INFO"
    } catch {
        Write-Result "Dati hardware" "Errore: $($_.Exception.Message)" "ERROR"
    }

    # Export CSV
    try {
        $sbVal = try { Confirm-SecureBootUEFI } catch { "N/A" }
        $mfg   = try { (Get-CimInstance Win32_ComputerSystem).Manufacturer } catch { "" }
        $mod   = try { (Get-CimInstance Win32_ComputerSystem).Model } catch { "" }
        $biosV = try { (Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion } catch { "" }

        $row = [PSCustomObject]@{
            Timestamp  = Get-Date -f "yyyy-MM-dd HH:mm:ss"
            Computer   = $env:COMPUTERNAME
            UEFI       = $isUefi
            SecureBoot = $sbVal
            Produttore = $mfg
            Modello    = $mod
            BIOSVers   = $biosV
        }
        $row | Export-Csv -Path $Script:ReportFile -NoTypeInformation -Append -Encoding UTF8
        Write-Log ""
        Write-Log "  Report CSV: $Script:ReportFile" -Color DarkGray
    } catch {
        Write-Log "  Impossibile salvare il CSV: $($_.Exception.Message)" -Color DarkGray
    }
}

# =============================================================================
# STEP 2 - MONITORAGGIO CERTIFICATI UEFI CA 2023
# =============================================================================

function Invoke-Step2-CertificateStatus {
    Write-Section "STEP 2 - Stato certificati UEFI CA 2023"

    # UEFICA2023Status
    try {
        $s = (Get-ItemProperty $REG_SERVICING `
                -Name "UEFICA2023Status" -ErrorAction Stop).UEFICA2023Status
        $desc = switch ($s) {
            0       { "Non avviato / Non applicabile" }
            1       { "In attesa aggiornamento firmware OEM" }
            2       { "KEK 2023 installata, DB/DBX in attesa" }
            3       { "Certificati 2023 completamente installati" }
            default { "Valore sconosciuto: $s" }
        }
        $st = if ($s -eq 3) { "OK" } elseif ($s -ge 1) { "WARN" } else { "INFO" }
        Write-Result "UEFICA2023Status (valore)" "$s" $st
        Write-Result "UEFICA2023Status (stato)"  $desc $st
    } catch {
        Write-Result "UEFICA2023Status" "Chiave assente - cert 2023 non ancora distribuiti" "WARN"
    }

    # AvailableUpdates
    try {
        $av = (Get-ItemProperty $REG_SERVICING `
                -Name "AvailableUpdates" -ErrorAction Stop).AvailableUpdates
        Write-Result "AvailableUpdates (hex)" ("0x{0:X4}" -f $av) "INFO"

        $flags = @()
        if ($av -band 0x0004) { $flags += "KEK disponibile" }
        if ($av -band 0x1000) { $flags += "DB disponibile" }
        if ($av -band 0x4000) { $flags += "Boot Manager 2023" }
        if ($av -band 0x0140) { $flags += "DBX disponibile" }
        $flagStr = if ($flags.Count -gt 0) { $flags -join " | " } else { "Nessun aggiornamento pendente" }
        $flagSt  = if ($flags.Count -gt 0) { "WARN" } else { "OK" }
        Write-Result "Aggiornamenti pendenti" $flagStr $flagSt
    } catch {
        Write-Result "AvailableUpdates" "Chiave non presente" "INFO"
    }

    # Certificati nel cert store
    Write-Log ""
    Write-Log "  Certificati UEFI nel trust store Windows:" -Color Gray
    try {
        $certs = Get-ChildItem Cert:\LocalMachine\Root -ErrorAction Stop |
            Where-Object { $_.Subject -match "Microsoft.*UEFI|Microsoft.*KEK|Windows UEFI" }

        if ($certs) {
            foreach ($c in $certs) {
                $daysLeft = [math]::Round(($c.NotAfter - (Get-Date)).TotalDays)
                $colSt    = if ($daysLeft -lt 90) { "ERROR" } `
                            elseif ($daysLeft -lt 365) { "WARN" } else { "OK" }
                $subj = if ($c.Subject.Length -gt 50) { $c.Subject.Substring(0,50) + "..." } else { $c.Subject }
                Write-Result "  $subj" "Scade: $($c.NotAfter.ToString('dd/MM/yyyy')) ($daysLeft gg)" $colSt
            }
        } else {
            Write-Log "  Nessun certificato UEFI trovato nel Root store" -Color DarkGray
        }
    } catch {
        Write-Log "  Impossibile leggere il cert store: $($_.Exception.Message)" -Color DarkGray
    }
}

# =============================================================================
# STEP 3 - VERIFICA FIRMWARE OEM
# =============================================================================

function Invoke-Step3-FirmwareCheck {
    Write-Section "STEP 3 - Verifica firmware OEM (pre-requisito deploy)"

    try {
        $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
        $cs   = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop

        Write-Result "Produttore"        $cs.Manufacturer "INFO"
        Write-Result "Modello"           $cs.Model "INFO"
        Write-Result "Versione Firmware" $bios.SMBIOSBIOSVersion "INFO"
        Write-Result "Data Firmware"     $bios.ReleaseDate.ToString("dd/MM/yyyy") "INFO"

        $fwYear = $bios.ReleaseDate.Year
        if ($fwYear -lt 2023) {
            Write-Result "Stato firmware" "Datato $fwYear - aggiornamento OEM raccomandato!" "WARN"
            Write-Log ""
            Write-Log "  AZIONE RICHIESTA: aggiornare il firmware prima del deploy." -Color Yellow
            Write-Log "  Link supporto:" -Color Yellow

            switch -Wildcard ($cs.Manufacturer) {
                "*Dell*"    { Write-Log "  -> https://www.dell.com/support/home" -Color Cyan }
                "*HP*"      { Write-Log "  -> https://support.hp.com/drivers" -Color Cyan }
                "*Lenovo*"  { Write-Log "  -> https://support.lenovo.com" -Color Cyan }
                "*ASUS*"    { Write-Log "  -> https://www.asus.com/support/" -Color Cyan }
                "*Acer*"    { Write-Log "  -> https://www.acer.com/support" -Color Cyan }
                "*MSI*"     { Write-Log "  -> https://www.msi.com/support" -Color Cyan }
                "*Toshiba*" { Write-Log "  -> https://support.toshiba.com" -Color Cyan }
                default     { Write-Log "  -> Cerca: BIOS update $($cs.Manufacturer) $($cs.Model)" -Color Cyan }
            }
        } else {
            Write-Result "Stato firmware" "Firmware $fwYear - compatibile con cert 2023" "OK"
        }
    } catch {
        Write-Result "Dati firmware" "Errore: $($_.Exception.Message)" "ERROR"
    }

    # Event ID 1803
    try {
        $ev = Get-WinEvent -FilterHashtable @{LogName="System"; Id=1803} `
                -MaxEvents 5 -ErrorAction Stop
        Write-Result "Event ID 1803" "$($ev.Count) occorrenze - firmware OEM non pronto" "ERROR"
    } catch {
        Write-Result "Event ID 1803" "Nessuna occorrenza" "OK"
    }
}

# =============================================================================
# STEP 4 - DEPLOY CERTIFICATI
# =============================================================================

function Invoke-Step4-Deploy {
    Write-Section "STEP 4 - Deploy certificati UEFI CA 2023"

    # Verifica Secure Boot
    try {
        $sb = Confirm-SecureBootUEFI -ErrorAction Stop
        if (-not $sb) {
            Write-Log "  Secure Boot non attivo. Abilitarlo nel firmware UEFI prima di procedere." -Color Red
            return
        }
    } catch {
        Write-Log "  Impossibile verificare lo stato del Secure Boot. Operazione annullata." -Color Red
        return
    }

    # Avviso firmware datato
    try {
        $fwYear = (Get-CimInstance Win32_BIOS -ErrorAction Stop).ReleaseDate.Year
        if ($fwYear -lt 2023) {
            Write-Log "  ATTENZIONE: firmware datato $fwYear." -Color Yellow
            Write-Log "  Si raccomanda di aggiornare prima il firmware OEM (Step 3)." -Color Yellow
            Write-Log ""
        }
    } catch {}

    Write-Log "  Metodi di deploy disponibili:" -Color Gray
    Write-Log "   [A] Deploy completo  (AvailableUpdates = 0x5144)" -Color Cyan
    Write-Log "       KEK + DB + DBX + Boot Manager 2023" -Color DarkGray
    Write-Log "   [B] Solo KEK 2023    (AvailableUpdates = 0x0004)" -Color Cyan
    Write-Log "   [C] Solo DB e DBX    (AvailableUpdates = 0x1140)" -Color Cyan
    Write-Log "   [S] Salta il deploy" -Color Gray
    Write-Log ""

    $deployChoice = Read-Host "  Scelta [A/B/C/S]"

    $deployValue = $null
    $deployDesc  = ""
    switch ($deployChoice.ToUpper()) {
        "A" { $deployValue = 0x5144; $deployDesc = "Deploy completo (KEK + DB + DBX + Boot Manager)" }
        "B" { $deployValue = 0x0004; $deployDesc = "Solo KEK 2023" }
        "C" { $deployValue = 0x1140; $deployDesc = "Solo DB + DBX" }
        "S" { Write-Log "  Deploy saltato." -Color DarkGray; return }
        default { Write-Log "  Scelta non valida. Deploy saltato." -Color Red; return }
    }

    Write-Log ""
    Write-Log "  Impostazione AvailableUpdates = 0x$($deployValue.ToString('X4'))" -Color Yellow
    Write-Log "  $deployDesc" -Color Yellow

    try {
        if (-not (Test-Path $REG_SERVICING)) {
            New-Item -Path $REG_SERVICING -Force | Out-Null
        }
        Set-ItemProperty -Path $REG_SERVICING `
            -Name "AvailableUpdates" -Value $deployValue -Type DWord -Force
        Write-Log "  Registry key impostata correttamente." -Color Green
        Write-Log ""
        Write-Log "  IMPORTANTE: riavviare il sistema per applicare i certificati." -Color Yellow
        Write-Log ""

        $rebootChoice = Read-Host "  Riavviare ora? [S/N]"
        if ($rebootChoice -eq "S" -or $rebootChoice -eq "s") {
            Write-Log "  Riavvio in corso..." -Color Yellow
            Start-Sleep -Seconds 3
            Restart-Computer -Force
        }
    } catch {
        Write-Log "  Errore durante la scrittura della registry: $($_.Exception.Message)" -Color Red
    }
}

# =============================================================================
# STEP 5 - TROUBLESHOOTING
# =============================================================================

function Invoke-Step5-Troubleshooting {
    Write-Section "STEP 5 - Troubleshooting e Remediation"

    $issues = 0

    # Event ID 1795
    try {
        $ev = Get-WinEvent -FilterHashtable @{LogName="System"; Id=1795} `
                -MaxEvents 10 -ErrorAction Stop
        $issues++
        Write-Result "Event ID 1795 (firma non valida)" "$($ev.Count) eventi rilevati" "ERROR"
        Write-Log "  Causa: Boot Manager non aggiornato prima dei certificati." -Color Yellow
        Write-Log "  Fix  : aggiornare Windows Update e ripetere il deploy (Step 4)." -Color Yellow
    } catch {
        Write-Result "Event ID 1795" "Nessuna occorrenza" "OK"
    }

    # Event ID 1796
    try {
        $ev = Get-WinEvent -FilterHashtable @{LogName="System"; Id=1796} `
                -MaxEvents 10 -ErrorAction Stop
        $issues++
        Write-Result "Event ID 1796 (KEK deploy fallita)" "$($ev.Count) eventi rilevati" "ERROR"
        Write-Log "  Causa: firmware non accetta la nuova KEK 2023." -Color Yellow
        Write-Log "  Fix  : aggiornare il firmware OEM (Step 3) e ripetere." -Color Yellow
    } catch {
        Write-Result "Event ID 1796" "Nessuna occorrenza" "OK"
    }

    # Event ID 1803
    try {
        $ev = Get-WinEvent -FilterHashtable @{LogName="System"; Id=1803} `
                -MaxEvents 10 -ErrorAction Stop
        $issues++
        Write-Result "Event ID 1803 (firmware OEM non pronto)" "$($ev.Count) eventi rilevati" "ERROR"
        Write-Log "  Causa: firmware OEM non ha aggiornato PK/KEK proprietarie." -Color Yellow
        Write-Log "  Fix  : contattare OEM e attendere aggiornamento firmware." -Color Yellow
    } catch {
        Write-Result "Event ID 1803" "Nessuna occorrenza" "OK"
    }

    # AvailableUpdates bloccato a 0x0004
    try {
        $av = (Get-ItemProperty $REG_SERVICING `
                -Name "AvailableUpdates" -ErrorAction Stop).AvailableUpdates
        if ($av -eq 0x0004) {
            $issues++
            Write-Result "AvailableUpdates = 0x0004" "KEK installata ma DB/DBX non avanzati" "WARN"
            Write-Log "  Fix: verificare aggiornamento firmware OEM e riavviare." -Color Yellow
        } elseif ($av -eq 0) {
            Write-Result "AvailableUpdates = 0x0000" "Nessun aggiornamento pendente" "OK"
        }
    } catch {}

    Write-Log ""
    if ($issues -eq 0) {
        Write-Log "  Nessun problema rilevato. Sistema correttamente configurato." -Color Green
    } else {
        Write-Log "  Rilevati $issues problemi - vedere i dettagli sopra." -Color Yellow
        Write-Log "  Documentazione: https://aka.ms/GetSecureBoot" -Color Cyan
    }
}

# =============================================================================
# MENU PRINCIPALE
# =============================================================================

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "   Secure Boot Audit & Remediation 2026  v$($Script:Version)" -ForegroundColor Cyan
    Write-Host "   angolodiwindows.com" -ForegroundColor DarkGray
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "  [1]  Step 1 - Inventario e stato Secure Boot" -ForegroundColor White
    Write-Host "  [2]  Step 2 - Stato certificati UEFI CA 2023" -ForegroundColor White
    Write-Host "  [3]  Step 3 - Verifica firmware OEM" -ForegroundColor White
    Write-Host "  [4]  Step 4 - Deploy certificati" -ForegroundColor White
    Write-Host "  [5]  Step 5 - Troubleshooting e remediation" -ForegroundColor White
    Write-Host "  [A]  Esegui tutti gli step (solo audit, no deploy)" -ForegroundColor Green
    Write-Host "  [Q]  Esci" -ForegroundColor DarkGray
    Write-Host "  ============================================================" -ForegroundColor Cyan
    Write-Host "  Log: $Script:LogFile" -ForegroundColor DarkGray
    Write-Host ""
}

# =============================================================================
# ENTRY POINT
# =============================================================================

Initialize-Environment

$menuLoop = $true
while ($menuLoop) {
    Show-Menu
    $menuChoice = Read-Host "  Scelta"

    switch ($menuChoice.ToUpper()) {
        "1" { Invoke-Step1-Inventory }
        "2" { Invoke-Step2-CertificateStatus }
        "3" { Invoke-Step3-FirmwareCheck }
        "4" { Invoke-Step4-Deploy }
        "5" { Invoke-Step5-Troubleshooting }
        "A" {
            Invoke-Step1-Inventory
            Invoke-Step2-CertificateStatus
            Invoke-Step3-FirmwareCheck
            Invoke-Step5-Troubleshooting
            Write-Log ""
            Write-Log "  [Audit completato - Step 4 saltato in modalita' automatica]" -Color DarkGray
        }
        "Q" {
            Write-Log "Uscita." -Color Gray
            $menuLoop = $false
        }
        default { Write-Log "  Scelta non valida." -Color Red }
    }

    if ($menuLoop) {
        Write-Host ""
        Write-Host "  Premi INVIO per tornare al menu..." -ForegroundColor DarkGray
        Read-Host | Out-Null
    }
}

Write-Host ""
Write-Host "  Log salvato in : $Script:LogFile" -ForegroundColor Cyan
Write-Host "  Report CSV     : $Script:ReportFile" -ForegroundColor Cyan
Write-Host ""
