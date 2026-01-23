@echo off
echo ========================================
echo   Suchaman App - Data Collector
echo ========================================
echo.
echo Starting Python data collector...
echo This will fetch real-time Schumann Resonance data every hour
echo Press Ctrl+C to stop
echo.

cd /d "%~dp0"
python python\main.py

pause
