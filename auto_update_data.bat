@echo off
echo Starting automatic data update service...
echo This will update the CSV file every 5 minutes

:loop
echo [%date% %time%] Updating data...
cd /d "e:\1.GAIATRYST SYNOPSIS\app"
python python\main.py

if %ERRORLEVEL% EQU 0 (
    echo Data updated successfully
) else (
    echo Error occurred while updating data
)

echo Waiting 5 minutes before next update...
timeout /t 300 /nobreak >nul
goto loop