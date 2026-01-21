Write-Host "Starting GAIATRYST SYNOPSIS with live data updates..." -ForegroundColor Green

# Start the server in a separate process
Write-Host "Starting data server..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-Command", "cd '$pwd\server'; node server.js"

# Wait for the server to start
Write-Host "Waiting for server to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 3

# Run the Flutter app
Write-Host "Starting Flutter app..." -ForegroundColor Yellow
flutter run

Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")