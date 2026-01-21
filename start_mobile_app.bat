@echo off
echo Starting GAIATRYST SYNOPSIS with live data updates...

REM Start the server in a separate window
start cmd /k "cd server && node server.js"

REM Wait a moment for the server to start
timeout /t 3 /nobreak >nul

REM Run the Flutter app
echo Starting Flutter app...
flutter run

pause