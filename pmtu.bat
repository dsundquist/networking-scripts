:: To see the stored cached pmtu for all interfaces:
:: netsh interface ipv4 show destinationcache
:: netsh interface ipv6 show destinationcache
::
:: Usage: pathmtu_ipv4.bat [ipv4|ipv6]  (defaults to ipv4)

@echo off
setlocal enabledelayedexpansion

:: Parse protocol argument (default: ipv4)
set PROTO=ipv4
if /i "%~1"=="ipv6" set PROTO=ipv6
if /i "%~1"=="6"    set PROTO=ipv6

:: Set target based on protocol
if "!PROTO!"=="ipv6" (
    set TARGET=2606:4700:102::2
) else (
    set TARGET=162.159.197.2
)

:: Initial MTU size to start from
set MIN_MTU=1100

:: Maximum MTU size to test (1500 is typical)
set MAX_MTU=1500

:: Increment size
set INCREMENT=5

:: Variable to store the largest successful MTU
set SUCCESSFUL_MTU=0

echo Testing path MTU to !TARGET! [!PROTO!]...

:: Loop through MTU values
for /l %%i in (%MIN_MTU%,%INCREMENT%,%MAX_MTU%) do (
REM echo Testing MTU size: %%i
    if "!PROTO!"=="ipv6" (
        ping -6 -n 1 -l %%i !TARGET! >nul
    ) else (
        ping -n 1 -f -l %%i !TARGET! >nul
    )
    if !errorlevel! equ 0 (
        set SUCCESSFUL_MTU=%%i
    ) else (
        echo Failure detected at %%i, stopping test.
        goto :RESULT
    )
)

:RESULT
echo Largest successful MTU payload size: !SUCCESSFUL_MTU!
if "!PROTO!"=="ipv6" (
    netsh interface ipv6 show destinationcache address=!TARGET!
) else (
    netsh interface ipv4 show destinationcache address=!TARGET!
)
