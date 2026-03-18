@echo off
:: ============================================================================
::  SecureBoot-Audit2026.bat
::  Launcher per SecureBoot-Audit2026.ps1
::  Fonte: https://angolodiwindows.com/2026/03/secure-boot-windows-guida-gestione-chiavi-uefi-2026/
:: ============================================================================

setlocal EnableDelayedExpansion
title Secure Boot Audit ^& Remediation 2026

:: ── Percorso dello script PS1 (stessa cartella del .bat) ────────────────────
set "SCRIPT_DIR=%~dp0"
set "PS1_FILE=%SCRIPT_DIR%SecureBoot-Audit2026.ps1"

:: ── Verifica esistenza file PS1 ─────────────────────────────────────────────
if not exist "%PS1_FILE%" (
    echo.
    echo  [ERRORE] File non trovato:
    echo  %PS1_FILE%
    echo.
    echo  Assicurarsi che SecureBoot-Audit2026.ps1 sia nella stessa cartella
    echo  di questo file .bat.
    echo.
    pause
    exit /b 1
)

:: ── Verifica privilegi Administrator ────────────────────────────────────────
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo  Rielevazione come Amministratore in corso...
    echo.

    :: Rilancia il .bat stesso con runas tramite PowerShell (piu affidabile di runas.exe)
    powershell -NoProfile -Command ^
        "Start-Process cmd.exe -ArgumentList '/c \"%~f0\"' -Verb RunAs"

    exit /b
)

:: ── A questo punto siamo Amministratori: avvia lo script PS1 ────────────────
echo.
echo  ============================================================
echo   Secure Boot Audit ^& Remediation 2026
echo   angolodiwindows.com
echo  ============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1_FILE%"

:: ── Fine ────────────────────────────────────────────────────────────────────
echo.
echo  Script terminato. Premi un tasto per chiudere.
pause >nul
endlocal
