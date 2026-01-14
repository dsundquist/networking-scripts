@echo off
setlocal enabledelayedexpansion

:: Check if target argument is provided
if "%~1"=="" (
    echo Usage: %~nx0 ^<target^> [threshold_ms]
    echo Example: %~nx0 google.com 100
    exit /b 1
)

set TARGET=%~1
set THRESHOLD=%~2
if "%THRESHOLD%"=="" set THRESHOLD=100

:: Create log file with timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set DATESTAMP=%%c%%a%%b)
for /f "tokens=1-2 delims=: " %%a in ('time /t') do (set TIMESTAMP=%%a%%b)
set LOGFILE=%~dp0ping_then_%TARGET%_%DATESTAMP%_%TIMESTAMP%.log

call :log "Monitoring %TARGET% - Will traceroute when latency > %THRESHOLD%ms or no response"
call :log "Press Ctrl+C to stop..."
call :log ""
call :log "Log file: %LOGFILE%"
call :log ""
call :log "Sending initial ping (ignoring result)..."

:: Send one initial ping and ignore the result (warm-up)
ping -n 1 %TARGET% >nul 2>&1

call :log "Starting monitoring..."
call :log ""

set loop_count=1

:loop
    :: Ping once and capture output
    set "latency="
    set "ping_failed=0"
    
    for /f "tokens=*" %%a in ('ping -n 1 %TARGET% 2^>nul') do (
        set "line=%%a"
        @REM echo "Debug: Line: !line!"
        @REM echo "Loop count: !loop_count!"
        @REM loop_count=!loop_count!+1

        :: Check for timeout/unreachable
        echo !line! | findstr /i "timed out Request timed Destination host unreachable" >nul
        if !errorlevel! equ 0 (
            set "ping_failed=1"
        )
        
        :: Look specifically for "Reply from" or "bytes=" to find the actual reply line with latency
        echo !line! | findstr /i "Reply from bytes=" >nul
        if !errorlevel! equ 0 (
            :: Extract latency value from the reply line
            for /f "tokens=5 delims==m" %%t in ("!line!") do (
                set "latency=%%t"
                :: Remove any trailing characters
                set "latency=!latency: =!"
            )
        )
    )

    :: Handle ping failure
    if !ping_failed! equ 1 (
        call :get_time
        call :log "[!UTCTIME!] No response from %TARGET%"
        call :log "Running traceroute..."
        tracert %TARGET% | tee -a %LOGFILE% 2>&1
        echo. & echo. >> %LOGFILE%
        goto loop
    )
    
    :: Process latency if we got a value
    if defined latency (
        :: Handle "time<1ms" case
        echo !latency! | findstr /r "^<" >nul
        if !errorlevel! equ 0 (
            set latency=0
        )
        
        :: Compare latency to threshold
        if !latency! gtr %THRESHOLD% (
            call :get_time
            call :log "[!UTCTIME!] High latency detected: !latency!ms (threshold: %THRESHOLD%ms)"
            call :log "Running traceroute..."
            tracert -d %TARGET% | tee -a %LOGFILE% 2>&1
            echo. & echo. >> %LOGFILE%
        ) else (
            call :get_time
            call :log "[!UTCTIME!] %TARGET% - !latency!ms"
        )
    )
    
    :: Small delay before next ping
    timeout /t 1 /nobreak >nul
    
goto loop

:log
    :: Subroutine to echo to both console and log file
    set "msg=%~1"
    echo !msg!
    echo !msg!>> "%LOGFILE%"
    exit /b

:get_time
    :: Get current local time with timezone
    for /f "tokens=*" %%a in ('tzutil /g') do set "TIMEZONE=%%a"
    set "UTCTIME=%date% %time% %TIMEZONE%"
    exit /b
