@echo off
Start-Process powershell -ArgumentList '-WindowStyle Minimized', '-Command', 'Set-Location ''e:\1.GAIATRYST SYNOPSIS\app\python''; python main.py'
Start-Sleep -Seconds 5
Set-Location 'e:\1.GAIATRYST SYNOPSIS\app'
flutter run
