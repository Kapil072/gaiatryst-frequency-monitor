Write-Host "========================================" -ForegroundColor Green
Write-Host "GAIATRYST SYNOPSIS - GitHub Deployment" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Step 1: Adding GitHub remote repository" -ForegroundColor Yellow
Write-Host "Replace YOUR_USERNAME with your actual GitHub username" -ForegroundColor Gray
Write-Host ""

$username = Read-Host "Enter your GitHub username"

git remote add origin "https://github.com/$username/gaiatryst-frequency-monitor.git"
Write-Host ""

Write-Host "Step 2: Pushing to GitHub" -ForegroundColor Yellow
Write-Host "This will upload all your code to GitHub" -ForegroundColor Gray
Write-Host ""

git push -u origin main
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Go to your GitHub repository" -ForegroundColor White
Write-Host "2. Click on 'Actions' tab" -ForegroundColor White
Write-Host "3. Enable the 'Auto Frequency Data Update' workflow" -ForegroundColor White
Write-Host "4. Update your Flutter app to fetch data from GitHub" -ForegroundColor White
Write-Host ""
Write-Host "See DEPLOY_TO_GITHUB.md for detailed instructions" -ForegroundColor Gray
Write-Host ""

Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")