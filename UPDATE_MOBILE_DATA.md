# Mobile Real-Time Data Update Guide

## Overview
This guide explains how to ensure your mobile app receives real-time data updates every 5 minutes as intended.

## Two-Part Solution

### Part 1: Automatic Data Collection (Windows Service)

To get real-time data updates, you need to run the Python script regularly on your Windows machine to collect fresh data:

1. **Run the auto-update service:**
   ```batch
   auto_update_data.bat
   ```
   This script will:
   - Run the Python script every 5 minutes
   - Update the CSV file with fresh data
   - Keep running in the background

2. **Keep the service running:**
   - Run the batch file in the background
   - Or use Windows Task Scheduler to run it automatically

### Part 2: Mobile App Configuration

The mobile app is already configured to:
- Fetch updated data every 5 minutes
- Use the latest data from the assets folder when rebuilt
- Attempt to connect to a web API for live data (future enhancement)

## Implementation Steps

### Step 1: Start Data Collection Service
Run the batch file to start collecting fresh data:
```batch
start /min auto_update_data.bat
```

### Step 2: Update Assets Periodically
To ensure your mobile app has the most recent data:

1. **For testing:** Run the Python script manually:
   ```batch
   python python\main.py
   ```

2. **For deployment:** Rebuild your app periodically to include the latest data:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk
   ```

### Step 3: Future Enhancement - Web API
For true real-time updates without rebuilding:

1. Deploy the Node.js server (see SERVER_SETUP.md)
2. Update the mobile app with your server's API URL
3. Modify `_fetchMobileData()` to use your actual server endpoint

## Verification

To verify your mobile app is getting updated data:

1. Check that `assets/gci_hourly_log_clean.csv` is updating regularly
2. Look for timestamps in the CSV file
3. Monitor app logs for data refresh messages
4. Verify frequency values are changing

## Troubleshooting

### Data Not Updating
- Verify the auto-update service is running
- Check that Python and dependencies are properly installed
- Ensure the target website is accessible

### Mobile App Not Showing New Data
- Rebuild the app to include the latest assets
- Clear app data/cache on the device
- Check app logs for data loading messages

## Best Practices

- Run the data collection service on a machine that stays on
- Monitor the service to ensure it continues running
- Regularly verify data freshness
- Plan for web API deployment for production use