@echo off
echo ========================================
echo GAIATRYST SYNOPSIS - GitHub Deployment
echo ========================================
echo.

echo Step 1: Adding GitHub remote repository
echo Replace YOUR_USERNAME with your actual GitHub username
echo.
set /p username=Enter your GitHub username: 

git remote add origin https://github.com/%username%/gaiatryst-frequency-monitor.git
echo.

echo Step 2: Pushing to GitHub
echo This will upload all your code to GitHub
echo.
git push -u origin main
echo.

echo ========================================
echo DEPLOYMENT COMPLETE!
echo ========================================
echo.
echo Next steps:
echo 1. Go to your GitHub repository
echo 2. Click on "Actions" tab
echo 3. Enable the "Auto Frequency Data Update" workflow
echo 4. Update your Flutter app to fetch data from GitHub
echo.
echo See DEPLOY_TO_GITHUB.md for detailed instructions
echo.
pause