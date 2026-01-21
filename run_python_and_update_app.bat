@echo off
echo Running Python script to update data...
cd /d "e:\1.GAIATRYST SYNOPSIS\app\python"
start /wait python main.py
timeout /t 10 /nobreak
echo Copying updated CSV to assets...
copy /Y "..\gci_hourly_log_clean.csv" "..\assets\gci_hourly_log_clean.csv"
echo Building app with updated data...
cd /d "e:\1.GAIATRYST SYNOPSIS\app"
flutter clean
flutter pub get
flutter run
pause
