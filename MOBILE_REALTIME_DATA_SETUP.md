# Mobile Real-Time Data Setup Guide

## Overview
This guide explains how to set up real-time data for the mobile app. Since Android and iOS cannot run Python directly, we need to implement a web service approach to provide live data to mobile devices.

## Two Approaches

### Approach 1: Static Data (Immediate Solution)
The mobile app currently uses the most recent data from the assets folder. To update the data:

1. Run the Python script on your development machine:
   ```bash
   python python\main.py
   ```

2. This updates the CSV file in the assets folder with the latest data

3. Rebuild your mobile app:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk
   ```

### Approach 2: Live Data via Web API (Recommended)
For true real-time data on mobile devices, set up a web server that runs the Python script and provides an API.

## Setting Up the Web API Server

### Step 1: Server Setup
1. Navigate to the server directory:
   ```bash
   cd server/
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Run the server:
   ```bash
   npm start
   ```

### Step 2: Update Mobile App
1. Edit `lib/main.dart` and update the API URL in the `_fetchMobileData()` function:
   ```dart
   final apiUrl = 'https://your-server-url.com/api/data';
   ```

2. Rebuild your mobile app:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk
   ```

### Step 3: Deploy Server
Choose one of the following deployment options:

#### Option A: Self-hosted Server
Deploy the Node.js server to any VPS or cloud provider that supports both Node.js and Python.

#### Option B: Cloud Platforms
Use cloud providers like:
- DigitalOcean
- AWS EC2
- Google Cloud Platform
- Azure

#### Option C: Automated Deployment
Use the provided deployment script:
```bash
deploy_server.bat
```

## How It Works

1. The server runs the Python script periodically (every 10 minutes)
2. The Python script scrapes live data from HeartMath GCI
3. The data is stored and served via REST API
4. The mobile app fetches the latest data from the API
5. Data is cached locally on the device for offline access

## Verification

To verify the mobile app is getting real-time data:

1. Check the server logs for successful data collection
2. Test the API endpoint directly in a browser
3. Monitor the mobile app logs for successful API calls
4. Verify the frequency values are updating

## Troubleshooting

### Mobile App Not Getting Live Data
- Verify the server is running and accessible
- Check the API URL in the mobile app
- Confirm internet permissions are set correctly
- Review mobile app logs for error messages

### Server Issues
- Ensure Python and required packages are installed
- Check that Chrome and ChromeDriver are accessible
- Verify the target website is accessible from the server
- Monitor server logs for errors

## Best Practices

- Use HTTPS for the API in production
- Implement proper error handling for offline scenarios
- Cache data locally on the mobile device
- Monitor server uptime and performance
- Set up alerts for when data collection fails

## Maintenance

- Regularly update server dependencies
- Monitor data collection success rate
- Scale server resources as needed
- Backup server configurations
- Update the Python scraping script if the source website changes