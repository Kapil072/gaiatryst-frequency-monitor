@echo off
echo Deploying Schumann Resonance Data Server...

echo Creating deployment package...
cd /d "%~dp0"

REM Create a temporary directory for deployment
if exist "temp_deploy" rmdir /s /q "temp_deploy"
mkdir temp_deploy

REM Copy necessary files
xcopy "server" "temp_deploy\server" /E /I /Y
copy "python\main.py" "temp_deploy\python\" /Y
copy "assets\gci_hourly_log_clean.csv" "temp_deploy\" /Y

echo Installing server dependencies...
cd temp_deploy\server
npm install --production

echo Creating deployment archive...
cd ..
tar -czf schumann-server-deployment.tar.gz server python gci_hourly_log_clean.csv

echo Deployment package created: temp_deploy\schumann-server-deployment.tar.gz

echo.
echo To deploy:
echo 1. Upload the tar.gz file to your server
echo 2. Extract it: tar -xzf schumann-server-deployment.tar.gz
echo 3. Navigate to the server directory: cd server
echo 4. Run: npm start
echo.
echo Remember to configure your Flutter app to use the new server URL!

pause