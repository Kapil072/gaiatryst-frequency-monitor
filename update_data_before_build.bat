@echo off
echo Updating real-time data before build...

echo Running Python script to fetch latest data...
cd /d "%~dp0"
python python\main.py

if %ERRORLEVEL% EQU 0 (
    echo Data updated successfully!
    echo Copying updated CSV to assets folder...
    copy /Y "gci_hourly_log_clean.csv" "assets\gci_hourly_log_clean.csv"
    echo Data file copied to assets.
) else (
    echo Warning: Python script failed, using existing data
)

echo Build data update complete.
pause