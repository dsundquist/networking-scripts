:: To see the stored cached pmtu for all interfaces: 
:: netsh interface ipv4 show destinationcache

@echo off
setlocal enabledelayedexpansion

:: Set the target IP or hostname here
set TARGET=162.159.197.2

:: Initial MTU size to start from
set MIN_MTU=1100

:: Maximum MTU size to test (1500 is typical)
set MAX_MTU=1500

:: Increment size
set INCREMENT=5

:: Variable to store the largest successful MTU
set SUCCESSFUL_MTU=0

:: Loop through MTU values
for /l %%i in (%MIN_MTU%,%INCREMENT%,%MAX_MTU%) do (
REM echo Testing MTU size: %%i
    ping -n 1 -f -l %%i %TARGET% >nul 
    if !errorlevel! equ 0 (
        set SUCCESSFUL_MTU=%%i
    ) else (
        echo Failure detected at %%i, stopping test.
        goto :RESULT
    )
)

:RESULT
netsh interface ipv4 show destinationcache address=%TARGET%
