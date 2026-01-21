@echo off
echo Updating CSV file from source...
copy /Y "..\gci_hourly_log_clean.csv" "assets\gci_hourly_log_clean.csv"
echo Cleaning and rebuilding app...
flutter clean
flutter pub get
flutter run
pause
