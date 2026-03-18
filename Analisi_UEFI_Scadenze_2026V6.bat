@echo off
setlocal DisableDelayedExpansion

:checkPrivileges
NET FILE 1>NUL 2>NUL
if '%errorlevel%' == '0' ( goto :isAdministrator ) else ( goto :getPrivileges )
:getPrivileges
if '%1'=='ELEV' (shift & goto :isAdministrator)
set "batchPath=%~f0"
set "batchArgs=%*"
setlocal EnableDelayedExpansion
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\OEgetPriv.vbs"
echo UAC.ShellExecute "cmd.exe", "/c ""!batchPath!"" ELEV !batchArgs!", "", "runas", 1 >> "%temp%\OEgetPriv.vbs"
"%temp%\OEgetPriv.vbs"
exit /B
:isAdministrator

cls
title "Audit UEFI 2026 - Angolo di Windows"

echo ==========================================================
echo    ANALISI UEFI: STATO E INTEGRITA' SISTEMA
echo ==========================================================
echo.

set "ps_script=%temp%\uefi_verdict.ps1"

echo $ErrorActionPreference = 'SilentlyContinue' > "%ps_script%"
echo $isSafe = $true >> "%ps_script%"
echo $sb = Get-SecureBootUEFI -Name 'SecureBoot' >> "%ps_script%"
echo if ($sb.Bytes -eq 1) { Write-Host '[OK] Secure Boot: ATTIVO' -ForegroundColor Green } >> "%ps_script%"
echo else { Write-Host '[!] Secure Boot: DISATTIVATO' -ForegroundColor Red; $isSafe = $false } >> "%ps_script%"
echo $sm = Get-SecureBootUEFI -Name 'SetupMode' >> "%ps_script%"
echo if ($sm.Bytes -eq 1) { Write-Host '[!] Setup Mode: ATTIVO (Rischio manomissione)' -ForegroundColor Yellow; $isSafe = $false } >> "%ps_script%"
echo else { Write-Host '[OK] User Mode: PROTETTO' -ForegroundColor Green } >> "%ps_script%"
echo Write-Host "`n--- ANALISI DATABASE FIRME (db) ---" -ForegroundColor Cyan >> "%ps_script%"
echo try { >> "%ps_script%"
echo     $dbVar = Get-SecureBootUEFI -Name 'db' >> "%ps_script%"
echo     $bin = $dbVar.Bytes; $found = $false >> "%ps_script%"
echo     for ($i = 0; $i -lt ($bin.Count - 2); $i++) { >> "%ps_script%"
echo         if ($bin[$i] -eq 0x30 -and $bin[$i+1] -eq 0x82) { >> "%ps_script%"
echo             try { >> "%ps_script%"
echo                 $certData = $bin[$i..($bin.Count-1)] >> "%ps_script%"
echo                 $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 >> "%ps_script%"
echo                 $cert.Import($certData) >> "%ps_script%"
echo                 $days = ($cert.NotAfter - (Get-Date)).Days >> "%ps_script%"
echo                 $name = ($cert.Subject -split 'CN=')[-1] -split ',' ^| Select-Object -First 1 >> "%ps_script%"
echo                 if ($days -lt 1) { $c = 'Red'; $isSafe = $false } elseif ($days -lt 30) { $c = 'Yellow'; $isSafe = $false } else { $c = 'White' } >> "%ps_script%"
echo                 Write-Host " >> Certificato: $name" -ForegroundColor White >> "%ps_script%"
echo                 Write-Host "    Scadenza: $($cert.NotAfter.ToShortDateString()) ($days giorni)" -ForegroundColor $c >> "%ps_script%"
echo                 $found = $true; $i += $cert.RawData.Count >> "%ps_script%"
echo             } catch { continue } >> "%ps_script%"
echo         } >> "%ps_script%"
echo     } >> "%ps_script%"
echo     if (-not $found) { Write-Host ' >> Validazione tramite Hash SHA-256 (Nessun certificato X.509).' -ForegroundColor Gray } >> "%ps_script%"
echo } catch { Write-Host ' >> Errore Database.' -ForegroundColor Red; $isSafe = $false } >> "%ps_script%"
echo Write-Host "`n==========================================================" >> "%ps_script%"
echo if ($isSafe) { >> "%ps_script%"
echo     Write-Host " VERDETTO: IL PC E' A POSTO E PROTETTO " -ForegroundColor Black -BackgroundColor Green >> "%ps_script%"
echo } else { >> "%ps_script%"
echo     Write-Host " VERDETTO: IL PC RICHIEDE ATTENZIONE / AGGIORNAMENTI " -ForegroundColor Black -BackgroundColor Red >> "%ps_script%"
echo } >> "%ps_script%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ps_script%"
if exist "%ps_script%" del "%ps_script%"

echo ==========================================================
echo Analisi completata per Angolo di Windows.
echo Premi un tasto per uscire...
pause >nul